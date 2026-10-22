<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="logos/speechmatics-academy-white-2400x600.png">
  <source media="(prefers-color-scheme: light)" srcset="logos/speechmatics-academy-black-2400x600.png">
  <img alt="Speechmatics Academy" src="logos/speechmatics-academy-black-2400x600.png" width="70%">
</picture>

<br/>
<br/>

**Code examples, integrations, and templates for Speechmatics APIs and SDKs.**

Explore code examples for transcription, voice-agent applications, and third-party integrations. Each example explains its setup, dependencies, and limitations.

**Examples • Integrations • Use Cases • Developer Guides**

[Browse Examples](#example-categories) • [Quick Start](#quick-start) • [Contributing](#contributing) • [portal](https://portal.speechmatics.com/)  • [Documentation](https://docs.speechmatics.com/) • [Discord Community](https://discord.gg/speechmatics)

</div>

---

## What is Speechmatics?

[Speechmatics](https://www.speechmatics.com/) provides Speech to Text (STT) and Text to Speech (TTS). Use the Batch API for pre-recorded audio, the Realtime API for streaming audio, and agent STT for transcript segments and turn events. Your application or framework combines these with a large language model (LLM), tools, and conversation logic to build a voice agent.

**Flexible Deployment** - SaaS on Cloud and on-prem options. Availability depends on the API and model; check the [deployment documentation](https://docs.speechmatics.com/deployments). Agent STT is available on SaaS on Cloud only.

**Advanced Features** - Model-specific capabilities include a custom dictionary, speaker diarization, speaker identification, smart formatting, and speech intelligence. Check the [model comparison](https://docs.speechmatics.com/speech-to-text/models) before combining features. Speaker focus in an integration may be implemented by the application or framework.

---

## 📋 Table of Contents

- [What is Speechmatics?](#what-is-speechmatics)
- [Quick Start](#quick-start)
- [Example Categories](#example-categories)
- [Community Projects](#community-projects)
- [Migration Guides](#migration-guides)
- [Finding Examples](#finding-examples)
- [Example Structure](#example-structure)
- [Contributing](#contributing)
- [Support & Resources](#support--resources)
- [License](#license)
- [Links](#links)

---

<h2 id="quick-start">⚡ Quick Start</h2>

### Prerequisites

**1. Get your API key** from the [portal](https://portal.speechmatics.com/). Use Python 3.12 to match the repository's Python CI environment, and check the selected example for additional requirements.

**2. Install the SDK** for your use case in a virtual environment. When running an Academy example, install its supplied requirements as shown below:

```bash
# Choose the package for your use case:

# Batch transcription
pip install speechmatics-batch

# Realtime streaming
pip install speechmatics-rt

# Agent STT: transcript segments plus speech and turn events
pip install speechmatics-agent-stt

# Text to Speech
pip install speechmatics-tts

# Deprecated Voice SDK: maintain existing client-side segmentation integrations
pip install speechmatics-voice
```
<details>

<summary><strong>📦 Package Details</strong> • Click to see what's included in each package</summary>

<br/>

**speechmatics-batch** - Asynchronous transcription with the Batch API
- Upload audio files for processing
- Retrieve transcripts with word timings and supported speaker and entity metadata
- Request speech intelligence features supported by the selected model

**speechmatics-rt** - WebSocket streaming with the Realtime API
- Stream audio for live transcription
- Configure latency for models that support latency controls
- Partial and final transcripts

**speechmatics-agent-stt** - Agent STT with Linden 1, built on `speechmatics-rt` and using the `/v2/agent` endpoint
- Segment-level transcripts instead of word groups, plus speech and turn events
- Use the service's voice activity detection (VAD) to close turns by default
- Or set `TurnDetectionMode.EXTERNAL` to close each turn yourself, when Pipecat, LiveKit or your own VAD already owns that decision
- Pick this for the transcription layer alone, with your own code driving the conversation

**speechmatics-tts** - Text to Speech
- Convert text to natural-sounding speech
- Multiple voices
- Read generated audio incrementally or save the complete response

**speechmatics-voice** - The [deprecated Voice SDK](https://docs.speechmatics.com/integrations-and-sdks/voice-sdk), retained for existing applications
- Client-side turn detection selected through presets
- Speaker diarization and client-side segmentation
- Optional machine-learning turn detection: `pip install "speechmatics-voice[smart]"`
- Start new voice-agent transcription integrations with [agent STT](basics/13-agent-stt/); your application supplies the LLM, TTS, tools, and conversation logic

</details>

<br/>

[SDK Documentation](https://github.com/speechmatics/speechmatics-python-sdk) | [API Reference](https://docs.speechmatics.com/api-ref)

### Option 1: Clone and Run

The commands below use PowerShell. macOS/Linux alternatives are shown in comments.

```powershell
# Clone the repository
git clone https://github.com/speechmatics/speechmatics-academy.git
cd speechmatics-academy

# Navigate to an example
cd basics/01-hello-world/python

# Create a virtual environment (macOS/Linux: python3 -m venv .venv)
python -m venv .venv

# Activate the virtual environment (PowerShell)
.\.venv\Scripts\Activate.ps1
# macOS/Linux: source .venv/bin/activate

# Install dependencies
python -m pip install -r requirements.txt

# Copy the environment template (PowerShell)
Copy-Item ..\.env.example .env
# macOS/Linux: cp ../.env.example .env
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

You are now in the copied example directory. Follow its [Quick Start](basics/01-hello-world/README.md#quick-start), beginning with `cd python` and the virtual environment setup, then install dependencies, configure `.env`, and run the example.

---

<h2 id="example-categories">📚 Example Categories</h2>

Start with the fundamentals below, or choose an integration or focus to explore related examples and demos. Browse the **[complete catalog](docs/CATALOG.md)** to find examples by package, feature, language, or difficulty.

### Fundamentals

Fundamental examples for getting started with the Speechmatics SDK.

**Suggested path:** [Hello World](basics/01-hello-world/README.md) → [Batch vs Realtime](basics/02-batch-vs-realtime/README.md) → [Configuration Guide](basics/03-configuration-guide/README.md), then choose a feature below. The table groups introductory examples first; folder numbers are stable identifiers rather than a required lesson sequence.

<!-- BEGIN GENERATED: basics -->
| Example | Description | Packages | Difficulty |
| --- | --- | --- | --- |
| [Hello World - Your First Transcription](<basics/01-hello-world/README.md>) | Transcribe a sample audio file with the Batch SDK. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | beginner |
| [Batch vs Realtime - Understanding API Modes](<basics/02-batch-vs-realtime/README.md>) | Compare file transcription with Batch and microphone streaming with Realtime. | [Batch](<https://pypi.org/project/speechmatics-batch/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | beginner |
| [Configuration Guide - Common Configuration Options](<basics/03-configuration-guide/README.md>) | Configure speaker labels, a custom dictionary, and formatting for Batch transcription. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | beginner |
| [Text to Speech](<basics/06-text-to-speech/README.md>) | Convert text into speech with the TTS SDK. | [TTS](<https://pypi.org/project/speechmatics-tts/>) | beginner |
| [Channel Diarization](<basics/10-channel-diarization/README.md>) | Transcribe separate audio channels and label each channel. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | beginner |
| [Melia 1 Multilingual Transcription](<basics/12-melia-multilingual/README.md>) | Transcribe audio that switches between languages with Melia 1. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | beginner |
| [Speech intelligence - Sentiment, Topics and Summaries](<basics/04-audio-intelligence/README.md>) | Extract sentiment, topics, and summaries from a recording. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | intermediate |
| [Multilingual &amp; Translation](<basics/05-multilingual-translation/README.md>) | Stream English microphone audio and display Spanish and Russian translations. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | intermediate |
| [Basic Turn Detection](<basics/07-turn-detection/README.md>) | Detect the end of speech using silence-based turn detection. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | intermediate |
| [Intelligent Turn Detection](<basics/08-voice-agent-turn-detection/README.md>) **Legacy** | Compare turn-detection presets in the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | intermediate |
| [Speaker ID &amp; Speaker Focus](<basics/09-voice-agent-speaker-id/README.md>) **Legacy** | Save speaker identifiers and apply speaker focus with the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | intermediate |
| [Preview WebSocket API Explorer](<basics/11-voice-api-explorer/README.md>) **Preview** | Explore raw WebSocket clients for the Voice API preview. | Direct API / configuration | intermediate |
| [Agent STT Linden 1 - Segments, Turns and Speakers](<basics/13-agent-stt/README.md>) | Handle transcript segments, turns, and speakers with Agent STT Linden 1. | [Agent STT](<https://pypi.org/project/speechmatics-agent-stt/>) | intermediate |
<!-- END GENERATED: basics -->

[Browse all basics examples](basics/)

---

### Integrations

Choose an integration to explore its examples and setup guides. Groups with several examples open a hub; a single example opens its own guide.

<!-- BEGIN GENERATED: integrations -->
| Integration | Examples | What you'll build | Languages |
| --- | --- | --- | --- |
| <picture><source media="(prefers-color-scheme: dark)" srcset="integrations/agora/logo/agora-logo-rgb-blue.svg"><img src="integrations/agora/logo/agora-logo-rgb-blue.svg" alt="Agora" height="22"></picture> | [1&nbsp;example](<integrations/agora/01-conversational-ai-agent/README.md>) | Agora RTC/RTM with Speechmatics Realtime transcription and a managed LLM and speech synthesis pipeline. | Python, TypeScript |
| <picture><source media="(prefers-color-scheme: dark)" srcset="integrations/livekit/logo/LK_wordmark_darkbg.png"><img src="integrations/livekit/logo/LK_wordmark_lightbg.png" alt="LiveKit" height="19"></picture> | [6&nbsp;examples](<integrations/livekit/README.md>) | Voice assistants with Agent STT, speaker controls, browser tools, and SIP telephony. | Python, JavaScript |
| <picture><source media="(prefers-color-scheme: dark)" srcset="integrations/pipecat/logo/pipecat.png"><img src="integrations/pipecat/logo/pipecat.png" alt="Pipecat AI" height="28"></picture> | [2&nbsp;examples](<integrations/pipecat/README.md>) | Local microphone and browser WebRTC voice agents using the Speechmatics adapter. | Python |
| <picture><source media="(prefers-color-scheme: dark)" srcset="integrations/twilio/logo/twillio.png"><img src="integrations/twilio/logo/twillio.png" alt="Twilio" height="28"></picture> | [4&nbsp;examples](<integrations/twilio/README.md>) | Phone agents through LiveKit SIP or direct Media Streams; the direct example uses the legacy Voice SDK. | Python |
| <picture><source media="(prefers-color-scheme: dark)" srcset="integrations/vapi/logo/vapi-light.png"><img src="integrations/vapi/logo/vapi-dark.png" alt="Vapi" height="50"></picture> | [1&nbsp;example](<integrations/vapi/01-voice-assistant/README.md>) | Managed voice assistants with Speechmatics streaming transcription and a custom dictionary. | Python |
| <picture><source media="(prefers-color-scheme: dark)" srcset="integrations/tambourine/logo/icon.png"><img src="integrations/tambourine/logo/icon.png" alt="Tambourine Voice" height="50"></picture> | [1&nbsp;example](<integrations/tambourine/01-healthcare-dictation/README.md>) | Desktop healthcare dictation with Speechmatics STT and configurable LLM formatting. | Configuration |
<!-- END GENERATED: integrations -->

[Browse all integrations](docs/CATALOG.md#by-integration)

---

### Use Cases

Explore examples by industry or workflow. Each collection brings together related examples from across the Academy; an example can appear in more than one collection.

<!-- BEGIN GENERATED: use-cases -->
| Focus | Examples | What you'll build | Languages |
| --- | --- | --- | --- |
| Healthcare | [5&nbsp;examples](<collections/healthcare/README.md>) | Medical transcription, clinical dictation, and consultation interfaces. | Python, JavaScript, Configuration |
| Telephony | [5&nbsp;examples](<collections/telephony/README.md>) | Phone assistants, SIP and Media Streams, and recorded-call analysis. | Python |
| Multilingual | [6&nbsp;examples](<collections/multilingual/README.md>) | Translation, bilingual transcription, and multilingual code-switching. | Python, JavaScript, Dart |
| Voice agents | [16&nbsp;examples](<collections/voice-agents/README.md>) | Speech interfaces, turn handling, and complete conversational pipelines. | Python, TypeScript, JavaScript |
| Captions and insights | [5&nbsp;examples](<collections/captions-insights/README.md>) | Captions, live transcript displays, sentiment, topics, and summaries. | Python, JavaScript, Dart |
| Mobile | [1&nbsp;example](<use-cases/09-flutter-mobile-transcription/README.md>) | Mobile audio capture and transcription applications. | Dart |
<!-- END GENERATED: use-cases -->

[Browse all use cases](docs/CATALOG.md#by-collection)

---

<h2 id="community-projects">🌍 Community Projects</h2>

Projects built by the Speechmatics community. Community projects can use **any language** and follow the [community submission requirements](community/README.md), including the repository's current CI checks.

> [!NOTE]
> No community projects yet - yours could be the first! See [How to Submit](community/README.md#how-to-submit).

<!-- As community projects are added, list them here:
| Project | Category | Description | Language | Author | Status |
|---------|----------|-------------|----------|--------|--------|
| [Example Project](community/use-cases/example/) | Use Case | Example description | Python | [@user](https://github.com/user) | ![Verified](https://img.shields.io/badge/Speechmatics_Academy-Verified-green) |
| [Example Tool](community/tools/example/) | Tool | Example description | TypeScript | [@user](https://github.com/user) | ![Community](https://img.shields.io/badge/Speechmatics_Academy-Community_Project-blue) |
-->

Community projects have two quality tiers:

![Verified](https://img.shields.io/badge/Speechmatics_Academy-Verified-green) Maintainer-audited, fully template-compliant, tested end-to-end

![Community](https://img.shields.io/badge/Speechmatics_Academy-Community_Project-blue) Basic structure, working code, light review

[Browse all community projects](community/) | [Submit a project](community/README.md#how-to-submit) | [Community Template](community/COMMUNITY_TEMPLATE.md)

---

<h2 id="migration-guides">🔄 Migration Guides</h2>

Switching from another Speech to Text provider? Use the migration guides to compare concepts, configuration, and code patterns. Check current SDK versions before adapting snippets.

| From | Guide | Features Covered | Status |
|------|-------|------------------|--------|
| **Deepgram** | [Migration Guide](guides/migration-guides/deepgram/) | Batch, Streaming, Diarization, custom dictionary | **Available** |
| **AssemblyAI** | Migration Guide | Transcription, Audio Intelligence, Real-time | Not yet included |
| **Google Cloud Speech** | Migration Guide  | Batch, Streaming, Multi-language | Not yet included |
| **AWS Transcribe** | Migration Guide | Batch Jobs, Streaming, custom dictionary | Not yet included |
| **Azure Speech** | Migration Guide | REST API, WebSocket, Pronunciation | Not yet included |

> [!NOTE]
> The migration guide provides:
> - **Feature Mapping** - Compare related features and their differences
> - **Code Comparison** - Side-by-side before/after examples
> - **Migration Checklist** - Step-by-step migration process
> - **Evaluation** - Compare services on representative audio and current capabilities
> - **Code Examples** - Supporting scripts with the setup and compatibility notes in the guide

[Browse all migration guides](guides/migration-guides/)

---

<h2 id="finding-examples">🔍 Finding Examples</h2>

<a id="by-package"></a>
<a id="by-feature"></a>
<a id="by-integration"></a>
<a id="by-language"></a>
<a id="by-difficulty"></a>

Browse the catalog by **[package](docs/CATALOG.md#by-package)** · **[feature](docs/CATALOG.md#by-feature)** · **[integration](docs/CATALOG.md#by-integration)** · **[language](docs/CATALOG.md#by-language)** · **[collection](docs/CATALOG.md#by-collection)** · **[difficulty](docs/CATALOG.md#by-difficulty)**.

Follow each example's README for its dependencies, setup, and compatibility notes.

---
<h2 id="example-structure">📁 Example Structure</h2>

Small Python examples generally follow this structure. Web and mobile applications use framework-specific layouts described in their READMEs:

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
> The example template calls for:
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
2. **Submit Community Projects** - Share your own projects in any language ([learn more](community/README.md))
3. **Improve Existing Examples** - Fix bugs, add features
4. **Add Language Support** - Port examples to other languages
5. **Fix Documentation** - Improve README files
6. **Report Issues** - Help us improve quality

### Adding a New Example

1. **Choose category** (basics/integrations/use-cases)
2. **Follow structure** (see [EXAMPLE_TEMPLATE.md](docs/EXAMPLE_TEMPLATE.md))
3. **Add metadata** to [docs/index.yaml](docs/index.yaml) and [regenerate the discovery pages](docs/CATALOG_GUIDE.md)
4. **Write README** using the template
5. **Test thoroughly**
6. **Submit PR** with clear description

See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for detailed guidelines.

### Quality Standards

> [!NOTE]
> All examples must meet these standards:
>
> - Clean, readable code following the conventions of its implementation language
> - Follows SDK best practices
> - Includes error handling and resource cleanup
> - No hardcoded secrets
> - Complete documentation
> - Tested with the documented runtime; validation and untested live steps are stated
> - Metadata in index.yaml

---

<h2 id="support--resources">🆘 Support & Resources</h2>

### Getting Help

- **GitHub Issues**: [Report bugs or request examples](https://github.com/speechmatics/speechmatics-academy/issues)
- **GitHub Community Discussions**: [Ask questions, share projects](https://github.com/speechmatics/community/discussions/categories/academy)
- **Discord Community**: [Join our Discord](https://discord.gg/speechmatics)
- **Email Support**: devrel@speechmatics.com

### Resources

- **SDK Repository**: [speechmatics-python-sdk](https://github.com/speechmatics/speechmatics-python-sdk)
- **API Documentation**: [docs.speechmatics.com](https://docs.speechmatics.com) · [Release notes](https://speechmatics.featurebase.app/en/changelog)
- **Developer portal**: [portal.speechmatics.com](https://portal.speechmatics.com)
- **Blog**: [speechmatics.com/blog](https://www.speechmatics.com/blog)

### Documentation

- **[Example Template](docs/EXAMPLE_TEMPLATE.md)** - Template for new examples
- **[Contributing Guide](docs/CONTRIBUTING.md)** - How to contribute

---

<a id="license"></a>

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<a id="links"></a>

## 🔗 Links

[SDK](https://github.com/speechmatics/speechmatics-python-sdk) · [Documentation](https://docs.speechmatics.com) · [portal](https://portal.speechmatics.com)

---

<div align="center">

**Built with ❤️ by the Speechmatics Community**

[Twitter](https://twitter.com/speechmatics) • [LinkedIn](https://linkedin.com/company/speechmatics) • [YouTube](https://youtube.com/@speechmatics)

</div>
