<div align="center">

<img src="logo/pipecat.png" alt="Pipecat" width="300">

# Pipecat + Speechmatics

**Build voice agents with a local microphone or a browser WebRTC connection.**

</div>

These examples use Pipecat's Speechmatics adapter for agent STT, powered by Linden 1. Pipecat connects transcription to an LLM, speech synthesis, audio transport, and conversation handling. Both examples use external voice activity detection (VAD) to finalize STT segments; the browser example also uses a local smart-turn analyzer to decide when the LLM should respond.

**Start with the [Simple Voice Bot](01-simple-voice-bot/README.md)** to learn the pipeline using your computer's microphone and speakers.

## Choose a workflow

- **Local microphone and speakers:** [Simple Voice Bot](01-simple-voice-bot/README.md) combines Speechmatics, OpenAI, and ElevenLabs without a WebRTC server.
- **Browser audio:** [Simple Voice Bot (Web)](02-simple-voice-bot-web/README.md) uses WebRTC, a Groq-hosted LLM, Cartesia speech synthesis, and local smart-turn analysis. Its browser client comes from the prebuilt Pipecat client package.

Follow the selected README for audio dependencies, launch commands, and Speechmatics, LLM, and speech synthesis credentials. Both examples run locally.

## Choose an example

<!-- BEGIN GENERATED: examples -->
| Example | What you'll build | SDK / adapter | Language / level | Demo |
| --- | --- | --- | --- | --- |
| [Pipecat Simple Voice Bot](<01-simple-voice-bot/README.md>) | Run a Pipecat voice assistant through a local microphone and speakers. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python<br>intermediate | [Local](<01-simple-voice-bot/README.md>) |
| [Pipecat Simple Voice Bot (Web)](<02-simple-voice-bot-web/README.md>) | Build a browser voice assistant with Pipecat WebRTC and local turn analysis. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python<br>intermediate | [Local](<02-simple-voice-bot-web/README.md>) |

### Demo access

- [Pipecat Simple Voice Bot](<01-simple-voice-bot/README.md>): Requires local microphone and speaker access plus PortAudio; the Web example uses browser audio.
- [Pipecat Simple Voice Bot (Web)](<02-simple-voice-bot-web/README.md>): Use macOS, Linux, or WSL2 for the documented backend setup; the client runs in a browser.

API reference: [Speechmatics Agent STT (Linden 1)](<https://docs.speechmatics.com/speech-to-text/agent-stt>).
<!-- END GENERATED: examples -->

## Related workflows

- [Voice agent examples](../../collections/voice-agents/README.md) — start with Agent STT directly or compare application frameworks.
- [LiveKit examples](../livekit/README.md) — voice assistants, browser tools, and SIP phone applications.
- [Agent STT fundamentals](../../basics/13-agent-stt/README.md) — transcript segments, speaker identifiers, and service or external turn finalization.
- [Complete Academy catalog](../../docs/CATALOG.md) — browse by package, feature, language, and difficulty.

[Back to Academy](../../README.md)
