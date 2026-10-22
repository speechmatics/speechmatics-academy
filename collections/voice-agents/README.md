<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../../logos/speechmatics-academy-white-2400x600.png">
  <source media="(prefers-color-scheme: light)" srcset="../../logos/speechmatics-academy-black-2400x600.png">
  <img alt="Speechmatics Academy" src="../../logos/speechmatics-academy-black-2400x600.png" width="320">
</picture>

# Voice agent examples

**Build conversational applications from transcription, turn events, an LLM, and speech synthesis.**

</div>

Speechmatics provides the Speech to Text layer. An application or framework connects it to an LLM, Text to Speech, tools, and audio transport. Agent STT, powered by Linden 1, supplies transcript segments, speaker labels, and speech and turn events for this pipeline.

**Start with [Agent STT Linden 1](../../basics/13-agent-stt/README.md)** to understand segments, speaker identifiers, and who finalizes each turn. For a complete conversational application, continue with the [LiveKit Simple Voice Assistant](../../integrations/livekit/01-simple-voice-assistant/README.md) or [Pipecat Simple Voice Bot](../../integrations/pipecat/01-simple-voice-bot/README.md).

## Choose a workflow

- **Learn transcription and turn handling:** [Agent STT](../../basics/13-agent-stt/README.md) demonstrates service VAD and external finalization. [Basic Turn Detection](../../basics/07-turn-detection/README.md) separately demonstrates silence-based end-of-utterance events with the Realtime SDK.
- **Choose an application framework:** [LiveKit](../../integrations/livekit/README.md) covers voice assistants, speaker controls, browser tools, and phone applications. [Pipecat](../../integrations/pipecat/README.md) offers local audio and browser WebRTC pipelines.
- **Use a managed conversational platform:** [Agora](../../integrations/agora/01-conversational-ai-agent/README.md) and [Vapi](../../integrations/vapi/01-voice-assistant/README.md) use Speechmatics streaming transcription within their managed pipelines; these examples do not configure Agent STT.
- **Add tools or a character:** [AI Receptionist](../../use-cases/04-voice-agent-calendar/README.md) uses calendar tools, [Alphanumerics Form Filler](../../use-cases/08-alphanumerics-form-filler/README.md) updates a browser through LiveKit RPC, and [Santa Voice Agent](../../use-cases/05-santa-voice-agent/README.md) combines a character prompt with speech synthesis.

## Choose an example

<!-- BEGIN GENERATED: examples -->
### Current examples

| Example | What you'll build | SDK / adapter | Language / level | Demo |
| --- | --- | --- | --- | --- |
| [Basic Turn Detection](<../../basics/07-turn-detection/README.md>) | Detect the end of speech using silence-based turn detection. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python<br>intermediate | [Local](<../../basics/07-turn-detection/README.md>) |
| [Agent STT Linden 1 - Segments, Turns and Speakers](<../../basics/13-agent-stt/README.md>) | Handle transcript segments, turns, and speakers with Agent STT Linden 1. | [Agent STT](<https://pypi.org/project/speechmatics-agent-stt/>) | Python<br>intermediate | [Local](<../../basics/13-agent-stt/README.md>) |
| [Agora Conversational AI Voice Agent](<../../integrations/agora/01-conversational-ai-agent/README.md>) | Build a browser voice agent with Agora audio, transcripts, and a managed LLM/TTS pipeline. | [Agora Agents](<https://pypi.org/project/agora-agents/>) | Python, TypeScript<br>intermediate | [Recording](<../../integrations/agora/01-conversational-ai-agent/assets/agora-conversational-ai.gif>) · [Local](<../../integrations/agora/01-conversational-ai-agent/README.md>) |
| [LiveKit Voice Assistant](<../../integrations/livekit/01-simple-voice-assistant/README.md>) | Build a LiveKit voice assistant with Agent STT, speaker labels, an LLM, and TTS. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python<br>intermediate | [Local](<../../integrations/livekit/01-simple-voice-assistant/README.md>) |
| [LiveKit Telephony with Twilio](<../../integrations/livekit/02-telephony-twilio/README.md>) | Receive phone calls through Twilio SIP and respond with a LiveKit voice assistant. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python<br>intermediate | [Local](<../../integrations/livekit/02-telephony-twilio/README.md>) |
| [Speaker Focus Voice Agent](<../../integrations/livekit/03-speaker-focus-voice-agent/README.md>) | Filter completed Agent STT turns by speaker in a LiveKit app with a browser visualizer. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript<br>intermediate | [Local](<../../integrations/livekit/03-speaker-focus-voice-agent/README.md>) |
| [Pipecat Simple Voice Bot](<../../integrations/pipecat/01-simple-voice-bot/README.md>) | Run a Pipecat voice assistant through a local microphone and speakers. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python<br>intermediate | [Local](<../../integrations/pipecat/01-simple-voice-bot/README.md>) |
| [Pipecat Simple Voice Bot (Web)](<../../integrations/pipecat/02-simple-voice-bot-web/README.md>) | Build a browser voice assistant with Pipecat WebRTC and local turn analysis. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python<br>intermediate | [Local](<../../integrations/pipecat/02-simple-voice-bot-web/README.md>) |
| [Vapi Voice Assistant](<../../integrations/vapi/01-voice-assistant/README.md>) | Configure a Vapi voice assistant with Speechmatics STT and a custom dictionary. | [Vapi SDK](<https://pypi.org/project/vapi-server-sdk/>) | Python<br>beginner | [Local](<../../integrations/vapi/01-voice-assistant/README.md>) |
| [AI Receptionist](<../../use-cases/04-voice-agent-calendar/README.md>) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python<br>advanced | [Local](<../../use-cases/04-voice-agent-calendar/README.md>) |
| [Santa Voice Agent](<../../use-cases/05-santa-voice-agent/README.md>) | Build a Santa character voice assistant with LiveKit and optional phone calls. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python<br>advanced | [Local](<../../use-cases/05-santa-voice-agent/README.md>) |
| [Alphanumerics Voice Form Filler](<../../use-cases/08-alphanumerics-form-filler/README.md>) | Fill a browser form with spoken names, email addresses, and numbers through LiveKit. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript<br>intermediate | [Local](<../../use-cases/08-alphanumerics-form-filler/README.md>) |

### Legacy and preview examples

| Example | What you'll build | SDK / adapter | Language / level | Demo |
| --- | --- | --- | --- | --- |
| [Intelligent Turn Detection](<../../basics/08-voice-agent-turn-detection/README.md>) **Legacy** | Compare turn-detection presets in the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python<br>intermediate | [Local](<../../basics/08-voice-agent-turn-detection/README.md>) |
| [Speaker ID &amp; Speaker Focus](<../../basics/09-voice-agent-speaker-id/README.md>) **Legacy** | Save speaker identifiers and apply speaker focus with the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python<br>intermediate | [Local](<../../basics/09-voice-agent-speaker-id/README.md>) |
| [Preview WebSocket API Explorer](<../../basics/11-voice-api-explorer/README.md>) **Preview** | Explore raw WebSocket clients for the Voice API preview. | Direct API / configuration | Python, JavaScript<br>intermediate | [Local](<../../basics/11-voice-api-explorer/README.md>) |
| [Twilio Outbound Dialer](<../../integrations/twilio/01-outbound-dialer/README.md>) **Legacy** | Start outbound phone calls with Twilio Media Streams and the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>) | Python<br>advanced | [Local](<../../integrations/twilio/01-outbound-dialer/README.md>) |

### Demo access

- [LiveKit Telephony with Twilio](<../../integrations/livekit/02-telephony-twilio/README.md>): Phone testing requires a Twilio number and configured SIP trunking.
- [Pipecat Simple Voice Bot](<../../integrations/pipecat/01-simple-voice-bot/README.md>): Requires local microphone and speaker access plus PortAudio; the Web example uses browser audio.
- [Pipecat Simple Voice Bot (Web)](<../../integrations/pipecat/02-simple-voice-bot-web/README.md>): Use macOS, Linux, or WSL2 for the documented backend setup; the client runs in a browser.
- [AI Receptionist](<../../use-cases/04-voice-agent-calendar/README.md>): Use a dedicated test calendar: the agent can create, move, and delete real events.
- [Preview WebSocket API Explorer](<../../basics/11-voice-api-explorer/README.md>): Confirm access to the Voice API preview and its older agent profile routes before running.
- [Twilio Outbound Dialer](<../../integrations/twilio/01-outbound-dialer/README.md>): Starts real outbound calls. Protect the dial endpoint and validate Twilio callbacks before exposing a tunnel.

API reference: [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>) · [Speechmatics Agent STT (Linden 1)](<https://docs.speechmatics.com/speech-to-text/agent-stt>) · [Speechmatics Text to Speech API](<https://docs.speechmatics.com/text-to-speech/quickstart>).

The Voice API preview is a legacy protocol, separate from Agent STT.
<!-- END GENERATED: examples -->

## Related workflows

- [Telephony examples](../telephony/README.md) — connect live calls or analyze recordings.
- [Multilingual examples](../multilingual/README.md) — compare recognition and translation workflows.
- [Complete Academy catalog](../../docs/CATALOG.md) — browse by package, feature, integration, and difficulty.

[Back to Academy](../../README.md)
