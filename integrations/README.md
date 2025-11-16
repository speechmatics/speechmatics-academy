# Integrations Examples

**Third-party framework and service integrations**

This section demonstrates how to integrate Speechmatics with popular frameworks, services, and platforms. These examples show real-world integration patterns and are designed to take 15-45 minutes to complete.

## 🔌 Available Integrations

### Voice & Communication Platforms

| Integration | Example | Description | Languages | Time |
|-------------|---------|-------------|-----------|------|
| **LiveKit** | [Voice Assistant](livekit/voice-assistant/) | WebRTC voice assistant with real-time transcription | Python | 10 min |
| **Pipecat AI** | [Simple Voice Bot](pipecat/simple-voice-bot/) | Conversational AI | Python | 10 min |
| **Twilio** | [Phone Transcription](twilio/phone-transcription/) | Live phone call transcription | Python | 20 min |
| **Twilio** | [Voicemail Analysis](twilio/voicemail-analysis/) | Batch voicemail processing with sentiment | Python | 20 min |


### Web Frameworks

| Framework | Example | Description | Languages | Time |
|-----------|---------|-------------|-----------|------|
| **FastAPI** | [Transcription API](web-frameworks/fastapi/) | REST API with async endpoints | Python | 20 min |
| **Flask** | [Transcription Service](web-frameworks/flask/) | Simple web service with file uploads | Python | 15 min |
| **Next.js** | [Transcription App](web-frameworks/nextjs/) | Full-stack transcription application | TypeScript | 35 min |

## 🎯 By Use Case

**Real-time Voice Applications:**
- LiveKit Voice Assistant
- Pipecat Simple Voice Bot
- Twilio Phone Transcription


**API Services:**
- FastAPI Transcription API
- Flask Transcription Service
- Next.js Transcription App

**Telephony:**
- Twilio Phone Transcription
- Twilio Voicemail Analysis

## 🚀 Quick Start

Each integration follows a consistent structure:

```bash
cd integrations/[integration]/[example]/python  # or typescript
pip install -r requirements.txt                 # or npm install
cp ../.env.example .env
# Edit .env and add required API keys (SPEECHMATICS_API_KEY + integration-specific keys)
python main.py                                 
```

## 📖 Prerequisites

**General Requirements:**
- Speechmatics API key from [portal.speechmatics.com](https://portal.speechmatics.com/)
- Python 3.8
- SDK installed: `pip install speechmatics-rt speechmatics-batch`

**Integration-Specific:**
- **LiveKit**: LiveKit Cloud account or self-hosted server
- **Pipecat**: OpenAI API key (for LLM responses)
- **Twilio**: Twilio account with phone number
- **Web Frameworks**: No additional accounts required

## 🎓 What You'll Learn

By exploring these integrations, you'll understand:

- ✅ How to integrate Speechmatics with popular voice platforms
- ✅ Real-time bidirectional communication patterns
- ✅ Building conversational AI applications
- ✅ Creating REST APIs for transcription services
- ✅ Handling webhooks and callbacks
- ✅ Managing multi-user/multi-session scenarios
- ✅ Production deployment patterns

## 🏗️ Integration Categories

### [LiveKit](livekit/)
WebRTC-based real-time communication platform for voice and video applications.

### [Pipecat AI](pipecat/)
Framework for building voice and multimodal AI agents with interruption handling.

### [Twilio](twilio/)
Cloud communications platform for SMS, voice calls, and video.

### [Web Frameworks](web-frameworks/)
FastAPI, Flask, and Next.js examples for building transcription services.

## ⏭️ Next Steps

After mastering integrations:

- **[Use Cases](../use-cases/)** - Explore production-ready applications for specific industries
- **[Basics](../basics/)** - Review fundamental SDK features if needed
- **[Templates](../templates/)** - Use starter templates to build your own integrations

## 📚 Resources

- [Speechmatics Python SDK](https://github.com/speechmatics/speechmatics-python-sdk)
- [API Documentation](https://docs.speechmatics.com)
- [Integration-Specific Docs](https://docs.speechmatics.com/integrations)
- [Community Discord](https://discord.gg/speechmatics)

---

[⬅️ Back to Main](../README.md)
