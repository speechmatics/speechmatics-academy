/* ============================================================
   Speaker Focus demo — LiveKit transport.

   Browser mic -> LiveKit room -> agent/main.py (livekit-agents +
   Speechmatics STT plugin). The agent publishes UI protocol messages
   on data topic "speaker-focus" and answers over its own audio track
   (Otto's voice plays in this tab). Commands go to the agent via the
   LiveKit RPC "update_speakers".

   Needs the agent worker (agent/main.py dev) and token server
   (agent/token_server.py) running. Serve the frontend over http://
   — mic capture is blocked on file://.
   ============================================================ */
"use strict";

// Echo cancellation + noise suppression + auto gain on the mic. Without AEC
// the agent's own voice (played on the speakers) is captured back into the
// mic, so it hears itself, turn detection breaks, and it stops reacting.
var AUDIO_OPTS = {
  echoCancellation: true,
  noiseSuppression: true,
  autoGainControl: true,
};

function LiveKitTransport(onMessage, tokenUrl){
  this.onMessage = onMessage;
  this.tokenUrl = tokenUrl || "http://127.0.0.1:8790/token";
  this.room = null;
  this._agentId = null;
  this._lastSeg = 0;
  this._suppress = false;
  this._lastBlocked = 0;
  this._levelTimer = null;

  // Mix graph: published track = raw mic (AEC intact) + injected clips.
  // Clips also feed a local monitor so you hear them — the app's echo
  // cancellation keeps that monitor playback out of the mic capture.
  var AC = window.AudioContext || window.webkitAudioContext;
  this.ctx = new AC();
  this.dest = this.ctx.createMediaStreamDestination();
  this.monitor = this.ctx.createGain();
  this.monitor.gain.value = 0.9;
  this.monitor.connect(this.ctx.destination);
  this._micNode = null;
  this._gum = null;
  this._clipSrcs = new Set();   // clips can overlap — the chaos pile-on

  this._connect();
}

LiveKitTransport.prototype._toast = function(text){
  this.onMessage({t:"toast", text:text});
};

LiveKitTransport.prototype._connect = function(){
  var self = this;
  if (typeof LivekitClient === "undefined"){
    self._toast("livekit-client missing — check frontend/vendor/");
    return;
  }
  // Unique room per connect — reusing a fixed name races the old session's
  // delayed delete_room_on_close, which would delete the freshly recreated room.
  var roomName = "sl-" + Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
  this._roomName = roomName;
  fetch(this.tokenUrl + "?room=" + roomName + "&identity=viewer-" + Math.floor(Math.random() * 1e5))
    .then(function(r){
      if (!r.ok) throw new Error("token server " + r.status);
      return r.json();
    })
    .then(function(t){ return self._join(t.url, t.token); })
    .catch(function(e){
      self._toast("token server offline — run: python python/token_server.py (" + e.message + ")");
      self.onMessage({t:"agentState", text:"token server offline"});
      setTimeout(function(){ self._connect(); }, 4000);
    });
};

LiveKitTransport.prototype._join = function(url, token){
  var self = this;
  var RoomEvent = LivekitClient.RoomEvent;
  var room = new LivekitClient.Room({ audioCaptureDefaults: AUDIO_OPTS });
  self.room = room;

  room.on(RoomEvent.DataReceived, function(payload, _participant, _kind, topic){
    if (topic && topic !== "speaker-focus") return;
    var msg;
    try { msg = JSON.parse(new TextDecoder().decode(payload)); } catch (e){ return; }
    if (msg.t === "segment") self._lastSeg = Date.now();
    if (msg.t === "mode") self._suppress = (msg.mode === "ignore");
    self.onMessage(msg);
  });

  room.on(RoomEvent.TranscriptionReceived, function(segments, participant){
    // Agent speech only — the user's transcript comes over our data topic with
    // the speaker-tagged formatting. These segments stream word-by-word as the
    // agent's TTS plays, so the caption builds up live instead of appearing
    // all at once when the reply finishes.
    var isAgent = participant && ((participant.kind === "agent") || /^agent/i.test(participant.identity));
    if (!isAgent) return;
    segments.forEach(function(seg){
      self.onMessage({t:"agentText", id:seg.id, text:seg.text, final:seg.final});
    });
  });

  room.on(RoomEvent.TrackSubscribed, function(track, _pub, participant){
    // Only ever play the AGENT's audio. Never play another participant's
    // microphone — otherwise a second tab (or a viewer sharing the room)
    // plays your own mic back through the speakers, so you hear yourself.
    var isAgent = (participant.kind === "agent") || /^agent/i.test(participant.identity);
    if (track.kind === "audio" && isAgent){
      var el = track.attach();
      el.style.display = "none";
      document.body.appendChild(el);
      self._toast("agent audio connected — " + participant.identity);
    }
  });

  room.on(RoomEvent.ParticipantConnected, function(p){ self._maybeAgent(p); });
  room.on(RoomEvent.ParticipantDisconnected, function(p){
    // If the agent leaves (its session closed), stop pretending it's here.
    // The room is deleted on agent close, which triggers our auto-rejoin below.
    if (p.identity === self._agentId){
      self._agentId = null;
      self.onMessage({t:"agentState", text:"agent left — reconnecting…"});
    }
  });
  room.on(RoomEvent.Disconnected, function(){
    self._stopLevel();
    self.stopClip();
    if (self._gum){ self._gum.getTracks().forEach(function(t){ t.stop(); }); self._gum = null; }
    self._micPub = null;
    self._agentId = null;
    // kicked or dropped — rejoin automatically
    self.onMessage({t:"agentState", text:"room disconnected — rejoining…"});
    setTimeout(function(){ self._connect(); }, 2500);
  });

  return room.connect(url, token).then(function(){
    self.onMessage({t:"reset"});
    self.onMessage({t:"roomWho", text:"livekit · " + self._roomName});
    self.onMessage({t:"agentState", text:"connected · waiting for agent"});
    self.onMessage({t:"event", text:"joined room " + self._roomName + " — publishing microphone"});
    room.remoteParticipants.forEach(function(p){ self._maybeAgent(p); });

    // browser autoplay policy: agent audio + our AudioContext need one gesture
    var unlock = function(){
      room.startAudio().catch(function(){});
      if (self.ctx.state === "suspended") self.ctx.resume().catch(function(){});
      document.removeEventListener("click", unlock);
      document.removeEventListener("keydown", unlock);
    };
    document.addEventListener("click", unlock);
    document.addEventListener("keydown", unlock);

    // Publish the MIXED track (mic + clip injector) as the microphone source
    // — the agent's RoomIO only accepts SOURCE_MICROPHONE audio.
    return navigator.mediaDevices.getUserMedia({ audio: AUDIO_OPTS }).then(function(gum){
      self._gum = gum;
      if (self._micNode){ try{ self._micNode.disconnect(); }catch(e){} }
      self._micNode = self.ctx.createMediaStreamSource(gum);
      self._micNode.connect(self.dest);
      return room.localParticipant.publishTrack(self.dest.stream.getAudioTracks()[0], {
        name: "mic-mix",
        source: LivekitClient.Track.Source.Microphone
      });
    });
  }).then(function(pub){
    self._micPub = pub || null;
    if (self._paused && pub && pub.track) pub.track.mute().catch(function(){});
    if (pub && pub.track) self._startLevel(pub.track);
  }).catch(function(e){
    self._toast("LiveKit connect failed: " + e.message);
  });
};

LiveKitTransport.prototype._maybeAgent = function(p){
  // livekit-agents workers join as agent-kind participants
  var isAgent = (p.kind === "agent") || /^agent/i.test(p.identity);
  if (isAgent && !this._agentId){
    this._agentId = p.identity;
    this.onMessage({t:"agentState", text:"agent joined · listening"});
  }
};

/* local mic level -> hero bars. Uses LiveKit's createAudioAnalyser with
   cloneTrack:true so the Web Audio tap runs on a CLONE — reading the raw
   published track through Web Audio would disable the browser's echo
   canceller on it. When ignoring, loud input with no fresh transcript is
   attributed to the blocked speaker (the "sound in, nothing out" beat). */
LiveKitTransport.prototype._startLevel = function(localTrack){
  var self = this;
  try {
    var a = LivekitClient.createAudioAnalyser(localTrack, { cloneTrack: true, fftSize: 512 });
    this._analyser = a;
    // Gate on the RAW volume: speech RMS is ~0.1-0.4, silence (even with
    // auto-gain lifting room noise) stays under this, so the bars rest.
    var MIC_GATE = 0.09;
    this._levelTimer = setInterval(function(){
      if (self._paused){
        self.onMessage({t:"level", v: 0, src: "idle"});
        return;
      }
      var vol = a.calculateVolume();      // 0..1 RMS
      var v = Math.min(1, vol * 3);       // visual scale for the bars
      var now = Date.now();
      var src;
      if (vol < MIC_GATE) src = "idle";
      else if (now - self._lastSeg < 1200) src = "focused";
      else if (self._suppress && now - self._lastSeg > 800){
        src = "ignored";
        if (now - self._lastBlocked > 1500){
          self._lastBlocked = now;
          self.onMessage({t:"stat", k:"blocked"});
        }
      } else src = "focused";
      self.onMessage({t:"level", v: Math.round(v * 1000) / 1000, src: src});
    }, 100);
  } catch (e){
    self._toast("mic meter unavailable: " + e.message);
  }
};
LiveKitTransport.prototype._stopLevel = function(){
  if (this._levelTimer){ clearInterval(this._levelTimer); this._levelTimer = null; }
  if (this._analyser && this._analyser.cleanup){
    try { this._analyser.cleanup(); } catch (e) {}
    this._analyser = null;
  }
};

/* ---------- pause: stop sending audio to the agent ----------------------- */
LiveKitTransport.prototype.setPaused = function(p){
  this._paused = !!p;
  if (p) this.stopClip();
  var track = this._micPub && this._micPub.track;
  if (track){
    (p ? track.mute() : track.unmute()).catch(function(){});
  } else {
    // not published yet — gate the mixed destination track directly
    var t = this.dest.stream.getAudioTracks()[0];
    if (t) t.enabled = !p;
  }
  this.onMessage({t:"paused", on: this._paused});
};

/* ---------- clip injection (drop clip audio straight into the agent) ------ */
LiveKitTransport.prototype.decodeClip = function(file){
  var self = this;
  return file.arrayBuffer().then(function(ab){ return self.ctx.decodeAudioData(ab); });
};
LiveKitTransport.prototype.playClip = function(buffer, name){
  var self = this;
  if (this._paused){ this._toast("paused — press P to resume first"); return; }
  var src = this.ctx.createBufferSource();
  src.buffer = buffer;
  src.connect(this.dest);        // into the published track -> the agent
  src.connect(this.monitor);     // into your speakers (AEC keeps it off the mic)
  src.onended = function(){
    self._clipSrcs.delete(src);
    console.log("[clip] ended —", name);     // console only: never on screen,
  };                                         // the injection must stay invisible
  if (this.ctx.state === "suspended") this.ctx.resume().catch(function(){});
  src.start();
  this._clipSrcs.add(src);                   // clips layer — no auto-stop
  console.log("[clip] playing —", name, "(" + this._clipSrcs.size + " active)");
};
LiveKitTransport.prototype.stopClip = function(){
  this._clipSrcs.forEach(function(s){ try{ s.stop(); }catch(e){} });
  this._clipSrcs.clear();
};

LiveKitTransport.prototype.command = function(action){
  var self = this;
  if (!this.room || !this._agentId){
    this._toast("agent not in room yet — command not sent");
    return;
  }
  this.room.localParticipant.performRpc({
    destinationIdentity: this._agentId,
    method: "update_speakers",
    payload: JSON.stringify({action: action})
  }).catch(function(e){ self._toast("rpc failed: " + e.message); });
};
