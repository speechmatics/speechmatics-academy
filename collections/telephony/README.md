<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../../logos/speechmatics-academy-white-2400x600.png">
  <source media="(prefers-color-scheme: light)" srcset="../../logos/speechmatics-academy-black-2400x600.png">
  <img alt="Speechmatics Academy" src="../../logos/speechmatics-academy-black-2400x600.png" width="320">
</picture>

# Telephony examples

**Build phone assistants or analyze recorded conversations.**

</div>

Choose between a live call pipeline and a recording workflow. LiveKit SIP applications combine Speechmatics agent STT with conversation tools and speech synthesis. The direct Twilio Media Streams example uses the deprecated Voice SDK. Recorded-call analysis submits existing audio to the Batch API and does not connect to a phone network.

**Start with [LiveKit Telephony with Twilio](../../integrations/livekit/02-telephony-twilio/README.md)** to build an inbound phone assistant using Agent STT and Speechmatics Text to Speech.

## Choose a workflow

- **Receive calls through SIP:** [LiveKit Telephony with Twilio](../../integrations/livekit/02-telephony-twilio/README.md) introduces the call transport and agent pipeline.
- **Add a business task or character:** [AI Receptionist](../../use-cases/04-voice-agent-calendar/README.md) adds calendar tools; [Santa Voice Agent](../../use-cases/05-santa-voice-agent/README.md) adds character instructions and a custom voice.
- **Study direct Media Streams:** [Twilio Outbound Dialer](../../integrations/twilio/01-outbound-dialer/README.md) is the legacy route for initiating and processing outbound calls without LiveKit.
- **Analyze recordings:** [Call Center Analytics](../../use-cases/03-call-center-analytics/README.md) processes stereo call audio with channel labels, sentiment, topics, and summaries. Its labels follow the recording's separate audio channels.

Live call examples need telephony routing and provider accounts. Recorded-call analysis starts with an audio file and a Speechmatics API key.

## Choose an example

<!-- BEGIN GENERATED: examples -->
| Example | What you'll build | SDK / adapter | Language / level | Demo |
| --- | --- | --- | --- | --- |
| [LiveKit Telephony with Twilio](<../../integrations/livekit/02-telephony-twilio/README.md>) | Receive phone calls through Twilio SIP and respond with a LiveKit voice assistant. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python<br>intermediate | [Local](<../../integrations/livekit/02-telephony-twilio/README.md>) |
| [Twilio Outbound Dialer](<../../integrations/twilio/01-outbound-dialer/README.md>) **Legacy** | Start outbound phone calls with Twilio Media Streams and the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>) | Python<br>advanced | [Local](<../../integrations/twilio/01-outbound-dialer/README.md>) |
| [Call Center Analytics](<../../use-cases/03-call-center-analytics/README.md>) | Analyze recorded calls with channel labels, sentiment, topics, and summaries. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python<br>beginner | [Local](<../../use-cases/03-call-center-analytics/README.md>) |
| [AI Receptionist](<../../use-cases/04-voice-agent-calendar/README.md>) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python<br>advanced | [Local](<../../use-cases/04-voice-agent-calendar/README.md>) |
| [Santa Voice Agent](<../../use-cases/05-santa-voice-agent/README.md>) | Build a Santa character voice assistant with LiveKit and optional phone calls. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python<br>advanced | [Local](<../../use-cases/05-santa-voice-agent/README.md>) |

### Demo access

- [LiveKit Telephony with Twilio](<../../integrations/livekit/02-telephony-twilio/README.md>): Phone testing requires a Twilio number and configured SIP trunking.
- [Twilio Outbound Dialer](<../../integrations/twilio/01-outbound-dialer/README.md>): Starts real outbound calls. Protect the dial endpoint and validate Twilio callbacks before exposing a tunnel.
- [AI Receptionist](<../../use-cases/04-voice-agent-calendar/README.md>): Use a dedicated test calendar: the agent can create, move, and delete real events.

API reference: [Speechmatics Batch API](<https://docs.speechmatics.com/speech-to-text/batch/quickstart>) · [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>) · [Speechmatics Agent STT (Linden 1)](<https://docs.speechmatics.com/speech-to-text/agent-stt>) · [Speechmatics Text to Speech API](<https://docs.speechmatics.com/text-to-speech/quickstart>).
<!-- END GENERATED: examples -->

## Related workflows

- [Twilio examples](../../integrations/twilio/README.md) — compare SIP and direct Media Streams.
- [LiveKit examples](../../integrations/livekit/README.md) — voice agents and application tools.
- [Captions and insights](../captions-insights/README.md) — transcription, captions, and analysis of audio content.
- [Complete Academy catalog](../../docs/CATALOG.md) — find examples by feature, language, or package.

[Back to Academy](../../README.md)
