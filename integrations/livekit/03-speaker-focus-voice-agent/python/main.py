#!/usr/bin/env python3
"""
Speaker Focus — LiveKit Agents + Speechmatics

A voice agent that only obeys the speakers you focus on. Speechmatics handles
diarization and voiceprints natively; this agent adds live focus / ignore
control and streams UI events to the browser visualiser over the
"speaker-focus" data topic.

    S1, S2 ...     diarization labels each new voice, live
    focus / ignore which speakers drive the conversation (hotkeys or voice)
    voiceprints    saved on demand (press E) to speakers.json — edit a "label" to name one

Run:
    .venv\\Scripts\\python main.py dev       # browser visualiser (frontend + token_server)
    .venv\\Scripts\\python main.py console   # quick terminal test, no browser
"""

import asyncio
import json
import re
import time
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from livekit import agents, rtc
from livekit.agents import (
    Agent,
    AgentSession,
    JobContext,
    RoomInputOptions,
    RoomOutputOptions,
    function_tool,
)
from livekit.plugins import elevenlabs, openai, silero, speechmatics
from livekit.plugins.speechmatics import (
    AdditionalVocabEntry,
    SpeakerFocusMode,
    SpeakerIdentifier,
    TurnDetectionMode,
)

load_dotenv(Path(__file__).parent / ".env")
load_dotenv(Path(__file__).parent.parent / ".env")  # .env at the example root also works

SPEAKERS_FILE = Path(__file__).parent / "speakers.json"
PROMPT_FILE = Path(__file__).parent.parent / "assets" / "agent.md"
TOPIC = "speaker-focus"
RESERVED = re.compile(r"^S\d+$")  # diarization labels the server won't accept back

# The model sees speakers tagged like this; LINE_RE parses it back out for the UI.
ACTIVE_FMT = "[{speaker_id}]: {text}"
PASSIVE_FMT = "[{speaker_id} (background)]: {text}"

# Custom dictionary: bias the STT toward words it keeps mishearing. Each entry
# is the correct spelling plus lowercase "sounds like" renderings of how people
# actually say it — without this, "Otto" tends to come out as "auto".
VOCAB = [
    AdditionalVocabEntry(content="Otto", sounds_like=["auto", "oto"]),
    AdditionalVocabEntry(content="Speechmatics", sounds_like=["speech matics", "speech mattics", "speech magics"]),
    # The chaos clip "make that a Hawaiian" kept transcribing as "house".
    AdditionalVocabEntry(content="Hawaiian", sounds_like=["house", "hawaii an"]),
]
LINE_RE = re.compile(r"^\[(?P<who>[^\]\(]+?)(?P<bg>\s*\(background\))?\]:\s*(?P<text>.*)$")


# ---------------------------------------------------------------- speakers --
def load_known_speakers() -> list[SpeakerIdentifier]:
    """Load enrolled voiceprints; skip reserved S-labels the server rejects."""
    if not SPEAKERS_FILE.exists():
        return []
    data = json.loads(SPEAKERS_FILE.read_text(encoding="utf-8"))
    return [
        SpeakerIdentifier(label=e["label"], speaker_identifiers=e["speaker_identifiers"])
        for e in data
        if isinstance(e, dict) and e.get("label") and e.get("speaker_identifiers") and not RESERVED.match(e["label"])
    ]


def save_speakers(raw: list[Any]) -> list[str]:
    """Persist GET_SPEAKERS results. Reserved labels (S1) are renamed to
    Speaker_1 so they load back as known_speakers; edit the label to name.
    Returns the labels actually saved (empty if nothing was captured yet)."""
    if raw and isinstance(raw[0], list):  # one stream -> flatten
        raw = next((x for x in raw if x), [])
    out = []
    for s in raw:
        label = s.get("label") if isinstance(s, dict) else getattr(s, "label", None)
        ids = s.get("speaker_identifiers") if isinstance(s, dict) else getattr(s, "speaker_identifiers", None)
        if not label or not ids:
            continue
        if RESERVED.match(label):
            label = f"Speaker_{label[1:]}"
        out.append({"label": label, "speaker_identifiers": ids})
    if not out:
        return []
    SPEAKERS_FILE.write_text(json.dumps(out, indent=2), encoding="utf-8")
    return [e["label"] for e in out]


def load_prompt() -> str:
    # encoding matters: prompt.md is UTF-8; Windows' default read is cp1252,
    # which turns em-dashes into mojibake INSIDE the system prompt, and the
    # model then parrots the garbage verbatim in spoken confirmations.
    return PROMPT_FILE.read_text(encoding="utf-8") if PROMPT_FILE.exists() else "You are a concise voice assistant."


def parse_lines(transcript: str, fallback: str | None):
    """Split a formatted transcript into (who, is_passive, text) tuples."""
    out = []
    for line in transcript.splitlines():
        line = line.strip()
        if not line:
            continue
        m = LINE_RE.match(line)
        if m:
            out.append((m.group("who").strip(), bool(m.group("bg")), m.group("text")))
        else:
            out.append((fallback or "S?", False, line))
    return out


# ------------------------------------------------------------------- lock --
class LockState:
    """Tracks focus/ignore config and who has been heard, for the UI roster."""

    def __init__(self, primary: str | None):
        self.focus: list[str] = []
        self.ignore: list[str] = []
        self.mode = SpeakerFocusMode.RETAIN
        self.primary = primary  # enrolled human, e.g. "Edgar"
        self.seen: dict[str, float] = {}  # sid -> last-heard time (for "talking")
        self.counts: dict[str, int] = {}  # sid -> segments spoken (for "dominant")

    def note(self, sid: str, now: float) -> None:
        self.seen[sid] = now
        self.counts[sid] = self.counts.get(sid, 0) + 1

    def spk_state(self, sid: str) -> str:
        if sid in self.ignore:
            return "ignored"
        if self.focus:
            if sid in self.focus:
                return "focused"
            return "passive" if self.mode == SpeakerFocusMode.RETAIN else "ignored"
        return "active"

    def mode_str(self) -> str:
        if self.focus:
            return "retain" if self.mode == SpeakerFocusMode.RETAIN else "ignore"
        return "ignore" if self.ignore else "none"

    def dominant(self) -> str | None:
        """Most talkative real (non-agent) speaker — the likely demo driver."""
        reals = {k: v for k, v in self.counts.items() if not k.startswith("__")}
        return max(reals, key=reals.get) if reals else None

    def me(self) -> str:
        """Resolve "focus on me" to a speaker who is actually present.

        The enrolled name only counts if it was recognised this session;
        focusing a name that isn't in the room makes EVERYONE passive, and
        RETAIN then buffers all of it (nothing emits) — which looks exactly
        like IGNORE. Fall back to the dominant live speaker.
        """
        if self.primary and self.primary in self.seen:
            return self.primary
        return self.dominant() or "S1"

    def other(self) -> str:
        """The most recent speaker who is not "me" (the one to ignore)."""
        me = self.me()
        others = {k: v for k, v in self.seen.items() if k != me and not k.startswith("__")}
        return max(others, key=others.get) if others else "S2"

    def roster(self) -> dict:
        ids = list(self.seen.keys())
        if self.primary and self.primary not in ids:
            ids.insert(0, self.primary)
        now = time.monotonic()
        return {
            "t": "speakers",
            "list": [
                {
                    "label": sid,
                    "state": self.spk_state(sid),
                    "talking": (now - self.seen.get(sid, 0)) < 1.2,
                }
                for sid in ids
            ],
        }


# ------------------------------------------------------------- entrypoint --
async def entrypoint(ctx: JobContext):
    await ctx.connect()

    known = load_known_speakers()
    primary = next((k.label for k in known if not RESERVED.match(k.label)), None)
    lock = LockState(primary)

    def publish(msg: dict):
        asyncio.create_task(ctx.room.local_participant.publish_data(json.dumps(msg), reliable=True, topic=TOPIC))

    def publish_views():
        publish({"t": "mode", "mode": lock.mode_str()})
        publish(lock.roster())

    # No `vad` here: passing one forces EXTERNAL turn detection, which ends a turn
    # on ANY voice — a background heckler would trip a reply. ADAPTIVE leaves
    # endpointing to Speechmatics, which ends turns only for focused speakers.
    stt = speechmatics.STT(
        turn_detection_mode=TurnDetectionMode.ADAPTIVE,
        end_of_utterance_silence_trigger=0.6,  # pause (s) of the active speaker that ends a turn
        enable_diarization=True,
        speaker_active_format=ACTIVE_FMT,
        speaker_passive_format=PASSIVE_FMT,
        known_speakers=known,
        additional_vocab=VOCAB,
    )
    # Silero stays on the session for barge-in only. With turn_detection="stt" the
    # VAD never ends a turn, so a background voice can interrupt playback but can
    # never make the agent reply.
    vad = silero.VAD.load()
    session = AgentSession(
        stt=stt,
        vad=vad,
        turn_detection="stt",
        llm=openai.LLM(model="gpt-4o-mini"),
        # Defaults drift pace/emotion between replies; pin stability/style/speed
        # so Otto stays consistent on camera.
        tts=elevenlabs.TTS(
            voice_id="yowh82B72eMNrxcxHgBh",
            voice_settings=elevenlabs.VoiceSettings(
                stability=0.8,
                similarity_boost=0.8,
                style=0.0,
                speed=1.0,
                use_speaker_boost=True,
            ),
        ),
    )

    # ---- STT -> UI ------------------------------------------------------
    @session.on("user_input_transcribed")
    def on_transcribed(ev):
        now = time.monotonic()
        for who, passive, text in parse_lines(ev.transcript, ev.speaker_id):
            if not text:
                continue
            is_new = who not in lock.seen
            lock.note(who, now)
            publish(
                {
                    "t": "segment",
                    "who": who,
                    "cls": "passive" if passive else "active",
                    "text": text,
                    "tag": "PASSIVE" if passive else None,
                    "partial": not ev.is_final,
                }
            )
            if ev.is_final:
                tag = " (background)" if passive else ""
                publish({"t": "bus", "lines": [{"text": f"[{who}{tag}]: {text}"}]})
            if is_new:
                publish_views()

    @session.on("conversation_item_added")
    def on_item(ev):
        item = getattr(ev, "item", None)
        text = getattr(item, "text_content", None) if item else None
        if item and getattr(item, "role", "") == "assistant" and text:
            publish({"t": "agent", "text": text})

    @session.on("agent_state_changed")
    def on_agent_state(ev):
        publish({"t": "agentState", "text": f"agent · {ev.new_state}"})

    # ---- the only speaker-focus lever: the Speechmatics plugin ----------
    # Dropping ignored speakers, marking others passive, buffering — all of it
    # happens inside the plugin. These wrappers call it and mirror the state
    # into the UI; the LLM tools and the app hotkeys both funnel through here.
    def apply_focus(targets: list[str], mode: SpeakerFocusMode):
        lock.focus, lock.mode = list(targets), mode
        stt.update_speakers(focus_speakers=lock.focus, focus_mode=mode)
        mname = "RETAIN" if mode == SpeakerFocusMode.RETAIN else "IGNORE"
        publish(
            {"t": "event", "text": f"update_speakers( focus_speakers={json.dumps(lock.focus)}, focus_mode={mname} )"}
        )
        publish_views()

    def apply_ignore(target: str):
        if target and target not in lock.ignore:
            lock.ignore.append(target)
        stt.update_speakers(ignore_speakers=lock.ignore)
        publish({"t": "event", "text": f"update_speakers( ignore_speakers={json.dumps(lock.ignore)} )"})
        publish_views()

    def apply_clear():
        lock.focus, lock.ignore, lock.mode = [], [], SpeakerFocusMode.RETAIN
        stt.update_speakers(focus_speakers=[], ignore_speakers=[], focus_mode=SpeakerFocusMode.RETAIN)
        publish({"t": "event", "text": "update_speakers( cleared )"})
        publish_views()

    # ---- voice control: LLM tools (doc-canonical) ----------------------
    # The model resolves "me" from the speaker tag on the message (see prompt.md)
    # and passes the real speaker id — no guessing on our side.
    @function_tool
    async def focus_on_speaker(speaker_ids: list[str]) -> str:
        """ONLY call when a speaker explicitly asks to change the focus — never
        during normal conversation such as taking an order. Prioritise these
        speakers; everyone else stays audible as background (RETAIN). Replaces
        any current focus. Use for ANY request containing the word "focus":
        "focus on me", "focus on my voice", "I want you to focus on my voice",
        "focus on us" — resolve "me" to the speaker id prefixing the
        requester's own message."""
        apply_focus(speaker_ids, SpeakerFocusMode.RETAIN)
        return "focused"

    @function_tool
    async def listen_only_to_speaker(speaker_ids: list[str]) -> str:
        """ONLY call when a speaker explicitly asks — never during normal
        conversation such as taking an order. Listen ONLY to these speakers;
        drop everyone else entirely (IGNORE), including any new speakers. Use
        for "I want you to ignore everyone else" and "only listen to me" —
        pass the requester's own speaker id. NOT for any request containing
        the word "focus" — those are focus_on_speaker."""
        apply_focus(speaker_ids, SpeakerFocusMode.IGNORE)
        return "listening only to them"

    @function_tool
    async def ignore_speaker(speaker_id: str) -> str:
        """ONLY call when a speaker explicitly asks — never on your own
        initiative. Add ONE specific other speaker to the ignore list so their
        speech stops being transcribed. Use for "ignore him / her / them".
        Never use this for "ignore everyone else" — that is
        listen_only_to_speaker."""
        apply_ignore(speaker_id)
        return "ignored"

    @function_tool
    async def listen_to_all_speakers() -> str:
        """ONLY call when a speaker explicitly asks — never on your own
        initiative. Reset: clear the focus and ignore lists and hear everyone
        equally again. Use for "listen to everyone"."""
        apply_clear()
        return "listening to everyone"

    agent = Agent(
        instructions=load_prompt(),
        tools=[focus_on_speaker, listen_only_to_speaker, ignore_speaker, listen_to_all_speakers],
    )

    # ---- manual override: app hotkeys (F/O/I/C/E) ----------------------
    # Same wrappers; the hotkey has no speaker context, so me()/other() pick a
    # present speaker as the target.
    @ctx.room.local_participant.register_rpc_method("update_speakers")
    async def on_update_speakers(data: rtc.RpcInvocationData) -> str:
        cmd = json.loads(data.payload or "{}")
        action = cmd.get("action")

        if action == "focus":
            apply_focus([lock.me()], SpeakerFocusMode.RETAIN)
        elif action == "only":
            apply_focus([lock.me()], SpeakerFocusMode.IGNORE)
        elif action == "ignore":
            apply_ignore(lock.other())
        elif action == "clear":
            apply_clear()
        elif action == "enroll":
            # voiceprints save only via this action (the E key) — no auto-capture
            try:
                saved = save_speakers(await stt.get_speaker_ids())
                if saved:
                    names = ", ".join(saved)
                    publish({"t": "event", "text": f"enrolled {len(saved)}: {names} → speakers.json"})
                    publish(
                        {
                            "t": "toast",
                            "hold": 6000,
                            "text": f"Enrolled {len(saved)} voice(s): {names}. "
                            f"Rename in python/speakers.json and restart to greet by name.",
                        }
                    )
                else:
                    publish({"t": "event", "text": "enroll: no speakers captured yet"})
                    publish(
                        {
                            "t": "toast",
                            "hold": 5000,
                            "text": "No voice captured yet — say a few full sentences, then press E again.",
                        }
                    )
            except Exception as e:
                publish({"t": "toast", "hold": 6000, "text": f"Enroll failed: {e}"})
            publish_views()
        return "ok"

    # ---- go --------------------------------------------------------------
    await session.start(
        room=ctx.room,
        agent=agent,
        # When the viewer disconnects (e.g. a browser refresh) the session
        # closes; deleting the room too means the reconnect gets a FRESH agent
        # linked to the new session, instead of a stale one that can't hear you.
        room_input_options=RoomInputOptions(delete_room_on_close=True),
        # Forward the agent's speech transcription to the room, synced with the
        # TTS audio — the frontend renders it word-by-word as Otto speaks.
        room_output_options=RoomOutputOptions(transcription_enabled=True),
    )

    publish({"t": "event", "text": "agent connected — Speechmatics STT via livekit-agents"})
    publish({"t": "agentState", "text": "agent · listening"})
    publish({"t": "roomWho", "text": f"livekit · {ctx.room.name}"})
    publish_views()

    # No names in the greeting — enrolled speakers may not be in the room. They
    # get welcomed by name once they actually speak (assets/agent.md "# Greetings").
    await session.generate_reply(
        instructions="Greet the user in one short sentence and ask how you can help. "
        "You have not heard anyone speak yet — do not use any names."
    )


if __name__ == "__main__":
    # Explicit dispatch: the worker registers under this name and is dispatched
    # into a room by the token server (deterministic — no reliance on automatic
    # dispatch timing). Console mode still works: `python main.py console`.
    agents.cli.run_app(
        agents.WorkerOptions(
            entrypoint_fnc=entrypoint,
            agent_name="speaker-focus",
        )
    )
