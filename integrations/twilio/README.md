<div align="center">

<img src="logo/twillio.png" alt="Twilio" width="200">

# Twilio + Speechmatics

**Connect phone calls to Speechmatics voice-agent applications.**

</div>

These examples offer two transport routes: Twilio SIP connected to LiveKit, and Twilio Media Streams handled directly by a Python application. The LiveKit applications use agent STT; the direct outbound dialer retains the deprecated Voice SDK.

**Start with [LiveKit Telephony with Twilio](../livekit/02-telephony-twilio/README.md)** for the SIP route with Agent STT, an OpenAI LLM, and Speechmatics Text to Speech.

## Choose a workflow

- **Inbound phone assistant:** [LiveKit Telephony with Twilio](../livekit/02-telephony-twilio/README.md) introduces Twilio Elastic SIP Trunking and LiveKit call handling.
- **Booking and business tools:** [AI Receptionist](../../use-cases/04-voice-agent-calendar/README.md) adds Google Calendar operations.
- **Character voice:** [Santa Voice Agent](../../use-cases/05-santa-voice-agent/README.md) adds a character prompt and ElevenLabs voice, with optional Twilio SIP calls.
- **Direct outbound calls:** [Twilio Outbound Dialer](01-outbound-dialer/README.md) initiates calls with the Twilio REST API and handles Media Streams. This is a legacy Voice SDK reference; migration to Agent STT requires changes to the audio and event handling.

Follow the chosen README for phone numbers, SIP or webhook routing, provider credentials, and local services.

## Choose an example

<!-- BEGIN GENERATED: examples -->
| Example | What you'll build | SDK / adapter | Language / level | Demo |
| --- | --- | --- | --- | --- |
| [LiveKit Telephony with Twilio](<../livekit/02-telephony-twilio/README.md>) | Receive phone calls through Twilio SIP and respond with a LiveKit voice assistant. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python<br>intermediate | [Local](<../livekit/02-telephony-twilio/README.md>) |
| [Twilio Outbound Dialer](<01-outbound-dialer/README.md>) **Legacy** | Start outbound phone calls with Twilio Media Streams and the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>) | Python<br>advanced | [Local](<01-outbound-dialer/README.md>) |
| [AI Receptionist](<../../use-cases/04-voice-agent-calendar/README.md>) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python<br>advanced | [Local](<../../use-cases/04-voice-agent-calendar/README.md>) |
| [Santa Voice Agent](<../../use-cases/05-santa-voice-agent/README.md>) | Build a Santa character voice assistant with LiveKit and optional phone calls. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python<br>advanced | [Local](<../../use-cases/05-santa-voice-agent/README.md>) |

### Demo access

- [LiveKit Telephony with Twilio](<../livekit/02-telephony-twilio/README.md>): Phone testing requires a Twilio number and configured SIP trunking.
- [Twilio Outbound Dialer](<01-outbound-dialer/README.md>): Starts real outbound calls. Protect the dial endpoint and validate Twilio callbacks before exposing a tunnel.
- [AI Receptionist](<../../use-cases/04-voice-agent-calendar/README.md>): Use a dedicated test calendar: the agent can create, move, and delete real events.

API reference: [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>) · [Speechmatics Agent STT (Linden 1)](<https://docs.speechmatics.com/speech-to-text/agent-stt>) · [Speechmatics Text to Speech API](<https://docs.speechmatics.com/text-to-speech/quickstart>).
<!-- END GENERATED: examples -->

## Related workflows

- [Telephony examples](../../collections/telephony/README.md) — include Batch analysis of recorded calls alongside live phone agents.
- [LiveKit examples](../livekit/README.md) — explore the framework's other voice applications.
- [Voice agent examples](../../collections/voice-agents/README.md) — compare current foundations and legacy references.
- [Complete Academy catalog](../../docs/CATALOG.md) — browse by package, feature, integration, and difficulty.

[Back to Academy](../../README.md)
