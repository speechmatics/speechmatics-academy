<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="logos/speechmatics-academy-white-2400x600.png">
  <source media="(prefers-color-scheme: light)" srcset="logos/speechmatics-academy-black-2400x600.png">
  <img alt="Speechmatics Academy" src="logos/speechmatics-academy-black-2400x600.png" width="70%">
</picture>

<br/>
<br/>

**Working examples, integrations, and templates for the Speechmatics SDK's.**

Comprehensive collection of code examples demonstrating real-world applications, third-party integrations, and best practices.


**Examples • Integrations • Use Cases • Copy-Paste Ready**

[Browse Examples](#example-categories) • [Quick Start](#quick-start) • [Contributing](#contributing) • [Portal](https://portal.speechmatics.com/)  • [Documentation](https://docs.speechmatics.com/)  

</div>

---

## What is Speechmatics?

[Speechmatics](https://www.speechmatics.com/) is a leading Automatic Speech Recognition (ASR) platform providing highly accurate speech-to-text (STT) and text-to-speech (TTS) APIs. Whether you're building real-time voice assistants, conversational voice AI agents, transcription services, or call center tools, Speechmatics provides the foundation for accurate, scalable speech AI.

**Flexible Deployment** — Cloud SaaS, on-premise, air-gapped environments, or on-device edge deployment.

**Advanced Features** — Domain-specific models, custom dictionaries, speaker diarization, speaker identification, and speaker focus for multi-speaker scenarios and much more.

---

## 📋 Table of Contents

- [What is Speechmatics?](#what-is-speechmatics)
- [Quick Start](#quick-start)
- [Theory](#theory)
- [Example Categories](#example-categories)
- [Migration Guides](#migration-guides)
- [Finding Examples](#finding-examples)
- [Example Structure](#example-structure)
- [Contributing](#contributing)
- [Support & Resources](#support--resources)


---

<h2 id="quick-start">⚡ Quick Start</h2>

### Prerequisites

**1. Get your API Key**  [portal.speechmatics.com](https://portal.speechmatics.com/)


**2. Install the SDK** for your use case:

```bash
# Choose the package for your use case:

# Batch transcription
pip install speechmatics-batch

# Real-time streaming
pip install speechmatics-rt

# Voice agents
pip install speechmatics-voice

# Text-to-speech
pip install speechmatics-tts
```
<details>

<summary><strong>📦 Package Details</strong> • Click to see what's included in each package</summary>

<br/>

**speechmatics-batch** - Async batch transcription API
- Upload audio files for processing
- Get transcripts with highly accurate timestamps, speakers, entities
- Supports all audio intelligence features

**speechmatics-rt** - Real-time WebSocket streaming
- Stream audio for live transcription
- Ultra-low latency
- Partial and final transcripts

**speechmatics-voice** - Voice agent SDK
- Build conversational AI applications
- Speaker diarization and turn detection
- Optional ML-based smart turn: `pip install speechmatics-voice[smart]`

**speechmatics-tts** - Text-to-speech
- Convert text to natural-sounding speech
- Multiple voices
- Streaming and batch modes

</details>

<br/>

[SDK Documentation](https://github.com/speechmatics/speechmatics-python-sdk) | [API Reference](https://docs.speechmatics.com/api-ref/)

### Option 1: Clone and Run

```bash
# Clone the repository
git clone https://github.com/speechmatics/speechmatics-academy.git
cd speechmatics-academy

# Navigate to an example
cd basics/01-hello-world/python

# Setup virtual environment
python -m venv venv

# Activate virtual environment (Windows)
venv\Scripts\activate
# On Mac/Linux: source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Set up environment variables
cp ../.env.example .env
# Edit .env and add your SPEECHMATICS_API_KEY

# Run the example
python main.py
```

> [!CAUTION]
> Never hardcode API keys in your source code. Always use environment variables (`.env` files) or secure secret management systems. Never commit `.env` to version control - only `.env.example` with placeholder values.


### Option 2: Direct Copy

Use [degit](https://github.com/Rich-Harris/degit) to copy individual examples:

```bash
# Install degit
npm install -g degit

# Copy an example
degit speechmatics/speechmatics-academy/basics/01-hello-world my-project
cd my-project
```
---

<h2 id="theory">📖 Theory</h2>

New to speech recognition? Start here to understand the core concepts before diving into code.

| Topic | Description |
|-------|-------------|
| **Introduction to ASR** | How automatic speech recognition converts audio to text using acoustic and language models |
| **Introduction to LLMs** | Understanding large language models and their role in voice AI applications |
| **Prompt Engineering** | Crafting effective prompts for voice agents and conversational AI |
| **Choosing the Right Model** | Comparing model types, capabilities, and when to use each |

> [!NOTE]
> Theory guides are coming soon. In the meantime, check out the **"How It Works"** sections in each example.

---

<h2 id="example-categories">📚 Example Categories</h2>

### Fundamentals

Fundamental examples for getting started with the Speechmatics SDK.

| Example | Description | Packages | Difficulty |
|---------|-------------|----------|------------|
| [Hello World](basics/01-hello-world/) | The absolute simplest transcription example | `Batch` |  Beginner |
| [Batch vs Real-time](basics/02-batch-vs-realtime/) | Learn the difference between API modes | `Batch` `RT` |  Beginner |
| [Configuration Guide](basics/03-configuration-guide/) | Common configuration options | `Batch` |  Beginner |
| [Text-to-Speech](basics/06-text-to-speech/) | Convert text to natural-sounding speech | `TTS` |  Beginner |
| [Channel Diarization](basics/10-channel-diarization/) | Multi-channel transcription with speaker attribution | `Voice` `RT` |  Beginner |
| [Audio Intelligence](basics/04-audio-intelligence/) | Extract insights with sentiment, topics, and summaries | `Batch` |  Intermediate |
| [Multilingual & Translation](basics/05-multilingual-translation/) | Transcribe 50+ languages and translate | `RT` |  Intermediate |
| [Basic Turn Detection](basics/07-turn-detection/) | Silence-based turn detection with Real-Time SDK | `RT` |  Intermediate |
| [Intelligent Turn Detection](basics/08-voice-agent-turn-detection/) | Smart turn detection with Voice SDK presets | `Voice` |  Intermediate |
| [Speaker ID & Speaker Focus](basics/09-voice-agent-speaker-id/) | Extract speaker IDs and control which speakers drive conversation | `Voice` |  Intermediate |

[Browse all basics examples](basics/)

---

### Integrations

Third-party framework and service integrations.

| Integration | Example | Features | Languages |
|-------------|---------|----------|-----------|
| <picture><source media="(prefers-color-scheme: dark)" srcset="integrations/livekit/logo/LK_wordmark_darkbg.png"><source media="(prefers-color-scheme: light)" srcset="integrations/livekit/logo/LK_wordmark_lightbg.png"><img alt="LiveKit" src="integrations/livekit/logo/LK_wordmark_lightbg.png" height="19"></picture> | [Simple Voice Assistant](integrations/livekit/01-simple-voice-assistant/) | WebRTC, VAD, diarization, focus speakers, passive filtering, LLM, TTS | Python |
| <picture><source media="(prefers-color-scheme: dark)" srcset="integrations/livekit/logo/LK_wordmark_darkbg.png"><source media="(prefers-color-scheme: light)" srcset="integrations/livekit/logo/LK_wordmark_lightbg.png"><img alt="LiveKit" src="integrations/livekit/logo/LK_wordmark_lightbg.png" height="19"></picture> | [Telephony with Twilio](integrations/livekit/02-telephony-twilio/) | Phone calls via SIP, LiveKit Agents, Krisp noise cancellation, LLM, TTS | Python |
| <img src="integrations/pipecat/logo/pipecat.png" alt="Pipecat" height="28"> | [Simple Voice Bot](integrations/pipecat/01-simple-voice-bot/) | Local audio, VAD, diarization, focus speakers, passive filtering, LLM, TTS, interruptions | Python |
| <img src="integrations/pipecat/logo/pipecat.png" alt="Pipecat" height="28"> | [Simple Voice Bot (Web)](integrations/pipecat/02-simple-voice-bot-web/) | Browser-based WebRTC, VAD, diarization, focus speakers, passive filtering, LLM, TTS | Python |
| <img src="integrations/twilio/logo/twillio.png" alt="Twilio" height="28"> | [Outbound Dialer](integrations/twilio/01-outbound-dialer/) | REST API, outbound calls, Media Streams, Speechmatics STT, ElevenLabs TTS | Python |
| <div align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="integrations/vapi/logo/vapi-light.png"><source media="(prefers-color-scheme: light)" srcset="integrations/vapi/logo/vapi-dark.png"><img alt="VAPI" src="integrations/vapi/logo/vapi-dark.png" height="50"></picture></div> | [Voice Assistant](integrations/vapi/01-voice-assistant/) | Voice AI platform, Speechmatics STT, diarization, custom vocabulary, LLM, TTS | Python |
| <picture><source media="(prefers-color-scheme: dark)" srcset="integrations/vercel/logo/vercel-logotype-dark.png"><source media="(prefers-color-scheme: light)" srcset="integrations/vercel/logo/vercel-logotype-light.png"><img alt="Vercel AI" src="integrations/vercel/logo/vercel-logotype-light.png" height="20"></picture> | Coming Soon | Vercel AI SDK integration | TypeScript |

[Browse all integrations](integrations/)

---

### Use Cases

Example applications for specific industries.

| Industry | Example | Features |
|----------|---------|----------|
| **Healthcare** | [Medical Transcription](use-cases/01-medical-transcription-realtime/) | Real-time, custom medical vocabulary, HIPAA compliance |
| **Media** | [Video Captioning](use-cases/02-video-captioning/) | SRT generation, timestamp sync, batch processing |
| **Contact Center** | [Call Analytics](use-cases/03-call-center-analytics/) | Channel diarization, sentiment analysis, topic detection, summarization |
| **Business** | [AI Receptionist](use-cases/04-voice-agent-calendar/) | LiveKit voice agent, Twilio SIP, Google Calendar booking, function calling |

[Browse all use cases](use-cases/)

---

<h2 id="migration-guides">🔄 Migration Guides</h2>

Switching from another speech-to-text provider? Our migration guides help you transition smoothly with feature mappings, code comparisons, and practical examples.

| From | Guide | Features Covered | Status |
|------|-------|------------------|--------|
| **Deepgram** | [Migration Guide](guides/migration-guides/deepgram/) | Batch, Streaming, Diarization, Custom Vocabulary | **Available** |
| **AssemblyAI** | Migration Guide | Transcription, Audio Intelligence, Real-time | Coming Soon |
| **Google Cloud Speech** | Migration Guide  | Batch, Streaming, Multi-language | Coming Soon |
| **AWS Transcribe** | Migration Guide | Batch Jobs, Streaming, Custom Vocabulary | Coming Soon |
| **Azure Speech** | Migration Guide | REST API, WebSocket, Pronunciation | Coming Soon |

> [!NOTE]
> Each migration guide includes:
> - **Feature Mapping** - Direct equivalent features comparison
> - **Code Comparison** - Side-by-side before/after examples
> - **Migration Checklist** - Step-by-step migration process
> - **Advantages** - Benefits of switching to Speechmatics
> - **Working Examples** - Complete runnable code

[Browse all migration guides](guides/migration-guides/)

---

<h2 id="finding-examples">🔍 Finding Examples</h2>
Find examples for the SDK package you installed:

### By Package


| Package | Description | Examples |
|---------|-------------|----------|
| **`speechmatics-batch`** | Async transcription of audio files | [Hello World](basics/01-hello-world/), [Batch vs Real-time](basics/02-batch-vs-realtime/), [Configuration Guide](basics/03-configuration-guide/), [Audio Intelligence](basics/04-audio-intelligence/), [Multilingual & Translation](basics/05-multilingual-translation/), [Video Captioning](use-cases/02-video-captioning/), [Call Analytics](use-cases/03-call-center-analytics/) |
| **`speechmatics-rt`** | Real-time transcription | [Batch vs Real-time](basics/02-batch-vs-realtime/), [Configuration Guide](basics/03-configuration-guide/), [Multilingual & Translation](basics/05-multilingual-translation/), [Basic Turn Detection](basics/07-turn-detection/), [Channel Diarization](basics/10-channel-diarization/), [Medical Transcription](use-cases/01-medical-transcription-realtime/) |
| **`speechmatics-voice`** | Voice agent with conversation management | [Intelligent Turn Detection](basics/08-voice-agent-turn-detection/), [Speaker ID & Speaker Focus](basics/09-voice-agent-speaker-id/), [Twilio Outbound Dialer](integrations/twilio/01-outbound-dialer/) |
| **`speechmatics-tts`** | Text-to-speech synthesis | [Text-to-Speech](basics/06-text-to-speech/) |

### By Feature

| Feature | Examples |
|---------|----------|
| **Batch Transcription** | [Hello World](basics/01-hello-world/), [Batch vs Real-time](basics/02-batch-vs-realtime/), [Configuration Guide](basics/03-configuration-guide/), [Audio Intelligence](basics/04-audio-intelligence/), [Video Captioning](use-cases/02-video-captioning/), [Call Analytics](use-cases/03-call-center-analytics/) |
| **Real-time** | [Batch vs Real-time](basics/02-batch-vs-realtime/), [Configuration Guide](basics/03-configuration-guide/), [Basic Turn Detection](basics/07-turn-detection/), [LiveKit Voice Assistant](integrations/livekit/01-simple-voice-assistant/), [Medical Transcription](use-cases/01-medical-transcription-realtime/) |
| **Turn Detection** | [Basic Turn Detection](basics/07-turn-detection/), [Intelligent Turn Detection](basics/08-voice-agent-turn-detection/) |
| **Voice Agents** | [Intelligent Turn Detection](basics/08-voice-agent-turn-detection/), [Speaker ID & Speaker Focus](basics/09-voice-agent-speaker-id/), [LiveKit Voice Assistant](integrations/livekit/01-simple-voice-assistant/), [Pipecat Voice Bot](integrations/pipecat/01-simple-voice-bot/), [Pipecat Voice Bot (Web)](integrations/pipecat/02-simple-voice-bot-web/), [Twilio Outbound Dialer](integrations/twilio/01-outbound-dialer/), [VAPI Voice Assistant](integrations/vapi/01-voice-assistant/), [AI Receptionist](use-cases/04-voice-agent-calendar/) |
| **Speaker Diarization** | [Configuration Guide](basics/03-configuration-guide/), [Speaker ID & Speaker Focus](basics/09-voice-agent-speaker-id/), [Channel Diarization](basics/10-channel-diarization/), [LiveKit Voice Assistant](integrations/livekit/01-simple-voice-assistant/), [Call Analytics](use-cases/03-call-center-analytics/) |
| **Speaker Identification** | [Speaker ID & Speaker Focus](basics/09-voice-agent-speaker-id/) |
| **Sentiment Analysis** | [Audio Intelligence](basics/04-audio-intelligence/), [Call Analytics](use-cases/03-call-center-analytics/) |
| **Topic Detection** | [Audio Intelligence](basics/04-audio-intelligence/), [Call Analytics](use-cases/03-call-center-analytics/) |
| **Summarization** | [Audio Intelligence](basics/04-audio-intelligence/), [Call Analytics](use-cases/03-call-center-analytics/) |
| **Translation** | [Multilingual & Translation](basics/05-multilingual-translation/) |
| **Text-to-Speech** | [Text-to-Speech](basics/06-text-to-speech/) |

### By Integration

| Integration | Examples | Documentation | Status |
|-------------|----------|---------------|--------|
| **LiveKit** | [Simple Voice Assistant](integrations/livekit/01-simple-voice-assistant/), [Telephony with Twilio](integrations/livekit/02-telephony-twilio/), [AI Receptionist](use-cases/04-voice-agent-calendar/) | [LiveKit Docs](https://docs.livekit.io/agents/models/stt/plugins/speechmatics/) | **Available** |
| **Pipecat AI** | [Simple Voice Bot](integrations/pipecat/01-simple-voice-bot/), [Simple Voice Bot (Web)](integrations/pipecat/02-simple-voice-bot-web/) | [Pipecat Docs](https://docs.pipecat.ai/server/services/stt/speechmatics#speechmatics) | **Available** |
| **Twilio** | [Outbound Dialer](integrations/twilio/01-outbound-dialer/), [Telephony with Twilio](integrations/livekit/02-telephony-twilio/), [AI Receptionist](use-cases/04-voice-agent-calendar/) | [Twilio Media Streams](https://www.twilio.com/docs/voice/media-streams) | **Available** |
| **VAPI** | [Voice Assistant](integrations/vapi/01-voice-assistant/) | [docs.vapi.ai](https://docs.vapi.ai/) | **Available** |

### By Language

| Language | Examples | Status |
|----------|----------|--------|
| **Python** | [Hello World](basics/01-hello-world/), [Batch vs Real-time](basics/02-batch-vs-realtime/), [Configuration Guide](basics/03-configuration-guide/), [Audio Intelligence](basics/04-audio-intelligence/), [Multilingual & Translation](basics/05-multilingual-translation/), [Text-to-Speech](basics/06-text-to-speech/), [Basic Turn Detection](basics/07-turn-detection/), [Intelligent Turn Detection](basics/08-voice-agent-turn-detection/), [Speaker ID & Speaker Focus](basics/09-voice-agent-speaker-id/), [Channel Diarization](basics/10-channel-diarization/), [LiveKit Voice Assistant](integrations/livekit/01-simple-voice-assistant/), [LiveKit Telephony](integrations/livekit/02-telephony-twilio/), [Pipecat Voice Bot](integrations/pipecat/01-simple-voice-bot/), [Pipecat Voice Bot (Web)](integrations/pipecat/02-simple-voice-bot-web/), [Twilio Outbound Dialer](integrations/twilio/01-outbound-dialer/), [VAPI Voice Assistant](integrations/vapi/01-voice-assistant/), [Medical Transcription](use-cases/01-medical-transcription-realtime/), [Video Captioning](use-cases/02-video-captioning/), [Call Analytics](use-cases/03-call-center-analytics/), [AI Receptionist](use-cases/04-voice-agent-calendar/) | **Available** |
| **Typescript** | - | Coming Soon |
| **C#** | - | Coming Soon |


### By Difficulty

| Difficulty | Examples |
|------------|----------|
| **Beginner** | [Hello World](basics/01-hello-world/), [Batch vs Real-time](basics/02-batch-vs-realtime/), [Configuration Guide](basics/03-configuration-guide/), [Text-to-Speech](basics/06-text-to-speech/), [Channel Diarization](basics/10-channel-diarization/), [VAPI Voice Assistant](integrations/vapi/01-voice-assistant/), [Video Captioning](use-cases/02-video-captioning/), [Call Analytics](use-cases/03-call-center-analytics/) |
| **Intermediate** | [Audio Intelligence](basics/04-audio-intelligence/), [Multilingual & Translation](basics/05-multilingual-translation/), [Basic Turn Detection](basics/07-turn-detection/), [Intelligent Turn Detection](basics/08-voice-agent-turn-detection/), [Speaker ID & Speaker Focus](basics/09-voice-agent-speaker-id/), [LiveKit Voice Assistant](integrations/livekit/01-simple-voice-assistant/), [Pipecat Voice Bot](integrations/pipecat/01-simple-voice-bot/), [Pipecat Voice Bot (Web)](integrations/pipecat/02-simple-voice-bot-web/), [Medical Transcription](use-cases/01-medical-transcription-realtime/) |
| **Advanced** | [LiveKit Telephony](integrations/livekit/02-telephony-twilio/), [Twilio Outbound Dialer](integrations/twilio/01-outbound-dialer/), [AI Receptionist](use-cases/04-voice-agent-calendar/) |



---


<h2 id="example-structure">📁 Example Structure</h2>

Every example follows a consistent structure:

```
example-name/
├── python/
│   ├── main.py             # Primary Python implementation
│   ├── requirements.txt    # Python dependencies
│   └── .gitignore          # Ignore venv/, __pycache__/, .env
├── assets/                 # Sample files, images, etc.
│   ├── sample.wav          # Sample audio (if needed)
│   └── agent.md            # Agent prompt (for voice agents)
├── .env.example            # Environment variables template
└── README.md               # Main documentation (REQUIRED)
```

> [!NOTE]
> Each example includes:
>
> 1. **What You'll Learn** - Key concepts covered
> 2. **Prerequisites** - Required setup
> 3. **Quick Start** - Step-by-step instructions
> 4. **How It Works** - Step-by-step explanation
> 5. **Key Features** - Demonstrated capabilities
> 6. **Expected Output** - Sample results
> 7. **Next Steps** - Related examples
> 8. **Troubleshooting** - Common issues
> 9. **Resources** - Relevant documentation

---

<h2 id="contributing">🤝 Contributing</h2>

We welcome contributions! There are many ways to help:

### Ways to Contribute

1. **Add New Examples** - Share your implementations
2. **Improve Existing Examples** - Fix bugs, add features
3. **Add Language Support** - Port examples to other languages
4. **Fix Documentation** - Improve README files
5. **Report Issues** - Help us improve quality

### Adding a New Example

1. **Choose category** (basics/integrations/use-cases)
2. **Follow structure** (see [EXAMPLE_TEMPLATE.md](docs/EXAMPLE_TEMPLATE.md))
3. **Add metadata** to [docs/index.yaml](docs/index.yaml)
4. **Write README** using the template
5. **Test thoroughly** 
6. **Submit PR** with clear description

See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for detailed guidelines.

### Quality Standards

> [!NOTE]
> All examples must meet these standards:
> 
> - Clean, readable, well-commented Python code
> - Follows SDK best practices
> - Includes proper error handling
> - No hardcoded secrets
> - Complete documentation
> - Tested end-to-end
> - Metadata in index.yaml

---

<h2 id="support--resources"> 🆘 Support & Resources</h2>

### Getting Help


- **GitHub Issues**: [Report bugs or request examples](https://github.com/speechmatics/speechmatics-academy/issues)
- **GitHub Community Discussions**: [Ask questions, share projects](https://github.com/speechmatics/community/discussions/categories/academy)
- **Email Support**: devrel@speechmatics.com

### Resources

- **SDK Repository**: [speechmatics-python-sdk](https://github.com/speechmatics/speechmatics-python-sdk)
- **API Documentation**: [docs.speechmatics.com](https://docs.speechmatics.com)
- **Developer Portal**: [portal.speechmatics.com](https://portal.speechmatics.com)
- **Blog**: [speechmatics.com/blog](https://www.speechmatics.com/blog)

### Documentation

- **[Example Template](docs/EXAMPLE_TEMPLATE.md)** - Template for new examples
- **[Contributing Guide](docs/CONTRIBUTING.md)** - How to contribute

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🔗 Links

- **SDK**: [github.com/speechmatics/speechmatics-python-sdk](https://github.com/speechmatics/speechmatics-python-sdk)
- **Docs**: [docs.speechmatics.com](https://docs.speechmatics.com)
- **Portal**: [portal.speechmatics.com](https://portal.speechmatics.com)

---

<div align="center">

**Built with ❤️ by the Speechmatics Community**

[Twitter](https://twitter.com/speechmatics) • [LinkedIn](https://linkedin.com/company/speechmatics) • [YouTube](https://youtube.com/@speechmatics)

</div>
