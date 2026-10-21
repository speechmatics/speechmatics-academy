<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="logos/speechmatics-academy-white-2400x600.png">
  <source media="(prefers-color-scheme: light)" srcset="logos/speechmatics-academy-black-2400x600.png">
  <img alt="Speechmatics Academy" src="logos/speechmatics-academy-black-2400x600.png" width="70%">
</picture>

**Code examples for building with Speechmatics APIs and SDKs.**

[Quick start](#quick-start) · [Examples](#example-categories) · [Contributing](#contributing) · [Documentation](https://docs.speechmatics.com/) · [portal](https://portal.speechmatics.com/)

</div>

## What is Speechmatics?

Speechmatics provides **Speech to Text (STT)** and **Text to Speech (TTS)**. Use the Batch API to transcribe pre-recorded audio, the Realtime API to transcribe streaming audio, and agent STT to receive transcript segments and turn events for a voice agent that you build with an LLM and TTS.

These examples demonstrate individual features and application patterns. Each README explains its setup, dependencies, and limitations. Deployment and feature availability depend on the model and API; see the [model comparison](https://docs.speechmatics.com/speech-to-text/models) and [deployment documentation](https://docs.speechmatics.com/deployments).

## Contents

- [Quick start](#quick-start)
- [Concepts and model selection](#theory)
- [Example categories](#example-categories)
- [Community projects](#community-projects)
- [Migration guides](#migration-guides)
- [Finding examples](#finding-examples)
- [Example structure](#example-structure)
- [Contributing](#contributing)
- [Support and resources](#support--resources)

<h2 id="quick-start">Quick start</h2>

Create an [API key in the portal](https://portal.speechmatics.com/). Use Python 3.12 for the Python examples to match the repository's CI environment; check the selected example for additional runtime, microphone, and service requirements.

Clone the repository and open the first example:

```bash
git clone https://github.com/speechmatics/speechmatics-academy.git
cd speechmatics-academy/basics/01-hello-world/python
python -m venv .venv
```

Activate the environment in **PowerShell**:

```powershell
.\.venv\Scripts\Activate.ps1
Copy-Item ..\.env.example .env
```

Or activate it in **macOS/Linux**:

```bash
source .venv/bin/activate
cp ../.env.example .env
```

Add `SPEECHMATICS_API_KEY` to `.env`, then install and run:

```bash
python -m pip install -r requirements.txt
python main.py
```

Keep API keys out of source control. Use a separate environment for each example so its dependencies can be installed independently.

### Choose an SDK

Install the requirements supplied with an example. For your own project, choose the package that matches the API you need:

<details>
<summary><strong>📦 Package details</strong> • Click to see what's included in each package</summary>

| Package | Purpose | Start here |
|---|---|---|
| `speechmatics-batch` | Submit audio files and retrieve transcripts | [Hello World](basics/01-hello-world/) |
| `speechmatics-rt` | Stream audio over WebSocket and receive partial and final transcripts | [Batch vs Realtime](basics/02-batch-vs-realtime/) |
| `speechmatics-agent-stt` | Receive speaker-attributed segments and speech and turn events | [Agent STT](basics/13-agent-stt/) |
| `speechmatics-tts` | Generate speech from text | [Text to Speech](basics/06-text-to-speech/) |
| `speechmatics-voice` | Maintain existing applications using client-side segmentation and turn presets | [Legacy turn detection example](basics/08-voice-agent-turn-detection/) |

</details>

The [Voice SDK is deprecated](https://docs.speechmatics.com/integrations-and-sdks/voice-sdk). Start new voice-agent transcription integrations with agent STT or the current LiveKit and Pipecat integrations. Your application or framework supplies the LLM, speech synthesis, tools, and conversation logic.

<h2 id="theory">Concepts and model selection</h2>

| What you need | Documentation | Academy example |
|---|---|---|
| Transcribe a recording | [Batch transcription](https://docs.speechmatics.com/speech-to-text/batch/quickstart) | [Hello World](basics/01-hello-world/) |
| Receive transcripts while audio streams | [Realtime transcription](https://docs.speechmatics.com/speech-to-text/realtime/quickstart) | [Basic turn detection](basics/07-turn-detection/) |
| Detect turns for a voice agent | [Agent STT](https://docs.speechmatics.com/speech-to-text/agent-stt) | [Agent STT with Linden 1](basics/13-agent-stt/) |
| Transcribe audio containing multiple languages | [Melia 1](https://docs.speechmatics.com/speech-to-text/models#melia-1) | [Batch multilingual transcription](basics/12-melia-multilingual/) or [Wall of Voices](use-cases/10-wall-of-voices/) |
| Transcribe multilingual healthcare audio | [Oak 1](https://docs.speechmatics.com/speech-to-text/models#oak-1) | [Oak Consultation Studio](use-cases/11-oak-consultation-studio/) |
| Use medical recognition with the Enhanced model | [Enhanced Medical](https://docs.speechmatics.com/speech-to-text/models#healthcare-domain) | [Medical transcription](use-cases/01-medical-transcription-realtime/) |
| Generate speech | [Text to Speech](https://docs.speechmatics.com/text-to-speech/quickstart) | [Text to Speech](basics/06-text-to-speech/) |

Melia 1 supports Batch and Realtime transcription. Oak 1 supports Batch transcription. Both use `language="multi"`, and their feature support differs from Standard and Enhanced. Oak 1 is distinct from the Medical sub-variant of Enhanced, selected with `domain="medical"`. Check the [model comparison](https://docs.speechmatics.com/speech-to-text/models) before combining features.

Use `model` in new Batch and Realtime configurations. The older `operating_point` property remains compatible but is deprecated for SaaS on Cloud. Agent STT uses Linden 1 and the `/v2/agent` endpoint. Consult the [release notes](https://speechmatics.featurebase.app/en/changelog) for changes to service capabilities.

<h2 id="example-categories">Example categories</h2>

### Basics

| Example | What it demonstrates |
|---|---|
| [01 · Hello World](basics/01-hello-world/) | Submit an audio file to the Batch API |
| [02 · Batch vs Realtime](basics/02-batch-vs-realtime/) | Compare file transcription with microphone streaming |
| [03 · Configuration guide](basics/03-configuration-guide/) | Configure transcription, speaker diarization, and a custom dictionary |
| [04 · Speech intelligence](basics/04-audio-intelligence/) | Request sentiment, topics, and summaries with Batch transcription |
| [05 · Multilingual transcription and translation](basics/05-multilingual-translation/) | Select a transcription language and translate streaming output |
| [06 · Text to Speech](basics/06-text-to-speech/) | Generate audio from text |
| [07 · Basic turn detection](basics/07-turn-detection/) | Detect an end of utterance with the Realtime API |
| [08 · Voice SDK turn detection](basics/08-voice-agent-turn-detection/) | Explore presets in the deprecated Voice SDK |
| [09 · Voice SDK speaker identification and focus](basics/09-voice-agent-speaker-id/) | Reuse speaker identifiers and filter speakers in an existing Voice SDK application |
| [10 · Channel diarization](basics/10-channel-diarization/) | Attribute transcripts to separate audio channels |
| [11 · Voice API Explorer](basics/11-voice-api-explorer/) | Inspect the older preview protocol in Python and JavaScript; see its compatibility notes |
| [12 · Melia 1 multilingual transcription](basics/12-melia-multilingual/) | Transcribe code-switching audio with the Batch API |
| [13 · Agent STT](basics/13-agent-stt/) | Receive segments, speech and turn events, and reusable speaker identifiers |

### Integrations

| Integration | Example | What it demonstrates |
|---|---|---|
| <picture><source media="(prefers-color-scheme: dark)" srcset="integrations/agora/logo/agora-logo-rgb-blue.svg"><source media="(prefers-color-scheme: light)" srcset="integrations/agora/logo/agora-logo-rgb-blue.svg"><img alt="Agora" src="integrations/agora/logo/agora-logo-rgb-blue.svg" height="22"></picture> | [Conversational AI agent](integrations/agora/01-conversational-ai-agent/) | Browser audio, transcripts, and a managed conversation pipeline |
| <picture><source media="(prefers-color-scheme: dark)" srcset="integrations/livekit/logo/LK_wordmark_darkbg.png"><source media="(prefers-color-scheme: light)" srcset="integrations/livekit/logo/LK_wordmark_lightbg.png"><img alt="LiveKit" src="integrations/livekit/logo/LK_wordmark_lightbg.png" height="19"></picture> | [Simple voice assistant](integrations/livekit/01-simple-voice-assistant/) | Connect transcription, an LLM, and speech synthesis |
| <picture><source media="(prefers-color-scheme: dark)" srcset="integrations/livekit/logo/LK_wordmark_darkbg.png"><source media="(prefers-color-scheme: light)" srcset="integrations/livekit/logo/LK_wordmark_lightbg.png"><img alt="LiveKit" src="integrations/livekit/logo/LK_wordmark_lightbg.png" height="19"></picture> | [Telephony](integrations/livekit/02-telephony-twilio/) | Connect phone calls through SIP |
| <picture><source media="(prefers-color-scheme: dark)" srcset="integrations/livekit/logo/LK_wordmark_darkbg.png"><source media="(prefers-color-scheme: light)" srcset="integrations/livekit/logo/LK_wordmark_lightbg.png"><img alt="LiveKit" src="integrations/livekit/logo/LK_wordmark_lightbg.png" height="19"></picture> | [Speaker focus](integrations/livekit/03-speaker-focus-voice-agent/) | Apply speaker focus and speaker memory in an application |
| <img src="integrations/pipecat/logo/pipecat.png" alt="Pipecat" height="28"> | [Local voice bot](integrations/pipecat/01-simple-voice-bot/) | Run a voice pipeline with local microphone and speaker audio |
| <img src="integrations/pipecat/logo/pipecat.png" alt="Pipecat" height="28"> | [Web voice bot](integrations/pipecat/02-simple-voice-bot-web/) | Connect a browser through WebRTC |
| <img src="integrations/twilio/logo/twillio.png" alt="Twilio" height="28"> | [Outbound dialer](integrations/twilio/01-outbound-dialer/) | Place calls and process Media Streams using the deprecated Voice SDK |
| <div align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="integrations/vapi/logo/vapi-light.png"><source media="(prefers-color-scheme: light)" srcset="integrations/vapi/logo/vapi-dark.png"><img alt="VAPI" src="integrations/vapi/logo/vapi-dark.png" height="50"></picture></div> | [Voice assistant](integrations/vapi/01-voice-assistant/) | Configure Speechmatics transcription in Vapi |
| <div align="center"><img src="integrations/tambourine/logo/icon.png" alt="Tambourine" height="50"></div> | [Healthcare dictation](integrations/tambourine/01-healthcare-dictation/) | Configure desktop dictation and text formatting |

### Use cases

| Example | What it demonstrates |
|---|---|
| [01 · Medical transcription](use-cases/01-medical-transcription-realtime/) | Stream healthcare audio with Enhanced Medical and a custom dictionary |
| [02 · Video captioning](use-cases/02-video-captioning/) | Generate SRT captions from pre-recorded media |
| [03 · Call center analytics](use-cases/03-call-center-analytics/) | Combine diarization with sentiment, topics, and summaries |
| [04 · Calendar receptionist](use-cases/04-voice-agent-calendar/) | Connect a LiveKit voice agent to Google Calendar tools |
| [05 · Santa voice agent](use-cases/05-santa-voice-agent/) | Configure a character prompt, speech synthesis, and telephony |
| [06 · Medical assistant](use-cases/06-medical-assistant/) | Combine bilingual transcription with LLM extraction and draft clinical notes |
| [07 · Medical microbatching](use-cases/07-medical-microbatching/) | Split microphone audio into chunks and submit Batch jobs |
| [08 · Alphanumerics form filler](use-cases/08-alphanumerics-form-filler/) | Collect spoken details and update a browser form through LiveKit RPC |
| [09 · Flutter mobile transcription](use-cases/09-flutter-mobile-transcription/) | Record or upload audio and configure Batch transcription from a mobile app |
| [10 · Wall of Voices](use-cases/10-wall-of-voices/) | Display streaming Melia 1 transcripts with per-word language labels |
| [11 · Oak Consultation Studio](use-cases/11-oak-consultation-studio/) | Explore multilingual healthcare transcripts, audio playback, and language hints |

<h2 id="community-projects">Community projects</h2>

Community contributions can use any programming language. See the [community guide](community/README.md) for submission requirements, maintenance expectations, and the Community and Verified review tiers. There are currently no community projects in the repository.

<h2 id="migration-guides">Migration guides</h2>

The [Deepgram migration guide](guides/migration-guides/deepgram/) compares transcription concepts and includes Python source examples. Use the current SDK documentation alongside the guide when porting an application.

<h2 id="finding-examples">Finding examples</h2>

Use the tables above to choose a workflow, then read that example's prerequisites. The [catalog](docs/index.yaml) contains metadata for search and filtering; the README beside each implementation describes how to run it.

Python examples cover the APIs and integrations. JavaScript examples include the [Voice API Explorer](basics/11-voice-api-explorer/), [Wall of Voices](use-cases/10-wall-of-voices/), and [Oak Consultation Studio](use-cases/11-oak-consultation-studio/). The [Agora example](integrations/agora/01-conversational-ai-agent/) has a TypeScript frontend, and the [mobile app](use-cases/09-flutter-mobile-transcription/) uses Dart and Flutter.

<h2 id="example-structure">Example structure</h2>

Small Python examples usually follow this layout:

```text
example-name/
├── python/
│   ├── main.py
│   └── requirements.txt
├── assets/
├── .env.example
└── README.md
```

Web and mobile applications use the layout appropriate to their framework. Follow their README for the working directory, environment-file location, start command, and tests.

<h2 id="contributing">Contributing</h2>

Read the [contribution guide](docs/CONTRIBUTING.md) before adding an example. Use the [example template](docs/EXAMPLE_TEMPLATE.md), document the required runtime and services, add catalog metadata, and test from a fresh checkout. Include the checks you ran and any API-dependent steps in your pull request.

Bug fixes, clearer setup instructions, additional language implementations, and focused examples are welcome. For a larger addition or refactor, open an [issue](https://github.com/speechmatics/speechmatics-academy/issues) to discuss scope.

<h2 id="support--resources">Support and resources</h2>

- [Speechmatics documentation](https://docs.speechmatics.com/)
- [API reference](https://docs.speechmatics.com/api-ref)
- [Python SDK repository](https://github.com/speechmatics/speechmatics-python-sdk)
- [Release notes](https://speechmatics.featurebase.app/en/changelog)
- [API keys and account management in the portal](https://portal.speechmatics.com/)
- [Academy issues](https://github.com/speechmatics/speechmatics-academy/issues)
- [Community discussions](https://github.com/speechmatics/community/discussions/categories/academy)
- [Discord](https://discord.gg/speechmatics)

## License

Speechmatics Academy is available under the [MIT License](LICENSE).
