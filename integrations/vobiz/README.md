<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="logo/vobiz-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="logo/vobiz-light.png">
  <img alt="Vobiz" src="logo/vobiz-light.png" width="200">
</picture>

# Vobiz + Speechmatics

**Connect phone calls on Vobiz numbers to Speechmatics speech recognition and speech synthesis.**

</div>

[Vobiz](https://vobiz.ai/) is a cloud telephony platform with phone numbers, voice calls, SIP trunking, and VobizXML for call control. Its `<Stream>` element sends live call audio to your server over a WebSocket as 16-bit PCM at 16 kHz, which Speechmatics accepts without transcoding. Speechmatics provides the Speech to Text (STT) and Text to Speech (TTS) on the call. Both examples run as a single Python process with no voice-agent framework or media server.

**Start with [Phone Voice Agent](01-phone-voice-agent/README.md)** to answer calls with agent STT, an LLM, and Speechmatics Text to Speech.

## Choose a workflow

- **Talk to an AI on the phone:** [Phone Voice Agent](01-phone-voice-agent/README.md) uses a bidirectional stream. Agent STT detects each caller turn, an OpenAI-compatible LLM writes the reply, and Speechmatics TTS speaks it back into the call, with barge-in.
- **Transcribe a call between two people:** [Live Call Transcription](02-live-call-transcription/README.md) bridges a caller to a second phone and copies both sides to one Realtime API session with channel diarization, shown in the console and a live web page.

Both examples need a Vobiz number and a public HTTPS tunnel to your machine. Follow the chosen README for setup.

## Choose an example

<!-- BEGIN GENERATED: examples -->
| Example | What you'll build | SDK / adapter | Language / level | Demo |
| --- | --- | --- | --- | --- |
| [Vobiz Phone Voice Agent](<01-phone-voice-agent/README.md>) | Answer phone calls with agent STT, an LLM, and Speechmatics TTS over a Vobiz audio stream. | Direct API / configuration | Python<br>intermediate | [Local](<01-phone-voice-agent/README.md>) |
| [Vobiz Live Call Transcription](<02-live-call-transcription/README.md>) | Transcribe both sides of a live phone call as separate speakers with channel diarization. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python<br>intermediate | [Local](<02-live-call-transcription/README.md>) |

### Demo access

- [Vobiz Phone Voice Agent](<01-phone-voice-agent/README.md>): Requires a Vobiz number and a public HTTPS tunnel; dial.py places real, billed outbound calls.
- [Vobiz Live Call Transcription](<02-live-call-transcription/README.md>): Requires a Vobiz number, a second phone to bridge to, and a public HTTPS tunnel; the proxy repoints the number unless run with `--no-setup`.

API reference: [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>) · [Speechmatics Agent STT (Linden 1)](<https://docs.speechmatics.com/speech-to-text/agent-stt>) · [Speechmatics Text to Speech API](<https://docs.speechmatics.com/text-to-speech/quickstart>).
<!-- END GENERATED: examples -->

## Related workflows

- [Telephony examples](../../collections/telephony/README.md) — other phone pipelines and recorded-call analysis.
- [Voice agent examples](../../collections/voice-agents/README.md) — agent STT foundations and complete pipelines.
- [Complete Academy catalog](../../docs/CATALOG.md) — browse by package, feature, integration, and difficulty.

[Back to Academy](../../README.md)
