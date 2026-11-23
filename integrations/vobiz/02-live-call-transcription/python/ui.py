"""Live transcript web UI for the proxy.

The proxy serves this page at /ui/<token> and pushes every call event and
transcript to it over a WebSocket at /events/<token>. Open the page in a
browser before (or during) a call to watch both speakers transcribed live.
"""

import asyncio
import json
from html import escape

CLIENTS: set = set()


def publish(event: dict) -> None:
    """Send one event to every open browser tab. Safe to call from sync code."""
    if not CLIENTS:
        return
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        return
    message = json.dumps(event)
    for ws in list(CLIENTS):
        loop.create_task(_send(ws, message))


async def _send(ws, message: str) -> None:
    try:
        await ws.send(message)
    except Exception:  # noqa: BLE001 - a closed tab just drops out
        CLIENTS.discard(ws)


async def serve_events(ws) -> None:
    """Hold one browser connection open until the tab closes."""
    CLIENTS.add(ws)
    try:
        await ws.send(json.dumps({"type": "hello"}))
        async for _ in ws:
            pass
    except Exception:  # noqa: BLE001
        pass
    finally:
        CLIENTS.discard(ws)


def page(events_path: str, vobiz_number: str, forward_to: str, language: str) -> bytes:
    return (
        PAGE.replace("__EVENTS_PATH__", events_path)
        .replace("__VOBIZ_NUMBER__", escape(vobiz_number or ""))
        .replace("__FORWARD_TO__", escape(forward_to or ""))
        .replace("__LANGUAGE__", escape(language or "en"))
        .encode()
    )


PAGE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Live Call Transcript · Speechmatics × Vobiz</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,600;12..96,700&family=Figtree:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
:root{
  --bg:#f5f6f8; --panel:#fff; --ink:#14161c; --muted:#5f6576; --line:#dfe2e8;
  --vobiz:#e83c00; --sm:#4b3fd1; --a:#1d6fd8; --a-soft:#e4effd; --b:#b2399a; --b-soft:#f7e4f3;
  --ok:#14915f; --warn:#c77700;
  --display:"Bricolage Grotesque",system-ui,sans-serif; --body:"Figtree",system-ui,sans-serif;
  --mono:"JetBrains Mono",ui-monospace,Menlo,monospace;
}
@media (prefers-color-scheme:dark){:root{
  --bg:#0e1015; --panel:#161920; --ink:#eceef3; --muted:#9aa1b2; --line:#2a2f3a;
  --vobiz:#ff6a33; --sm:#8f86ff; --a:#5aa2ff; --a-soft:#14243b; --b:#e277cb; --b-soft:#33192e;
  --ok:#3ccf8e; --warn:#f0a531; color-scheme:dark}}
*{box-sizing:border-box}
html,body{height:100%}
body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.55 var(--body);display:flex;flex-direction:column}
header{display:flex;align-items:center;gap:16px;flex-wrap:wrap;padding:14px max(16px,3vw);border-bottom:1px solid var(--line);background:var(--panel)}
.brand{font-family:var(--display);font-weight:700;font-size:20px;letter-spacing:-.01em}
.brand .x{color:var(--muted);font-weight:600;margin:0 6px}
.brand .sm{color:var(--sm)} .brand .vb{color:var(--vobiz)}
.status{display:inline-flex;align-items:center;gap:8px;font-size:13px;font-weight:600;padding:5px 12px;border-radius:999px;border:1px solid var(--line)}
.dot{width:9px;height:9px;border-radius:50%;background:var(--muted)}
.status.live .dot{background:var(--ok);box-shadow:0 0 0 0 var(--ok);animation:pulse 1.6s infinite}
.status.waiting .dot{background:var(--warn)}
@keyframes pulse{0%{box-shadow:0 0 0 0 color-mix(in srgb,var(--ok) 60%,transparent)}100%{box-shadow:0 0 0 10px transparent}}
.meta{margin-left:auto;display:flex;gap:18px;flex-wrap:wrap;font-size:13px;color:var(--muted)}
.meta b{color:var(--ink);font-family:var(--mono);font-weight:500}
main{flex:1;display:grid;grid-template-columns:minmax(0,1fr) 280px;gap:0;min-height:0}
@media (max-width:860px){main{grid-template-columns:1fr}aside{display:none}}
#feed{overflow-y:auto;padding:24px max(16px,3vw) 40px;display:flex;flex-direction:column;gap:14px}
.empty{margin:auto;text-align:center;color:var(--muted);max-width:44ch}
.empty h2{font-family:var(--display);color:var(--ink);font-size:22px;margin:0 0 6px}
.turn{display:flex;flex-direction:column;max-width:70%;gap:4px}
.turn.inbound{align-self:flex-start}
.turn.outbound{align-self:flex-end;align-items:flex-end}
.who{font-size:11.5px;font-weight:600;letter-spacing:.06em;text-transform:uppercase}
.inbound .who{color:var(--a)} .outbound .who{color:var(--b)}
.bubble{padding:10px 14px;border-radius:14px;font-size:16px;line-height:1.5}
.inbound .bubble{background:var(--a-soft);border-top-left-radius:4px}
.outbound .bubble{background:var(--b-soft);border-top-right-radius:4px}
.partial{color:var(--muted);font-style:italic}
.live{position:sticky;bottom:0;margin-top:auto;display:flex;flex-direction:column;gap:6px;padding-top:10px;background:linear-gradient(transparent,var(--bg) 30%)}
.live div{font-size:14px;color:var(--muted);font-style:italic;min-height:0}
.live div:empty{display:none}
.live b{font-style:normal;font-weight:600;font-size:11.5px;letter-spacing:.06em;text-transform:uppercase;margin-right:8px}
.live .inbound b{color:var(--a)} .live .outbound b{color:var(--b)}
.greet{align-self:center;font-size:13px;color:var(--ink);padding:6px 14px;border-radius:999px;background:color-mix(in srgb,var(--vobiz) 14%,transparent);border:1px solid color-mix(in srgb,var(--vobiz) 40%,transparent)}
.greet b{color:var(--vobiz);margin-right:6px}
.sys{align-self:center;font-size:12.5px;color:var(--muted);font-family:var(--mono);padding:4px 10px;border:1px dashed var(--line);border-radius:999px}
aside{border-left:1px solid var(--line);background:var(--panel);padding:20px;overflow-y:auto;display:flex;flex-direction:column;gap:18px}
aside h3{font-size:11.5px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);margin:0 0 8px}
.legend{display:flex;flex-direction:column;gap:10px;font-size:14px}
.legend div{display:flex;align-items:center;gap:10px}
.sw{width:12px;height:12px;border-radius:4px}
.stats{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.stat{border:1px solid var(--line);border-radius:10px;padding:10px}
.stat .v{font-family:var(--mono);font-size:20px;font-variant-numeric:tabular-nums}
.stat .l{font-size:12px;color:var(--muted)}
.pipeline{font-size:13px;color:var(--muted);display:flex;flex-direction:column;gap:6px}
.pipeline span{font-family:var(--mono);color:var(--ink)}
button{font:inherit;font-size:13px;padding:6px 12px;border-radius:8px;border:1px solid var(--line);background:var(--bg);color:var(--ink);cursor:pointer}
button:focus-visible{outline:2px solid var(--sm);outline-offset:2px}
</style>
</head>
<body>
<header>
  <div class="brand"><span class="sm">Speechmatics</span><span class="x">×</span><span class="vb">Vobiz</span></div>
  <div id="status" class="status waiting"><span class="dot"></span><span id="statusText">Waiting for a call</span></div>
  <div class="meta">
    <span>Vobiz number <b>__VOBIZ_NUMBER__</b></span>
    <span>Bridged to <b>__FORWARD_TO__</b></span>
    <span>Language <b>__LANGUAGE__</b></span>
    <span>Duration <b id="timer">0:00</b></span>
  </div>
</header>
<main>
  <section id="feed" aria-live="polite">
    <div class="empty" id="empty">
      <h2>Ready to transcribe</h2>
      Call the Vobiz number. Both sides of the conversation appear here live,
      transcribed by Speechmatics Realtime as separate speakers.
    </div>
    <div class="live" id="live"><div class="inbound" id="liveIn"></div><div class="outbound" id="liveOut"></div></div>
  </section>
  <aside>
    <div>
      <h3>Speakers</h3>
      <div class="legend">
        <div><span class="sw" style="background:var(--a)"></span>Caller <small style="color:var(--muted)">· inbound track</small></div>
        <div><span class="sw" style="background:var(--b)"></span>Bridged party <small style="color:var(--muted)">· outbound track</small></div>
      </div>
    </div>
    <div>
      <h3>This call</h3>
      <div class="stats">
        <div class="stat"><div class="v" id="nIn">0</div><div class="l">caller words</div></div>
        <div class="stat"><div class="v" id="nOut">0</div><div class="l">bridged words</div></div>
        <div class="stat"><div class="v" id="nTurns">0</div><div class="l">turns</div></div>
        <div class="stat"><div class="v" id="fmt">–</div><div class="l">audio format</div></div>
      </div>
    </div>
    <div>
      <h3>Pipeline</h3>
      <div class="pipeline">
        <div>Vobiz <span>&lt;Stream audioTrack="both"&gt;</span></div>
        <div>→ proxy, no transcoding</div>
        <div>→ Speechmatics RT <span>diarization="channel"</span></div>
      </div>
    </div>
    <div><button id="clear" type="button">Clear transcript</button></div>
  </aside>
</main>
<script>
const feed = document.getElementById('feed');
const empty = document.getElementById('empty');
const statusEl = document.getElementById('status');
const statusText = document.getElementById('statusText');
const timerEl = document.getElementById('timer');
const LABEL = {inbound: 'Caller', outbound: 'Bridged party'};
let last = null, startedAt = null, timer = null;
const count = {inbound: 0, outbound: 0, turns: 0};

function setStatus(cls, text){ statusEl.className = 'status ' + cls; statusText.textContent = text; }
function scroll(){ feed.scrollTop = feed.scrollHeight; }
const liveBox = document.getElementById('live');
const liveEl = {inbound: document.getElementById('liveIn'), outbound: document.getElementById('liveOut')};
function add(node){ feed.insertBefore(node, liveBox); }
function sys(text){ empty.hidden = true; const d = document.createElement('div'); d.className = 'sys'; d.textContent = text; add(d); last = null; scroll(); }
function greet(text){ empty.hidden = true; const d = document.createElement('div'); d.className = 'greet'; d.innerHTML = '<b>Vobiz played</b>'; d.appendChild(document.createTextNode(text)); add(d); last = null; scroll(); }
function setLive(ch, text){ const el = liveEl[ch]; if (!el) return; el.innerHTML = ''; if (text){ const b = document.createElement('b'); b.textContent = LABEL[ch] || ch; el.appendChild(b); el.appendChild(document.createTextNode(text + ' …')); } }
const GREETING = /this call is being transcribed\s*\.?/i;
let greeted = false;
function turnFor(ch){
  if (last && last.ch === ch) return last;
  empty.hidden = true;
  const t = document.createElement('div'); t.className = 'turn ' + ch;
  t.innerHTML = '<div class="who"></div><div class="bubble"><span class="final"></span></div>';
  t.querySelector('.who').textContent = LABEL[ch] || ch;
  add(t);
  count.turns++; document.getElementById('nTurns').textContent = count.turns;
  last = {ch, final: t.querySelector('.final')};
  return last;
}
function words(s){ return (s.match(/\S+/g) || []).length; }
function tick(){ const s = Math.floor((Date.now() - startedAt) / 1000); timerEl.textContent = Math.floor(s/60) + ':' + String(s%60).padStart(2,'0'); }

function onEvent(e){
  if (e.type === 'call_started'){
    setStatus('live', 'Live call');
    document.getElementById('fmt').textContent = (e.format || '').replace('audio/x-','').replace('/', ' ');
    sys('call started · ' + new Date().toLocaleTimeString()); greeted = false;
    startedAt = Date.now(); clearInterval(timer); timer = setInterval(tick, 500);
  } else if (e.type === 'call_ended'){
    setStatus('', 'Call ended'); clearInterval(timer);
    setLive('inbound', ''); setLive('outbound', '');
    sys('call ended · ' + new Date().toLocaleTimeString());
  } else if (e.type === 'partial'){
    setLive(e.channel, (e.text || '').replace(GREETING, '').trim()); scroll();
  } else if (e.type === 'final'){
    if (!e.text) return;
    setLive(e.channel, '');
    let text = e.text;
    if (!greeted && e.channel === 'outbound' && GREETING.test(text)){
      greeted = true; greet('This call is being transcribed.');
      text = text.replace(GREETING, '').replace(/^\s+/, '');
      if (!text) return;
    }
    const t = turnFor(e.channel); t.final.textContent += (t.final.textContent ? '' : '') + text;
    count[e.channel] = (count[e.channel] || 0) + words(e.text);
    document.getElementById('nIn').textContent = count.inbound;
    document.getElementById('nOut').textContent = count.outbound;
    scroll();
  }
}

function connect(){
  const ws = new WebSocket((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '__EVENTS_PATH__');
  ws.onmessage = m => onEvent(JSON.parse(m.data));
  ws.onclose = () => { if (!startedAt) setStatus('waiting', 'Reconnecting…'); setTimeout(connect, 1500); };
  ws.onopen = () => { if (!startedAt) setStatus('waiting', 'Waiting for a call'); };
}
document.getElementById('clear').onclick = () => {
  feed.querySelectorAll('.turn,.sys,.greet').forEach(n => n.remove()); setLive('inbound',''); setLive('outbound',''); last = null; empty.hidden = false;
  count.inbound = count.outbound = count.turns = 0;
  ['nIn','nOut','nTurns'].forEach(id => document.getElementById(id).textContent = '0');
};
connect();
</script>
</body>
</html>
"""
