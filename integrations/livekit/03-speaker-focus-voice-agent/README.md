<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/LK_wordmark_darkbg.png">
  <source media="(prefers-color-scheme: light)" srcset="../logo/LK_wordmark_lightbg.png">
  <img alt="LiveKit" src="../logo/LK_wordmark_lightbg.png" width="300">
</picture>

# Speaker Focus - Voice Agent Access Control

**A LiveKit voice agent that decides who it obeys: focus on chosen speakers, ignore or retain the rest, and recognise returning speakers by name - all live, driven by voice.**

</div>

Put a voice agent in a room with more than one person and you hit a problem immediately: whose words should it act on? By default, everyone's - anyone within earshot is an admin. This example locks the agent onto chosen speakers using the Speechmatics **speaker focus** and **speaker memory** features, and ships with a browser visualiser so every decision is visible on screen.

## What You'll Learn

- **Diarization** - labelling every voice live (`S1`, `S2`, ...) with `enable_diarization`
- **Speaker focus** - `RETAIN` (heard but not obeyed) vs `IGNORE` (dropped before it becomes text), switched mid-session with `stt.update_speakers(...)`
- **The ignore list** - muting one specific speaker
- **Speaker memory** - saving voice fingerprints with `get_speaker_ids()` and recognising returning speakers via `known_speakers`
- **Voice-driven control** - LLM function tools that change the focus ("ignore everyone else")
- **Focus-aware turn detection** - why `TurnDetectionMode.ADAPTIVE` matters in multi-speaker rooms
- **Custom dictionary** - `additional_vocab` so the STT spells "Otto" and "Speechmatics" correctly

## Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/) (free hours every month)
- **LiveKit Cloud Account**: Sign up at [cloud.livekit.io](https://cloud.livekit.io/) (URL, API key, API secret)
- **OpenAI API Key**: the agent's brain
- **ElevenLabs API Key**: the agent's voice
- **Python 3.9+**
- **A microphone** and a Chromium browser (Chrome/Edge) - mic capture happens in the browser, no PyAudio needed

## Project Structure

```
03-speaker-focus-voice-agent/
├── python/
│   ├── main.py           # the voice agent (diarization + focus + memory + tools)
│   ├── token_server.py   # room tokens + agent dispatch (port 8790)
│   ├── requirements.txt
│   └── .gitignore        # keeps .env and speakers.json out of git
├── frontend/             # no-build browser visualiser (static files)
├── assets/
│   └── agent.md          # the agent's system prompt (Otto, a pizzeria agent)
├── .env.example
└── README.md
```

## Quick Start

You'll run **three processes** in three terminals: the agent, the token server, and the frontend.

**Step 1: Create and activate a virtual environment**

On Windows (PowerShell):
```powershell
cd python
python -m venv .venv
.venv\Scripts\Activate.ps1
```

On Windows (cmd):
```bat
cd python
python -m venv .venv
.venv\Scripts\activate.bat
```

On Mac/Linux:
```bash
cd python
python3 -m venv .venv
source .venv/bin/activate
```

**Step 2: Install dependencies**

```bash
pip install -r requirements.txt
```

**Step 3: Configure environment**

```bash
cp ../.env.example .env      # cmd.exe: copy ..\.env.example .env
# Edit .env and fill in all six values
```

`.env` can live next to the code in `python/` or at the example root — the
scripts check both.

**Step 4: Start the three processes**

All three run at the same time, one terminal each. The agent itself is
headless - the browser UI in Step 5 only appears once all three are up.

Terminal 1 - the agent worker, from `python/` (wait for `registered worker`;
it stays running in this console):
```bash
python main.py dev
```

Terminal 2 - the token + dispatch server, from `python/`:
```bash
python token_server.py
```

Terminal 3 - the frontend static server (plain global Python is fine here -
no packages needed). Step into the `frontend/` folder and serve it:
```bash
cd frontend        # from the example root (from python/ use: cd ../frontend)
python -m http.server 8748
```

**Step 5: Open the app**

1. Go to **http://localhost:8748** in Chrome.
2. Allow the microphone.
3. Click once anywhere on the page (browser autoplay policy - this unlocks the agent's voice).

Within a couple of seconds the status flips to **agent joined - listening** and the agent (Otto) greets you.

## Architecture

```mermaid
flowchart LR
    subgraph Browser
        MIC[Mic + clip injector]
        UI[Visualiser + hotkeys]
    end

    subgraph Local
        TOKEN[token_server.py]
    end

    subgraph LiveKit Cloud
        ROOM[LiveKit Room]
    end

    subgraph Agent
        STT["Speechmatics STT - diarization, focus, memory"]
        LLM["OpenAI LLM + focus tools"]
        TTS[TTS]
    end

    UI -->|token request| TOKEN
    TOKEN -->|dispatches agent| ROOM
    MIC <-->|WebRTC audio| ROOM
    ROOM --> STT
    STT -->|speaker-tagged text| LLM
    LLM --> TTS
    TTS --> ROOM
    LLM -->|update_speakers| STT
    UI -.->|RPC update_speakers| ROOM
    ROOM -.->|UI events data topic| UI
```

The one loop that makes this example special: the LLM's focus tools (and the hotkey RPC) both call `stt.update_speakers(...)` on the same STT - Speechmatics then decides, server-side, whose words ever become text.

## How It Works

Your mic is published into a **LiveKit room**; the agent joins that room and runs the audio through the **Speechmatics STT plugin**. Everything speaker focus does is one plugin call - `stt.update_speakers(...)` - driven either by an LLM function tool or a hotkey. The agent never filters or drops speakers itself; Speechmatics does it server-side and returns speaker-tagged text.

Speaker focus rides on diarization (`enable_diarization=True`, on in this example), and the entire feature surface is three calls, live mid-session, no restart:

```python
# RETAIN: prioritise S1, everyone else becomes tagged background
stt.update_speakers(focus_speakers=["S1"], focus_mode=SpeakerFocusMode.RETAIN)

# IGNORE: drop everyone but S1 before their words ever become text
stt.update_speakers(focus_speakers=["S1"], focus_mode=SpeakerFocusMode.IGNORE)

# reset: hear everyone equally again
stt.update_speakers(focus_speakers=[], ignore_speakers=[])
```

Speaker focus is available in the Speechmatics voice SDK, Pipecat, and LiveKit plugins (the raw Realtime API does not expose it directly today).

**RETAIN vs IGNORE.** With `RETAIN` (the default), non-focused speakers are still transcribed but tagged `(background)` - the agent can hear them and be asked about them, but a system-prompt rule stops it obeying them, and they can be brought into focus later without losing anything. With `IGNORE`, non-focused speech is dropped at the engine level: not transcribed, and it never triggers voice activity or end-of-utterance detection.

**Two more levers.** The **ignore list** (`ignore_speakers`) silences specific speakers independently of the focus - useful for muting one heckler while everyone else stays active. And any speaker label wrapped in double underscores (such as `__ASSISTANT__`) is **excluded automatically**, so the agent's own voice can never be transcribed back into the conversation.

**Turn detection is focus-aware.** The STT uses `turn_detection_mode=TurnDetectionMode.ADAPTIVE`, so only the focused speaker can end a turn - a background voice going quiet never triggers a reply. Passing a `vad` to the STT would force `EXTERNAL` mode, which endpoints on any voice and makes the agent answer hecklers. Silero VAD stays on the `AgentSession` for barge-in only.

**Tags are the source of truth.** The system prompt (`assets/agent.md`) follows the three rules the docs recommend for focus-aware agents: the model judges every line only by its tag (untagged lines are active and must be served; `(background)` lines are context, never commands), it resolves "me"/"I" to the speaker ID prefixing that message, and it never says internal labels like `S1` out loud - only real names once known. The model never tracks focus state from conversation memory; the plugin already encodes it in the text.

**Speaker memory.** During a session the engine builds a voice fingerprint per speaker (usable after roughly five spoken words; fingerprints captured at the end of a session are the highest quality). Press `E` to save them via `stt.get_speaker_ids()` into `speakers.json`; rename a label (e.g. `Speaker_1` to `Edgar`) and restart, and `known_speakers` attributes that voice to `Edgar` in every future session - the focus can then target speakers **by name**:

```python
stt = speechmatics.STT(
    enable_diarization=True,
    known_speakers=[
        SpeakerIdentifier(label="Edgar", speaker_identifiers=["XX...XX"]),
    ],
)
```

A speaker profile can hold several identifiers; collecting them across sessions and devices and merging them into the existing profile (rather than overwriting it) makes recognition steadily more reliable.

## Using It

Talk to the agent normally, then change who it listens to - by voice or by hotkey.

### By voice (the LLM calls the tools)

| Say | Effect |
|-----|--------|
| "Otto, I want you to focus on my voice" | **RETAIN** - you drive the conversation; others become background |
| "Otto, I want you to ignore everyone else" | **IGNORE** - everyone else is dropped entirely |
| "Otto, ignore her" | adds that speaker to the ignore list |
| "Otto, listen to everyone" | resets - hear everyone equally |

### By hotkey (manual override)

| Key | Action |
|-----|--------|
| `F` | Focus you (RETAIN) |
| `O` | Only you (IGNORE - drop everyone else) |
| `I` | Ignore the latest other speaker |
| `C` | Clear the focus |
| `E` | Enroll voiceprints to `speakers.json` |
| `P` | Pause - stop sending your mic to the agent |
| `V` | Vertical 9:16 layout |
| `S` | Toggle the on-screen buttons |
| `H` | Toggle the hotkey/clip help overlay |
| `1`-`9` / `Space` | Play / stop loaded audio clips (multi-speaker testing without extra people) |

## Key Features

- **One plugin call** - focus, ignore and reset are all `stt.update_speakers(focus_speakers, ignore_speakers, focus_mode)`; zero custom filtering code
- **Live mid-session switching** - no restart, no reconnect
- **Voice-driven** - four `@function_tool`s let the model change the focus; it resolves "me" from the speaker tag on the request
- **Deliberate enrollment** - voiceprints are saved only when you press `E`; the agent never silently profiles anyone
- **Clip injection** - load audio clips and fire them into the published mic track with keys `1`-`9` to simulate a crowd single-handedly

## Expected Output

With no focus set, every speaker's line lands green in the transcript and the agent obeys all of them. After "I want you to ignore everyone else", other voices produce nothing at all - the events panel shows `update_speakers( focus_speakers=["S1"], focus_mode=IGNORE )` and the transcript stays still while they speak. After "I want you to focus on my voice", their lines appear grey with a `PASSIVE` tag and the agent only reacts when you address it. After enrolling and renaming, your transcript lines are labelled with your name and the agent welcomes you back by name when you speak.

## Security & Privacy

> [!WARNING]
> Speaker identifiers are voice fingerprints and **may qualify as biometric
> data** under data-protection law (for example GDPR): obtain consent before
> enrolling anyone, store identifiers securely, and support deletion.
> Speechmatics does not store them - you own the file. Identifiers are unique
> per account and do not work across accounts. `speakers.json` is gitignored
> in this example; treat it like a credential.

## Troubleshooting

**"waiting for agent" / no reply** - Make sure Terminal 1 (the agent) is running, then reload the browser tab. Each page load creates a fresh room with its own dispatch, so a reload recovers a stuck session on its own.

**No agent voice** - Click once anywhere on the page (browser autoplay policy).

**The agent hears or talks over itself** - Echo cancellation is on by default; on open speakers use headphones, or check the OS "listen to this device" setting is off.

**Enrollment says "no voice captured yet"** - A voiceprint needs about ten seconds of clean speech; say a few full sentences, then press `E` again.

**Authentication errors** - Re-check all six values in your `.env` (no stray spaces).

## Next Steps

- [Speaker ID & Speaker Focus (basics)](../../../basics/09-voice-agent-speaker-id/) - the minimal version of this pattern
- [Intelligent Turn Detection](../../../basics/08-voice-agent-turn-detection/) - more on end-of-turn behaviour
- [Simple Voice Assistant](../01-simple-voice-assistant/) - the plain LiveKit + Speechmatics starting point

## Resources

- [Speaker focus for voice agents](https://docs.speechmatics.com/speech-to-text/realtime/speaker-identification)
- [Diarization](https://docs.speechmatics.com/speech-to-text/features/diarization) - separating a transcript into speakers
- [LiveKit Speechmatics plugin](https://github.com/livekit/agents/tree/main/livekit-plugins/livekit-plugins-speechmatics)
- [LiveKit Agents docs](https://docs.livekit.io/agents/)

---

**Time to Complete**: 20 minutes
**Difficulty**: Intermediate
**API Mode**: Voice Agent (Real-time)
**Stack**: LiveKit Agents + Speechmatics STT plugin - Python + browser

[Back to LiveKit Integrations](../) | [Back to Academy](../../../README.md)
