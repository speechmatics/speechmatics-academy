# Speechmatics Academy

**Production-ready examples, integrations, and templates for the Speechmatics Python SDK.**

Comprehensive collection of working examples demonstrating real-world applications, third-party integrations, and production deployment patterns.

**50+ Examples • Python • Copy-Paste Ready**

[Browse Examples](#example-categories) • [Quick Start](#quick-start) • [CLI Tool](#cli-tool) • [Contributing](#contributing)

---

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Example Categories](#example-categories)
- [Finding Examples](#finding-examples)

---

## ⚡ Quick Start

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
cd basics/01-simple-transcription/python

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
degit speechmatics/speechmatics-academy/basics/01-simple-transcription my-project
cd my-project
```
---

## 📚 Example Categories

### 🟢 Basics

Fundamental examples for getting started with the Speechmatics SDK.

| Example | Description | Difficulty | Languages | Time |
|---------|-------------|------------|-----------|------|
| [Simple Transcription](basics/01-simple-transcription/) | Upload audio and get a transcript | Beginner | Python | x min |
| [Real-time Streaming](basics/02-realtime-streaming/) | Stream audio for live transcription | Beginner | Python | x min |
| [Speaker Diarization](basics/03-speaker-diarization/) | Identify different speakers | Intermediate | Python | x min |
| [Custom Vocabulary](basics/04-custom-vocabulary/) | Add domain-specific terms | Beginner | Python | x min |
| [Audio Intelligence](basics/05-audio-intelligence/) | Sentiment, topics, summaries | Intermediate | Python | x min |
| [Translation](basics/06-translation/) | Transcribe and translate | Intermediate | Python | x min |

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
| **Discord** | [Voice Channel Bot](integrations/discord/voice-channel-bot/) | Discord bot, multi-speaker | Python | x min |
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

## 🔍 Finding Examples

### By Feature

| Feature | Examples |
|---------|----------|
| **Batch Transcription** | Simple Transcription, Podcast Processing, Court Reporting |
| **Real-time Streaming** | Real-time Streaming, LiveKit Integration, Discord Bot |
| **Speaker Diarization** | Speaker Diarization, Call Center Analytics, Meeting Transcription |
| **Custom Vocabulary** | Custom Vocabulary, Medical Dictation, Court Reporting |
| **Sentiment Analysis** | Audio Intelligence, Call Center Analytics, Voicemail Analysis |
| **Translation** | Translation, Education Transcription |
| **Text-to-Speech** | Voice Assistant, Pipecat Voice Bot |

### By Language

**Python Examples:** All examples include Python implementations

### By Difficulty

**Beginner (5-15 min):**
- Simple Transcription
- Real-time Streaming
- Custom Vocabulary
- FastAPI Integration
- Flask Integration

**Intermediate (15-45 min):**
- Speaker Diarization
- Audio Intelligence
- Translation
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
