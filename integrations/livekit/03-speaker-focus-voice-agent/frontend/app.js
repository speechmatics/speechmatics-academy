/* ============================================================
   Speaker Focus demo — app logic (LiveKit only).
   Hero voice bars + subtitle captions + status card + events feed,
   driven by the agent's "speaker-focus" data-topic messages.
   Hotkeys are listed in the on-screen help overlay (refreshHelp below).
   ============================================================ */
"use strict";

(function(){
  var reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var qs = new URLSearchParams(location.search);

  /* ---------- elements ---------- */
  var app = document.getElementById("app");
  var els = {
    stage: document.getElementById("stage"),
    bars: document.querySelectorAll("#bars b"),
    badge: document.getElementById("badge"),
    caps: document.getElementById("caps"),
    roomWho: document.getElementById("roomWho"),
    modeChip: document.getElementById("modeChip"),
    statusHead: document.getElementById("statusHead"),
    statusSub: document.getElementById("statusSub"),
    chipBlocked: document.getElementById("chipBlocked"),
    blockedN: document.getElementById("blockedN"),
    pulseLine: document.getElementById("pulseLine"),
    spkStrip: document.getElementById("spkStrip"),
    evList: document.getElementById("evList"),
    evCount: document.getElementById("evCount"),
    toast: document.getElementById("toast"),
    help: document.getElementById("help")
  };

  /* ---------- state ---------- */
  var state = {
    talkSrc: "idle",
    level: null,        // real mic amplitude (0..1)
    blocked: 0, evN: 0,
    mode: "none",
    caps: []            // caption stack, newest last
  };

  var MODE_LABEL = { none:"NO LOCK", ignore:"IGNORE", retain:"RETAIN" };
  var MODE_HEAD  = { none:"No lock — all active", ignore:"Ignoring speakers", retain:"Focus locked" };

  /* ---------- hero bars ---------- */
  var BAR_PATTERN = [0.55, 0.9, 1.0, 0.75, 0.5];
  function tickBars(){
    var hot = state.talkSrc !== "idle";
    var amp = state.level == null ? 1 : (0.35 + state.level * 0.85);
    els.bars.forEach(function(b, i){
      var h = hot ? (18 + Math.random() * 74 * BAR_PATTERN[i] * amp) : 0;
      b.style.height = h.toFixed(0) + "%";
    });
    document.querySelectorAll('.spk[data-talking="1"] .talkbars i').forEach(function(el){
      el.style.height = (25 + Math.random() * 75).toFixed(0) + "%";
    });
    document.querySelectorAll('.spk[data-talking="0"] .talkbars i').forEach(function(el){
      el.style.height = (10 + Math.random() * 8).toFixed(0) + "%";
    });
  }

  /* ---------- captions ---------- */
  function renderCaps(){
    var n = state.caps.length;
    els.caps.innerHTML = state.caps.map(function(c, i){
      var age = (i === n - 1) ? "new" : "old";
      if (c.kind === "event"){
        return '<div class="cap event ' + age + '"><span class="ev">' + c.text + "</span></div>";
      }
      var tag = c.tag ? '<span class="tag">' + c.tag + "</span>" : "";
      var caret = c.partial ? '<span class="caret"></span>' : "";
      return '<div class="cap ' + c.cls + " " + age + '">' +
             '<span class="who">' + c.who + "</span>" +
             '<span class="txt">' + c.text + tag + caret + "</span></div>";
    }).join("");
  }
  function pushCap(cap){
    var last = state.caps[state.caps.length - 1];
    if (last && last.partial && last.who === cap.who) state.caps.pop();
    state.caps.push(cap);
    if (state.caps.length > 3) state.caps.shift();
    renderCaps();
  }

  /* ---------- events feed ---------- */
  function plain(html){ return String(html).replace(/<[^>]+>/g, ""); }
  function pad(n){ return String(n).padStart(2, "0"); }
  var bootAt = Date.now();
  function stamp(){
    var s = Math.floor((Date.now() - bootAt) / 1000);
    return pad(Math.floor(s / 60)) + ":" + pad(s % 60);
  }
  function addEv(kind, key, text){
    var item = document.createElement("div");
    item.className = "ev-item";
    item.setAttribute("data-kind", kind);
    item.innerHTML =
      '<span class="d"></span>' +
      '<span><span class="k">' + key + '<span class="tm">' + stamp() + "</span></span>" +
      '<div class="x">' + text + "</div></span>";
    els.evList.appendChild(item);
    while (els.evList.children.length > 7) els.evList.removeChild(els.evList.firstChild);
    state.evN++;
    els.evCount.textContent = state.evN;
  }

  /* ---------- status card ---------- */
  function refreshStatus(){
    els.statusHead.textContent = MODE_HEAD[state.mode];
    els.modeChip.textContent = MODE_LABEL[state.mode];
    els.modeChip.setAttribute("data-mode", state.mode);
  }

  function setSpeakers(list){
    els.spkStrip.innerHTML = list.map(function(s){
      var st = { focused:"FOCUSED", active:"ACTIVE", passive:"PASSIVE",
                 ignored:"IGNORED" }[s.state] || s.state.toUpperCase();
      return '<div class="spk" data-state="' + s.state + '" data-talking="' + (s.talking ? 1 : 0) + '">' +
             '<span class="dot"></span><span class="nm">' + s.label + "</span>" +
             '<span class="talkbars"><i></i><i></i><i></i><i></i></span>' +
             '<span class="st">' + st + "</span></div>";
    }).join("");
  }

  /* ---------- blocked badge + counter ---------- */
  function bumpBlocked(){
    state.blocked++;
    els.blockedN.textContent = state.blocked;
    els.chipBlocked.classList.add("show");
    els.badge.textContent = "DROPPED ×" + state.blocked;
    els.badge.classList.add("on");
  }

  /* ---------- reset ---------- */
  function reset(){
    state.caps = []; renderCaps();
    els.evList.innerHTML = ""; state.evN = 0; els.evCount.textContent = "0";
    state.blocked = 0; els.blockedN.textContent = "0";
    els.chipBlocked.classList.remove("show");
    els.badge.classList.remove("on");
    state.talkSrc = "idle";
    els.stage.setAttribute("data-src", "idle");
    els.pulseLine.classList.remove("on");
  }

  /* ---------- protocol dispatcher ---------- */
  function handle(msg){
    switch (msg.t){
      case "reset": reset(); break;
      case "mode": state.mode = msg.mode; refreshStatus(); break;
      case "speakers": setSpeakers(msg.list); break;
      case "segment":
        pushCap({kind:"seg", cls:msg.cls, who:msg.who, text:msg.text, tag:msg.tag, partial:msg.partial});
        if (!msg.partial) addEv("segment", "segment", "[" + msg.who + "] " + plain(msg.text));
        break;
      case "agentText":
        // streaming agent speech (word-by-word, synced to the TTS audio)
        pushCap({kind:"seg", cls:"agent", who:"OTTO", text:msg.text, partial:!msg.final});
        break;
      case "agent":
        // final reply text from the data topic — events log only; the caption
        // is driven by the streaming "agentText" above.
        addEv("agent", "agent say", plain(msg.text));
        break;
      case "event":
        pushCap({kind:"event", text:msg.text});
        addEv("update", "update_speakers", msg.text);
        break;
      case "bus":
        addEv("llm", "llm input", msg.lines.map(function(l){ return plain(l.text); }).join(" · "));
        break;
      case "stat": if (msg.k === "blocked") bumpBlocked(); break;
      case "agentState": els.statusSub.textContent = msg.text; break;
      case "roomWho": els.roomWho.textContent = msg.text; break;
      case "level":
        state.level = msg.v;
        state.talkSrc = msg.src;
        els.stage.setAttribute("data-src", msg.src);
        els.pulseLine.classList.toggle("on", msg.src !== "idle" && !reduced);
        if (msg.src !== "ignored") els.badge.classList.remove("on");
        break;
      case "toast": toast(msg.text, msg.hold); break;
      case "paused":
        app.setAttribute("data-paused", msg.on ? "true" : "false");
        var pb = document.getElementById("pauseBtn");
        pb.setAttribute("data-on", msg.on ? "true" : "false");
        pb.textContent = msg.on ? "Paused" : "Pause";
        if (msg.on){
          state.talkSrc = "idle"; state.level = 0;
          els.stage.setAttribute("data-src", "idle");
          els.pulseLine.classList.remove("on");
        }
        break;
    }
  }

  /* ---------- transport ---------- */
  var transport = new LiveKitTransport(handle, qs.get("token"));

  /* ---------- toast ---------- */
  var toastTimer = null;
  function toast(html, hold){
    els.toast.innerHTML = html;
    els.toast.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function(){ els.toast.classList.remove("show"); }, hold || 2400);
  }
  var CALLS = {
    focus:  'stt.update_speakers(<span class="fn">focus_speakers</span>=[you], <span class="fn">focus_mode</span>=RETAIN)',
    only:   'stt.update_speakers(<span class="fn">focus_speakers</span>=[you], <span class="fn">focus_mode</span>=IGNORE)',
    ignore: 'stt.update_speakers(<span class="fn">ignore_speakers</span>=[stranger])',
    clear:  'stt.update_speakers(<span class="fn">focus_speakers</span>=[], <span class="fn">ignore_speakers</span>=[])'
  };
  function command(action){
    transport.command(action);
    toast("→ " + CALLS[action]);
  }
  function enroll(){
    transport.command("enroll");
    toast('→ <span class="fn">get_speaker_ids()</span> · saving voiceprints');
  }
  document.getElementById("pauseBtn").addEventListener("click", function(){
    transport.setPaused(!(transport._paused));
    this.blur();
  });

  document.querySelector(".cmds").addEventListener("click", function(e){
    var btn = e.target.closest("button[data-call]");
    if (!btn) return;
    var a = btn.getAttribute("data-call");
    if (a === "enroll") enroll();
    else if (a === "loadclips") document.getElementById("clipPick").click();
    else command(a);
  });

  /* ---------- heckler clips — injected straight into the published mic ----- */
  var clips = new Array(9).fill(null);   // {name, buffer} · keys 1–9
  document.getElementById("clipPick").addEventListener("change", function(){
    var files = Array.from(this.files).slice(0, 9);
    this.value = "";
    files.forEach(function(f, i){
      transport.decodeClip(f).then(function(buffer){
        clips[i] = {name: f.name.replace(/\.[^.]+$/, ""), buffer: buffer};
        toast("clip " + (i + 1) + " = " + clips[i].name);
        refreshHelp();
      }).catch(function(e){ toast("clip " + (i + 1) + " failed: " + e.message); });
    });
  });
  function playClip(i){
    if (!clips[i]){ toast("clip slot " + (i + 1) + " is empty — press S, then Load clips"); return; }
    transport.playClip(clips[i].buffer, clips[i].name);
  }
  /* help overlay: hotkey legend + live map of which clip sits on which key.
     Toggled with H — hide it for clean takes so the trick stays invisible. */
  function refreshHelp(){
    els.help.textContent = "";
    var l1 = document.createElement("div");
    l1.textContent = "1-9 play clip · Space stop · F focus · O only · I ignore · C clear · E enroll · P pause · V vertical · S setup · H hide";
    els.help.appendChild(l1);
    var loaded = [];
    clips.forEach(function(c, i){ if (c) loaded.push((i + 1) + " " + c.name); });
    if (loaded.length){
      var l2 = document.createElement("div");
      l2.textContent = "clips: " + loaded.join(" · ");
      els.help.appendChild(l2);
    }
  }

  /* ---------- hotkeys ---------- */
  document.addEventListener("keydown", function(e){
    if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") return;
    var k = e.key.toLowerCase();
    if (k >= "1" && k <= "9"){ playClip(+k - 1); }
    else if (k === " "){ e.preventDefault(); transport.stopClip(); }
    else if (k === "f") command("focus");
    else if (k === "o") command("only");
    else if (k === "i") command("ignore");
    else if (k === "c") command("clear");
    else if (k === "e") enroll();
    else if (k === "p") transport.setPaused(!(transport._paused));
    else if (k === "v"){
      var v = document.body.getAttribute("data-layout") === "vertical";
      document.body.setAttribute("data-layout", v ? "desktop" : "vertical");
    }
    else if (k === "s"){
      var on = app.getAttribute("data-setup") === "on";
      app.setAttribute("data-setup", on ? "off" : "on");
    }
    else if (k === "h"){ els.help.classList.toggle("show"); }
  });

  /* ---------- loops ---------- */
  if (!reduced){
    setInterval(tickBars, 120);
  } else {
    els.bars.forEach(function(b, i){ b.style.height = (20 + (i % 3) * 18) + "%"; });
  }

  /* ---------- boot ---------- */
  if (qs.get("layout") === "vertical") document.body.setAttribute("data-layout", "vertical");
  var frame = qs.get("frame");
  if (frame === "jade" || frame === "amber") document.body.setAttribute("data-frame", frame);
  refreshStatus();
  els.roomWho.textContent = "connecting…";
  els.statusSub.textContent = "connecting…";
  refreshHelp();
  els.help.classList.add("show");
})();
