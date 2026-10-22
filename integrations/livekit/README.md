<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="logo/LK_wordmark_darkbg.png">
  <source media="(prefers-color-scheme: light)" srcset="logo/LK_wordmark_lightbg.png">
  <img alt="LiveKit" src="logo/LK_wordmark_lightbg.png" width="300">
</picture>

# LiveKit + Speechmatics

**Build voice-agent applications with LiveKit and Speechmatics Speech to Text.**

</div>

LiveKit provides the application framework and audio transport. Speechmatics supplies agent STT, powered by Linden 1. The examples combine this transcription layer with an LLM, Text to Speech, and application tools.

**Start with the [Simple Voice Assistant](01-simple-voice-assistant/README.md)** to learn the voice pipeline. LiveKit Agents Playground connects to your own running agent and credentials.

## Choose a workflow

- **Control which speakers drive responses:** [Speaker Focus](03-speaker-focus-voice-agent/README.md) adds a browser visualizer, reusable speaker identifiers, and application-side turn filtering.
- **Update a browser from conversation:** [Alphanumerics Form Filler](../../use-cases/08-alphanumerics-form-filler/README.md) connects voice-agent tools to form fields through LiveKit RPC.
- **Connect a phone number:** [Telephony with Twilio](02-telephony-twilio/README.md) introduces the SIP connection. Continue with [AI Receptionist](../../use-cases/04-voice-agent-calendar/README.md) for calendar tools or [Santa Voice Agent](../../use-cases/05-santa-voice-agent/README.md) for a character prompt and voice.

Follow each README for its runtime and provider setup.

## Choose an example

<!-- BEGIN GENERATED: examples -->
| Example | What you'll build | SDK / adapter | Language / level | Demo |
| --- | --- | --- | --- | --- |
| [LiveKit Voice Assistant](<01-simple-voice-assistant/README.md>) | Build a LiveKit voice assistant with Agent STT, speaker labels, an LLM, and TTS. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python<br>intermediate | [Local](<01-simple-voice-assistant/README.md>) |
| [LiveKit Telephony with Twilio](<02-telephony-twilio/README.md>) | Receive phone calls through Twilio SIP and respond with a LiveKit voice assistant. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python<br>intermediate | [Local](<02-telephony-twilio/README.md>) |
| [Speaker Focus Voice Agent](<03-speaker-focus-voice-agent/README.md>) | Filter completed Agent STT turns by speaker in a LiveKit app with a browser visualizer. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript<br>intermediate | [Local](<03-speaker-focus-voice-agent/README.md>) |
| [AI Receptionist](<../../use-cases/04-voice-agent-calendar/README.md>) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python<br>advanced | [Local](<../../use-cases/04-voice-agent-calendar/README.md>) |
| [Santa Voice Agent](<../../use-cases/05-santa-voice-agent/README.md>) | Build a Santa character voice assistant with LiveKit and optional phone calls. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python<br>advanced | [Local](<../../use-cases/05-santa-voice-agent/README.md>) |
| [Alphanumerics Voice Form Filler](<../../use-cases/08-alphanumerics-form-filler/README.md>) | Fill a browser form with spoken names, email addresses, and numbers through LiveKit. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript<br>intermediate | [Local](<../../use-cases/08-alphanumerics-form-filler/README.md>) |

### Demo access

- [LiveKit Telephony with Twilio](<02-telephony-twilio/README.md>): Phone testing requires a Twilio number and configured SIP trunking.
- [AI Receptionist](<../../use-cases/04-voice-agent-calendar/README.md>): Use a dedicated test calendar: the agent can create, move, and delete real events.

API reference: [Speechmatics Agent STT (Linden 1)](<https://docs.speechmatics.com/speech-to-text/agent-stt>) · [Speechmatics Text to Speech API](<https://docs.speechmatics.com/text-to-speech/quickstart>).
<!-- END GENERATED: examples -->

## Related examples and documentation

- [Healthcare examples](../../collections/healthcare/README.md) — transcription and dictation workflows for healthcare applications.
- [Twilio examples](../twilio/README.md) — compare LiveKit SIP applications with the direct Media Streams example.
- [Agent STT fundamentals](../../basics/13-agent-stt/README.md) — understand segments, speaker labels, and turn events without a framework.
- [Speechmatics LiveKit documentation](https://docs.speechmatics.com/integrations-and-sdks/livekit) — current plugin setup and configuration.
- [Complete Academy catalog](../../docs/CATALOG.md) — discover examples by package, feature, language, and difficulty.

[Back to Academy](../../README.md)
