# Speechmatics Academy

**Production-ready examples, integrations, and templates for the Speechmatics Python SDK.**

Comprehensive collection of working examples demonstrating real-world applications, third-party integrations, and production deployment patterns.

**4 Examples • Python • Copy-Paste Ready**

[Browse Examples](#example-categories) • [Quick Start](#quick-start) • [Contributing](#contributing)

---

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Example Categories](#example-categories)
- [Finding Examples](#finding-examples)


---

<h2 id="quick-start">⚡ Quick Start</h2>

### Prerequisites

This repository contains examples for the Speechmatics Python SDK. Install the SDK first:

```bash
# Install the package you need
pip install speechmatics-batch     # For batch transcription
pip install speechmatics-rt        # For real-time streaming
pip install speechmatics-voice     # For voice agents
pip install speechmatics-tts       # For text 
```

📚 [SDK Documentation](https://github.com/speechmatics/speechmatics-python-sdk) | [API Reference](https://docs.speechmatics.com)

### Option 1: Clone and Run

```bash
# Clone the repository
git clone https://github.com/speechmatics/speechmatics-academy.git
cd speechmatics-academy

# Navigate to an example
cd basics/01-hello-world/python

# Install dependencies
pip install -r requirements.txt

# Set up environment variables
cp ../.env.example .env
# Edit .env and add your SPEECHMATICS_API_KEY

# Run the example
python main.py
```

### Option 2: CLI Tool (Fastest)

### Option 3: Direct Copy

Use [degit](https://github.com/Rich-Harris/degit) to copy individual examples:

```bash
# Install degit
npm install -g degit

# Copy an example
degit speechmatics/speechmatics-academy/basics/01-hello-world my-project
cd my-project
```
---

<h2 id="example-categories">📚 Example Categories</h2>

### 🟢 Basics

Fundamental examples for getting started with the Speechmatics SDK.

| Example | Description | Difficulty | Languages | Time |
|---------|-------------|------------|-----------|------|
| [Hello World](basics/01-hello-world/) | The absolute simplest transcription example | Beginner | Python | 5 min |
| [Batch vs Real-time](basics/02-batch-vs-realtime/) | Learn the difference between API modes | Beginner | Python | 10 min |
| [Configuration Guide](basics/03-configuration-guide/) | All configuration options in one place | Beginner | Python | 15 min |
| [Audio Intelligence](basics/04-audio-intelligence/) | Extract insights with sentiment, topics, and summaries | Intermediate | Python | 15 min |

[Browse all basics examples →](basics/)

---

### 🔌 Integrations

Third-party framework and service integrations.

| Integration | Example | Features | Languages | Time |
|-------------|---------|----------|-----------|------|
| **LiveKit** | [Voice Assistant](integrations/livekit/voice-assistant/) | Real-time, diarization, WebRTC | Python | x min |
| **Pipecat AI** | [Simple Voice Bot](integrations/pipecat/simple-voice-bot/) | Conversational AI, interruptions | Python | x min |
| **Pipecat AI** | [Multimodal Agent](integrations/pipecat/multimodal-agent/) | Voice + vision, context switching | Python | x min |
| **Twilio** | [Phone Transcription](integrations/twilio/phone-transcription/) | Phone calls, real-time streaming | Python | x min |
| **Twilio** | [Voicemail Analysis](integrations/twilio/voicemail-analysis/) | Batch processing, sentiment | Python | x min |
| **FastAPI** | [Transcription API](integrations/web-frameworks/fastapi/) | REST API, async endpoints | Python | x min |
| **Flask** | [Transcription Service](integrations/web-frameworks/flask/) | Web service, file uploads | Python | x min |

[Browse all integrations →](integrations/)

---

### 🎯 Use Cases

Production-ready applications for specific industries.

| Use Case | Description | Features | Languages | Time |
|----------|-------------|----------|-----------|------|
| [Call Center Analytics](use-cases/call-center-analytics/) | Analyze customer calls with sentiment, topics, summaries | Diarization, sentiment, topics, summarization | Python | x min |
| [Meeting Transcription](use-cases/meeting-transcription/) | Auto-transcribe meetings with action items | Diarization, chapters, summaries | Python | x min |
| [Podcast Processing](use-cases/podcast-processing/) | Generate transcripts, timestamps, searchable content | Batch processing, SRT captions | Python | x min |
| [Court Reporting](use-cases/court-reporting/) | Legal transcription with high accuracy | Custom vocabulary, formatting | Python | x min |
| [Medical Dictation](use-cases/medical-dictation/) | HIPAA-compliant medical transcription | Medical vocabulary, on-premise | Python | x min |
| [Education Transcription](use-cases/education-transcription/) | Lecture transcripts with accessibility | Diarization, SRT, entities | Python | x min |

[Browse all use cases →](use-cases/)

---

<h2 id="finding-examples">🔍 Finding Examples</h2>

### By Feature

| Feature | Examples |
|---------|----------|
| **Batch Transcription** | Hello World, Configuration Guide, Audio Intelligence, Podcast Processing, Court Reporting |
| **Real-time Streaming** | Batch vs Real-time, LiveKit Integration, Discord Bot |
| **Speaker Diarization** | Configuration Guide, Call Center Analytics, Meeting Transcription |
| **Custom Vocabulary** | Configuration Guide, Medical Dictation, Court Reporting |
| **Sentiment Analysis** | Audio Intelligence, Call Center Analytics, Voicemail Analysis |
| **Topic Detection** | Audio Intelligence, Call Center Analytics |
| **Summarization** | Audio Intelligence, Call Center Analytics, Meeting Transcription |
| **Translation** | Translation, Education Transcription |
| **Text-to-Speech** | Voice Assistant, Pipecat Voice Bot |

### By Language

**Python Examples:** All examples include Python implementations

### By Difficulty

**Beginner (5-15 min):**
- Hello World (5 min)
- Batch vs Real-time (10 min)
- Configuration Guide (15 min)
- Custom Vocabulary
- FastAPI Integration
- Flask Integration

**Intermediate (15-45 min):**
- Audio Intelligence
- Translation
- Speaker Diarization
- Pipecat Voice Bot
- Twilio Integration
- Discord Bot
- Most use cases

**Advanced (45+ min):**
- Multimodal Agent
- Production deployments
- Complex integrations

### By Integration

| Integration | Examples | Documentation |
|-------------|----------|---------------|
| **LiveKit** | Voice Assistant | [livekit.io](https://docs.livekit.io/agents/models/stt/plugins/speechmatics/) |
| **Pipecat AI** | Voice Bot, Multimodal Agent | [pipecat-ai](https://docs.pipecat.ai/server/services/stt/speechmatics#speechmatics) |


---


## 📁 Example Structure

Every example follows a consistent structure:

```
example-name/
├── python/
│   ├── main.py             # Primary implementation
│   ├── requirements.txt    # Dependencies
│   ├── config.py           # Configuration (optional)
│   └── README.md           # Python-specific notes
├── .env.example            # Environment template
├── assets/                 # Screenshots, samples
│   ├── demo.mp4
│   └── sample.wav
└── README.md               # Main documentation
```

Each example includes:

1. **What You'll Learn** - Key concepts covered
2. **Prerequisites** - Required setup
3. **Quick Start** - Step-by-step instructions
4. **How It Works** - Step-by-step explanation
5. **Key Features** - Demonstrated capabilities
6. **Expected Output** - Sample results
7. **Next Steps** - Related examples
8. **Troubleshooting** - Common issues
9. **Resources** - Relevant documentation

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

**Helpful Guides:**
- [Creating Examples](docs/guides/creating-examples.md) - Step-by-step guide
- [Testing Examples](docs/guides/testing-examples.md) - Testing best practices
- [Example Checklist](docs/EXAMPLE_CHECKLIST.md) - Pre-submission checklist

See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for detailed guidelines.

### Quality Standards

All examples must meet these standards:

- ✅ Clean, readable, well-commented Python code
- ✅ Follows SDK best practices
- ✅ Includes proper error handling
- ✅ No hardcoded secrets
- ✅ Complete documentation
- ✅ Tested end-to-end
- ✅ Metadata in index.yaml

---

## 🆘 Support & Resources

### Getting Help

- **Discord**: [Join our community](https://discord.gg/speechmatics) - Fast responses from developers
- **GitHub Issues**: [Report bugs or request examples](https://github.com/speechmatics/speechmatics-academy/issues)
- **GitHub Discussions**: [Ask questions, share projects](https://github.com/speechmatics/speechmatics-academy/discussions)
- **Email Support**: academy@speechmatics.com

### Resources

- **SDK Repository**: [speechmatics-python-sdk](https://github.com/speechmatics/speechmatics-python-sdk)
- **API Documentation**: [docs.speechmatics.com](https://docs.speechmatics.com)
- **Developer Portal**: [portal.speechmatics.com](https://portal.speechmatics.com)
- **Blog**: [speechmatics.com/blog](https://www.speechmatics.com/blog)

### Documentation

- **[Example Template](docs/EXAMPLE_TEMPLATE.md)** - Template for new examples
- **[Example Checklist](docs/EXAMPLE_CHECKLIST.md)** - Quality standards
- **[Contributing Guide](docs/CONTRIBUTING.md)** - How to contribute
- **[Creating Examples](docs/guides/creating-examples.md)** - Step-by-step guide
- **[Testing Examples](docs/guides/testing-examples.md)** - Testing guide
- **[Multi-Language Support](docs/guides/multi-language-support.md)** - Language guide

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🔗 Links

- **Academy**: [github.com/speechmatics/speechmatics-academy](https://github.com/speechmatics/speechmatics-academy)
- **SDK**: [github.com/speechmatics/speechmatics-python-sdk](https://github.com/speechmatics/speechmatics-python-sdk)
- **Docs**: [docs.speechmatics.com](https://docs.speechmatics.com)
- **Portal**: [portal.speechmatics.com](https://portal.speechmatics.com)
- **Community**: [discord.gg/speechmatics](https://discord.gg/speechmatics)

---

<div align="center">

**Built with ❤️ by the Speechmatics Community**

[Twitter](https://twitter.com/speechmatics) • [LinkedIn](https://linkedin.com/company/speechmatics) • [YouTube](https://youtube.com/@speechmatics)

</div>