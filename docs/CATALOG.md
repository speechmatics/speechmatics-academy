# Speechmatics Academy Catalog

[← Back to Academy](<../README.md>)

<!-- Generated from docs/index.yaml; run .github/scripts/generate_catalog.py. -->

33 examples. Metadata updated 2026-10-22.

Service availability: implementation lifecycle describes this example, not an access guarantee. Check the linked API documentation and your account access before running it. A local demo requires setup; a recording shows a captured session.

Browse: [Package](#by-package) · [Feature](#by-feature) · [Language](#by-language) · [Integration](#by-integration) · [Collection](#by-collection) · [Difficulty](#by-difficulty)

<a id="by-package"></a>
## By package

<a id="package-speechmatics-batch"></a>
### Speechmatics Batch SDK

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Hello World - Your First Transcription](<../basics/01-hello-world/README.md>) · [Details](#example-hello-world) | Transcribe a sample audio file with the Batch SDK. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Batch vs Realtime - Understanding API Modes](<../basics/02-batch-vs-realtime/README.md>) · [Details](#example-batch-vs-realtime) | Compare file transcription with Batch and microphone streaming with Realtime. | [Batch](<https://pypi.org/project/speechmatics-batch/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | beginner |
| [Configuration Guide - Common Configuration Options](<../basics/03-configuration-guide/README.md>) · [Details](#example-configuration-guide) | Configure speaker labels, a custom dictionary, and formatting for Batch transcription. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Melia 1 Multilingual Transcription](<../basics/12-melia-multilingual/README.md>) · [Details](#example-melia-multilingual) | Transcribe audio that switches between languages with Melia 1. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Speech intelligence - Sentiment, Topics and Summaries](<../basics/04-audio-intelligence/README.md>) · [Details](#example-audio-intelligence) | Extract sentiment, topics, and summaries from a recording. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | intermediate |
| [Video Captioning](<../use-cases/02-video-captioning/README.md>) · [Details](#example-video-captioning) | Generate SRT captions from video with the Batch API. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Call Center Analytics](<../use-cases/03-call-center-analytics/README.md>) · [Details](#example-call-center-analytics) | Analyze recorded calls with channel labels, sentiment, topics, and summaries. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Medical Microbatching](<../use-cases/07-medical-microbatching/README.md>) · [Details](#example-medical-microbatching) | Split microphone audio into Batch jobs with optional speaker tracking and Medical settings. | [Batch](<https://pypi.org/project/speechmatics-batch/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |

<a id="package-speechmatics-rt"></a>
### Speechmatics Realtime SDK

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Batch vs Realtime - Understanding API Modes](<../basics/02-batch-vs-realtime/README.md>) · [Details](#example-batch-vs-realtime) | Compare file transcription with Batch and microphone streaming with Realtime. | [Batch](<https://pypi.org/project/speechmatics-batch/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | beginner |
| [Channel Diarization](<../basics/10-channel-diarization/README.md>) · [Details](#example-channel-diarization) | Transcribe separate audio channels and label each channel. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | beginner |
| [Multilingual &amp; Translation](<../basics/05-multilingual-translation/README.md>) · [Details](#example-multilingual-translation) | Stream English microphone audio and display Spanish and Russian translations. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Basic Turn Detection](<../basics/07-turn-detection/README.md>) · [Details](#example-turn-detection) | Detect the end of speech using silence-based turn detection. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Intelligent Turn Detection](<../basics/08-voice-agent-turn-detection/README.md>) **Legacy** · [Details](#example-voice-agent-turn-detection) | Compare turn-detection presets in the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Speaker ID &amp; Speaker Focus](<../basics/09-voice-agent-speaker-id/README.md>) **Legacy** · [Details](#example-voice-agent-speaker-id) | Save speaker identifiers and apply speaker focus with the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Medical Transcription - Realtime Enhanced Medical](<../use-cases/01-medical-transcription-realtime/README.md>) · [Details](#example-medical-transcription-realtime) | Stream a medical recording with Enhanced Medical and a custom dictionary. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Medical Assistant](<../use-cases/06-medical-assistant/README.md>) **Preview** · [Details](#example-medical-assistant) | Transcribe Arabic and English consultations and draft structured fields and SOAP notes. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | advanced |
| [Medical Microbatching](<../use-cases/07-medical-microbatching/README.md>) · [Details](#example-medical-microbatching) | Split microphone audio into Batch jobs with optional speaker tracking and Medical settings. | [Batch](<https://pypi.org/project/speechmatics-batch/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Wall of Voices](<../use-cases/10-wall-of-voices/README.md>) **Preview** · [Details](#example-wall-of-voices) | Display live multilingual transcripts with per-word language labels and colors. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | intermediate |

<a id="package-speechmatics-agent-stt"></a>
### Speechmatics Agent STT SDK

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Agent STT Linden 1 - Segments, Turns and Speakers](<../basics/13-agent-stt/README.md>) · [Details](#example-agent-stt) | Handle transcript segments, turns, and speakers with Agent STT Linden 1. | [Agent STT](<https://pypi.org/project/speechmatics-agent-stt/>) | Python | intermediate |

<a id="package-speechmatics-tts"></a>
### Speechmatics Text to Speech SDK

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Text to Speech](<../basics/06-text-to-speech/README.md>) · [Details](#example-text-to-speech) | Convert text into speech with the TTS SDK. | [TTS](<https://pypi.org/project/speechmatics-tts/>) | Python | beginner |

<a id="package-speechmatics-voice"></a>
### Speechmatics Voice SDK (deprecated)

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Intelligent Turn Detection](<../basics/08-voice-agent-turn-detection/README.md>) **Legacy** · [Details](#example-voice-agent-turn-detection) | Compare turn-detection presets in the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Speaker ID &amp; Speaker Focus](<../basics/09-voice-agent-speaker-id/README.md>) **Legacy** · [Details](#example-voice-agent-speaker-id) | Save speaker identifiers and apply speaker focus with the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Twilio Outbound Dialer](<../integrations/twilio/01-outbound-dialer/README.md>) **Legacy** · [Details](#example-twilio-outbound-dialer) | Start outbound phone calls with Twilio Media Streams and the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>) | Python | advanced |

<a id="package-livekit-plugins-speechmatics"></a>
### LiveKit Speechmatics STT and TTS plugin

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [LiveKit Voice Assistant](<../integrations/livekit/01-simple-voice-assistant/README.md>) · [Details](#example-livekit-voice-assistant) | Build a LiveKit voice assistant with Agent STT, speaker labels, an LLM, and TTS. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [LiveKit Telephony with Twilio](<../integrations/livekit/02-telephony-twilio/README.md>) · [Details](#example-livekit-telephony-twilio) | Receive phone calls through Twilio SIP and respond with a LiveKit voice assistant. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [Speaker Focus Voice Agent](<../integrations/livekit/03-speaker-focus-voice-agent/README.md>) · [Details](#example-livekit-speaker-focus) | Filter completed Agent STT turns by speaker in a LiveKit app with a browser visualizer. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |
| [AI Receptionist](<../use-cases/04-voice-agent-calendar/README.md>) · [Details](#example-voice-agent-calendar) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Santa Voice Agent](<../use-cases/05-santa-voice-agent/README.md>) · [Details](#example-santa-voice-agent) | Build a Santa character voice assistant with LiveKit and optional phone calls. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Alphanumerics Voice Form Filler](<../use-cases/08-alphanumerics-form-filler/README.md>) · [Details](#example-alphanumerics-form-filler) | Fill a browser form with spoken names, email addresses, and numbers through LiveKit. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |

<a id="package-pipecat-ai"></a>
### Pipecat AI with Speechmatics adapter

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Pipecat Simple Voice Bot](<../integrations/pipecat/01-simple-voice-bot/README.md>) · [Details](#example-pipecat-voice-bot) | Run a Pipecat voice assistant through a local microphone and speakers. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |
| [Pipecat Simple Voice Bot (Web)](<../integrations/pipecat/02-simple-voice-bot-web/README.md>) · [Details](#example-pipecat-voice-bot-web) | Build a browser voice assistant with Pipecat WebRTC and local turn analysis. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |

<a id="package-agora-agents"></a>
### Agora Conversational AI Agents SDK

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Agora Conversational AI Voice Agent](<../integrations/agora/01-conversational-ai-agent/README.md>) · [Details](#example-agora-conversational-ai-agent) | Build a browser voice agent with Agora audio, transcripts, and a managed LLM/TTS pipeline. | [Agora Agents](<https://pypi.org/project/agora-agents/>) | Python, TypeScript | intermediate |

<a id="package-vapi-server-sdk"></a>
### Vapi Server SDK

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Vapi Voice Assistant](<../integrations/vapi/01-voice-assistant/README.md>) · [Details](#example-vapi-voice-assistant) | Configure a Vapi voice assistant with Speechmatics STT and a custom dictionary. | [Vapi SDK](<https://pypi.org/project/vapi-server-sdk/>) | Python | beginner |

<a id="package-direct-api-configuration"></a>
### Direct API / configuration

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Preview WebSocket API Explorer](<../basics/11-voice-api-explorer/README.md>) **Preview** · [Details](#example-voice-api-explorer) | Explore raw WebSocket clients for the Voice API preview. | Direct API / configuration | Python, JavaScript | intermediate |
| [Tambourine Healthcare Dictation](<../integrations/tambourine/01-healthcare-dictation/README.md>) · [Details](#example-tambourine-healthcare-dictation) | Configure desktop dictation and clinical formatting prompts in Tambourine. | Direct API / configuration | Configuration | beginner |
| [Flutter Mobile Transcription App](<../use-cases/09-flutter-mobile-transcription/README.md>) · [Details](#example-flutter-mobile-transcription) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart | intermediate |
| [Oak Consultation Studio](<../use-cases/11-oak-consultation-studio/README.md>) · [Details](#example-oak-consultation-studio) | Explore multilingual medical transcripts with Oak 1, audio playback, and speaker labels. | Direct API / configuration | Python, JavaScript | intermediate |

<a id="by-feature"></a>
## By feature

<a id="feature-batch-transcription"></a>
### Batch transcription

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Hello World - Your First Transcription](<../basics/01-hello-world/README.md>) · [Details](#example-hello-world) | Transcribe a sample audio file with the Batch SDK. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Batch vs Realtime - Understanding API Modes](<../basics/02-batch-vs-realtime/README.md>) · [Details](#example-batch-vs-realtime) | Compare file transcription with Batch and microphone streaming with Realtime. | [Batch](<https://pypi.org/project/speechmatics-batch/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | beginner |
| [Configuration Guide - Common Configuration Options](<../basics/03-configuration-guide/README.md>) · [Details](#example-configuration-guide) | Configure speaker labels, a custom dictionary, and formatting for Batch transcription. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Melia 1 Multilingual Transcription](<../basics/12-melia-multilingual/README.md>) · [Details](#example-melia-multilingual) | Transcribe audio that switches between languages with Melia 1. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Speech intelligence - Sentiment, Topics and Summaries](<../basics/04-audio-intelligence/README.md>) · [Details](#example-audio-intelligence) | Extract sentiment, topics, and summaries from a recording. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | intermediate |
| [Video Captioning](<../use-cases/02-video-captioning/README.md>) · [Details](#example-video-captioning) | Generate SRT captions from video with the Batch API. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Call Center Analytics](<../use-cases/03-call-center-analytics/README.md>) · [Details](#example-call-center-analytics) | Analyze recorded calls with channel labels, sentiment, topics, and summaries. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Medical Microbatching](<../use-cases/07-medical-microbatching/README.md>) · [Details](#example-medical-microbatching) | Split microphone audio into Batch jobs with optional speaker tracking and Medical settings. | [Batch](<https://pypi.org/project/speechmatics-batch/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Flutter Mobile Transcription App](<../use-cases/09-flutter-mobile-transcription/README.md>) · [Details](#example-flutter-mobile-transcription) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart | intermediate |
| [Oak Consultation Studio](<../use-cases/11-oak-consultation-studio/README.md>) · [Details](#example-oak-consultation-studio) | Explore multilingual medical transcripts with Oak 1, audio playback, and speaker labels. | Direct API / configuration | Python, JavaScript | intermediate |

<a id="feature-realtime-transcription"></a>
### Realtime transcription

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Batch vs Realtime - Understanding API Modes](<../basics/02-batch-vs-realtime/README.md>) · [Details](#example-batch-vs-realtime) | Compare file transcription with Batch and microphone streaming with Realtime. | [Batch](<https://pypi.org/project/speechmatics-batch/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | beginner |
| [Channel Diarization](<../basics/10-channel-diarization/README.md>) · [Details](#example-channel-diarization) | Transcribe separate audio channels and label each channel. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | beginner |
| [Multilingual &amp; Translation](<../basics/05-multilingual-translation/README.md>) · [Details](#example-multilingual-translation) | Stream English microphone audio and display Spanish and Russian translations. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Basic Turn Detection](<../basics/07-turn-detection/README.md>) · [Details](#example-turn-detection) | Detect the end of speech using silence-based turn detection. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Intelligent Turn Detection](<../basics/08-voice-agent-turn-detection/README.md>) **Legacy** · [Details](#example-voice-agent-turn-detection) | Compare turn-detection presets in the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Speaker ID &amp; Speaker Focus](<../basics/09-voice-agent-speaker-id/README.md>) **Legacy** · [Details](#example-voice-agent-speaker-id) | Save speaker identifiers and apply speaker focus with the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Preview WebSocket API Explorer](<../basics/11-voice-api-explorer/README.md>) **Preview** · [Details](#example-voice-api-explorer) | Explore raw WebSocket clients for the Voice API preview. | Direct API / configuration | Python, JavaScript | intermediate |
| [Agent STT Linden 1 - Segments, Turns and Speakers](<../basics/13-agent-stt/README.md>) · [Details](#example-agent-stt) | Handle transcript segments, turns, and speakers with Agent STT Linden 1. | [Agent STT](<https://pypi.org/project/speechmatics-agent-stt/>) | Python | intermediate |
| [Agora Conversational AI Voice Agent](<../integrations/agora/01-conversational-ai-agent/README.md>) · [Details](#example-agora-conversational-ai-agent) | Build a browser voice agent with Agora audio, transcripts, and a managed LLM/TTS pipeline. | [Agora Agents](<https://pypi.org/project/agora-agents/>) | Python, TypeScript | intermediate |
| [LiveKit Voice Assistant](<../integrations/livekit/01-simple-voice-assistant/README.md>) · [Details](#example-livekit-voice-assistant) | Build a LiveKit voice assistant with Agent STT, speaker labels, an LLM, and TTS. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [LiveKit Telephony with Twilio](<../integrations/livekit/02-telephony-twilio/README.md>) · [Details](#example-livekit-telephony-twilio) | Receive phone calls through Twilio SIP and respond with a LiveKit voice assistant. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [Speaker Focus Voice Agent](<../integrations/livekit/03-speaker-focus-voice-agent/README.md>) · [Details](#example-livekit-speaker-focus) | Filter completed Agent STT turns by speaker in a LiveKit app with a browser visualizer. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |
| [Pipecat Simple Voice Bot](<../integrations/pipecat/01-simple-voice-bot/README.md>) · [Details](#example-pipecat-voice-bot) | Run a Pipecat voice assistant through a local microphone and speakers. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |
| [Pipecat Simple Voice Bot (Web)](<../integrations/pipecat/02-simple-voice-bot-web/README.md>) · [Details](#example-pipecat-voice-bot-web) | Build a browser voice assistant with Pipecat WebRTC and local turn analysis. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |
| [Twilio Outbound Dialer](<../integrations/twilio/01-outbound-dialer/README.md>) **Legacy** · [Details](#example-twilio-outbound-dialer) | Start outbound phone calls with Twilio Media Streams and the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>) | Python | advanced |
| [Vapi Voice Assistant](<../integrations/vapi/01-voice-assistant/README.md>) · [Details](#example-vapi-voice-assistant) | Configure a Vapi voice assistant with Speechmatics STT and a custom dictionary. | [Vapi SDK](<https://pypi.org/project/vapi-server-sdk/>) | Python | beginner |
| [Tambourine Healthcare Dictation](<../integrations/tambourine/01-healthcare-dictation/README.md>) · [Details](#example-tambourine-healthcare-dictation) | Configure desktop dictation and clinical formatting prompts in Tambourine. | Direct API / configuration | Configuration | beginner |
| [Medical Transcription - Realtime Enhanced Medical](<../use-cases/01-medical-transcription-realtime/README.md>) · [Details](#example-medical-transcription-realtime) | Stream a medical recording with Enhanced Medical and a custom dictionary. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [AI Receptionist](<../use-cases/04-voice-agent-calendar/README.md>) · [Details](#example-voice-agent-calendar) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Santa Voice Agent](<../use-cases/05-santa-voice-agent/README.md>) · [Details](#example-santa-voice-agent) | Build a Santa character voice assistant with LiveKit and optional phone calls. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Medical Assistant](<../use-cases/06-medical-assistant/README.md>) **Preview** · [Details](#example-medical-assistant) | Transcribe Arabic and English consultations and draft structured fields and SOAP notes. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | advanced |
| [Alphanumerics Voice Form Filler](<../use-cases/08-alphanumerics-form-filler/README.md>) · [Details](#example-alphanumerics-form-filler) | Fill a browser form with spoken names, email addresses, and numbers through LiveKit. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |
| [Wall of Voices](<../use-cases/10-wall-of-voices/README.md>) **Preview** · [Details](#example-wall-of-voices) | Display live multilingual transcripts with per-word language labels and colors. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | intermediate |

<a id="feature-speaker-diarization"></a>
### Speaker diarization

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Configuration Guide - Common Configuration Options](<../basics/03-configuration-guide/README.md>) · [Details](#example-configuration-guide) | Configure speaker labels, a custom dictionary, and formatting for Batch transcription. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Speaker ID &amp; Speaker Focus](<../basics/09-voice-agent-speaker-id/README.md>) **Legacy** · [Details](#example-voice-agent-speaker-id) | Save speaker identifiers and apply speaker focus with the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Preview WebSocket API Explorer](<../basics/11-voice-api-explorer/README.md>) **Preview** · [Details](#example-voice-api-explorer) | Explore raw WebSocket clients for the Voice API preview. | Direct API / configuration | Python, JavaScript | intermediate |
| [Agent STT Linden 1 - Segments, Turns and Speakers](<../basics/13-agent-stt/README.md>) · [Details](#example-agent-stt) | Handle transcript segments, turns, and speakers with Agent STT Linden 1. | [Agent STT](<https://pypi.org/project/speechmatics-agent-stt/>) | Python | intermediate |
| [LiveKit Voice Assistant](<../integrations/livekit/01-simple-voice-assistant/README.md>) · [Details](#example-livekit-voice-assistant) | Build a LiveKit voice assistant with Agent STT, speaker labels, an LLM, and TTS. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [Speaker Focus Voice Agent](<../integrations/livekit/03-speaker-focus-voice-agent/README.md>) · [Details](#example-livekit-speaker-focus) | Filter completed Agent STT turns by speaker in a LiveKit app with a browser visualizer. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |
| [Pipecat Simple Voice Bot](<../integrations/pipecat/01-simple-voice-bot/README.md>) · [Details](#example-pipecat-voice-bot) | Run a Pipecat voice assistant through a local microphone and speakers. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |
| [Pipecat Simple Voice Bot (Web)](<../integrations/pipecat/02-simple-voice-bot-web/README.md>) · [Details](#example-pipecat-voice-bot-web) | Build a browser voice assistant with Pipecat WebRTC and local turn analysis. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |
| [Vapi Voice Assistant](<../integrations/vapi/01-voice-assistant/README.md>) · [Details](#example-vapi-voice-assistant) | Configure a Vapi voice assistant with Speechmatics STT and a custom dictionary. | [Vapi SDK](<https://pypi.org/project/vapi-server-sdk/>) | Python | beginner |
| [Medical Transcription - Realtime Enhanced Medical](<../use-cases/01-medical-transcription-realtime/README.md>) · [Details](#example-medical-transcription-realtime) | Stream a medical recording with Enhanced Medical and a custom dictionary. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [AI Receptionist](<../use-cases/04-voice-agent-calendar/README.md>) · [Details](#example-voice-agent-calendar) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Santa Voice Agent](<../use-cases/05-santa-voice-agent/README.md>) · [Details](#example-santa-voice-agent) | Build a Santa character voice assistant with LiveKit and optional phone calls. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Medical Assistant](<../use-cases/06-medical-assistant/README.md>) **Preview** · [Details](#example-medical-assistant) | Transcribe Arabic and English consultations and draft structured fields and SOAP notes. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | advanced |
| [Medical Microbatching](<../use-cases/07-medical-microbatching/README.md>) · [Details](#example-medical-microbatching) | Split microphone audio into Batch jobs with optional speaker tracking and Medical settings. | [Batch](<https://pypi.org/project/speechmatics-batch/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Flutter Mobile Transcription App](<../use-cases/09-flutter-mobile-transcription/README.md>) · [Details](#example-flutter-mobile-transcription) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart | intermediate |
| [Oak Consultation Studio](<../use-cases/11-oak-consultation-studio/README.md>) · [Details](#example-oak-consultation-studio) | Explore multilingual medical transcripts with Oak 1, audio playback, and speaker labels. | Direct API / configuration | Python, JavaScript | intermediate |

<a id="feature-speaker-identification"></a>
### Speaker identification

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Speaker ID &amp; Speaker Focus](<../basics/09-voice-agent-speaker-id/README.md>) **Legacy** · [Details](#example-voice-agent-speaker-id) | Save speaker identifiers and apply speaker focus with the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Preview WebSocket API Explorer](<../basics/11-voice-api-explorer/README.md>) **Preview** · [Details](#example-voice-api-explorer) | Explore raw WebSocket clients for the Voice API preview. | Direct API / configuration | Python, JavaScript | intermediate |
| [Agent STT Linden 1 - Segments, Turns and Speakers](<../basics/13-agent-stt/README.md>) · [Details](#example-agent-stt) | Handle transcript segments, turns, and speakers with Agent STT Linden 1. | [Agent STT](<https://pypi.org/project/speechmatics-agent-stt/>) | Python | intermediate |
| [LiveKit Voice Assistant](<../integrations/livekit/01-simple-voice-assistant/README.md>) · [Details](#example-livekit-voice-assistant) | Build a LiveKit voice assistant with Agent STT, speaker labels, an LLM, and TTS. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [Speaker Focus Voice Agent](<../integrations/livekit/03-speaker-focus-voice-agent/README.md>) · [Details](#example-livekit-speaker-focus) | Filter completed Agent STT turns by speaker in a LiveKit app with a browser visualizer. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |
| [Medical Microbatching](<../use-cases/07-medical-microbatching/README.md>) · [Details](#example-medical-microbatching) | Split microphone audio into Batch jobs with optional speaker tracking and Medical settings. | [Batch](<https://pypi.org/project/speechmatics-batch/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Flutter Mobile Transcription App](<../use-cases/09-flutter-mobile-transcription/README.md>) · [Details](#example-flutter-mobile-transcription) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart | intermediate |

<a id="feature-channel-diarization"></a>
### Channel diarization

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Channel Diarization](<../basics/10-channel-diarization/README.md>) · [Details](#example-channel-diarization) | Transcribe separate audio channels and label each channel. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | beginner |
| [Call Center Analytics](<../use-cases/03-call-center-analytics/README.md>) · [Details](#example-call-center-analytics) | Analyze recorded calls with channel labels, sentiment, topics, and summaries. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Flutter Mobile Transcription App](<../use-cases/09-flutter-mobile-transcription/README.md>) · [Details](#example-flutter-mobile-transcription) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart | intermediate |
| [Oak Consultation Studio](<../use-cases/11-oak-consultation-studio/README.md>) · [Details](#example-oak-consultation-studio) | Explore multilingual medical transcripts with Oak 1, audio playback, and speaker labels. | Direct API / configuration | Python, JavaScript | intermediate |

<a id="feature-custom-vocabulary"></a>
### Custom dictionary

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Hello World - Your First Transcription](<../basics/01-hello-world/README.md>) · [Details](#example-hello-world) | Transcribe a sample audio file with the Batch SDK. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Configuration Guide - Common Configuration Options](<../basics/03-configuration-guide/README.md>) · [Details](#example-configuration-guide) | Configure speaker labels, a custom dictionary, and formatting for Batch transcription. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Agora Conversational AI Voice Agent](<../integrations/agora/01-conversational-ai-agent/README.md>) · [Details](#example-agora-conversational-ai-agent) | Build a browser voice agent with Agora audio, transcripts, and a managed LLM/TTS pipeline. | [Agora Agents](<https://pypi.org/project/agora-agents/>) | Python, TypeScript | intermediate |
| [Speaker Focus Voice Agent](<../integrations/livekit/03-speaker-focus-voice-agent/README.md>) · [Details](#example-livekit-speaker-focus) | Filter completed Agent STT turns by speaker in a LiveKit app with a browser visualizer. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |
| [Vapi Voice Assistant](<../integrations/vapi/01-voice-assistant/README.md>) · [Details](#example-vapi-voice-assistant) | Configure a Vapi voice assistant with Speechmatics STT and a custom dictionary. | [Vapi SDK](<https://pypi.org/project/vapi-server-sdk/>) | Python | beginner |
| [Medical Transcription - Realtime Enhanced Medical](<../use-cases/01-medical-transcription-realtime/README.md>) · [Details](#example-medical-transcription-realtime) | Stream a medical recording with Enhanced Medical and a custom dictionary. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [AI Receptionist](<../use-cases/04-voice-agent-calendar/README.md>) · [Details](#example-voice-agent-calendar) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Santa Voice Agent](<../use-cases/05-santa-voice-agent/README.md>) · [Details](#example-santa-voice-agent) | Build a Santa character voice assistant with LiveKit and optional phone calls. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Medical Assistant](<../use-cases/06-medical-assistant/README.md>) **Preview** · [Details](#example-medical-assistant) | Transcribe Arabic and English consultations and draft structured fields and SOAP notes. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | advanced |
| [Flutter Mobile Transcription App](<../use-cases/09-flutter-mobile-transcription/README.md>) · [Details](#example-flutter-mobile-transcription) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart | intermediate |

<a id="feature-audio-intelligence"></a>
### Speech intelligence

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Speech intelligence - Sentiment, Topics and Summaries](<../basics/04-audio-intelligence/README.md>) · [Details](#example-audio-intelligence) | Extract sentiment, topics, and summaries from a recording. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | intermediate |
| [Call Center Analytics](<../use-cases/03-call-center-analytics/README.md>) · [Details](#example-call-center-analytics) | Analyze recorded calls with channel labels, sentiment, topics, and summaries. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Flutter Mobile Transcription App](<../use-cases/09-flutter-mobile-transcription/README.md>) · [Details](#example-flutter-mobile-transcription) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart | intermediate |

<a id="feature-sentiment-analysis"></a>
### Sentiment analysis

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Speech intelligence - Sentiment, Topics and Summaries](<../basics/04-audio-intelligence/README.md>) · [Details](#example-audio-intelligence) | Extract sentiment, topics, and summaries from a recording. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | intermediate |
| [Call Center Analytics](<../use-cases/03-call-center-analytics/README.md>) · [Details](#example-call-center-analytics) | Analyze recorded calls with channel labels, sentiment, topics, and summaries. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |

<a id="feature-topic-detection"></a>
### Topic detection

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Speech intelligence - Sentiment, Topics and Summaries](<../basics/04-audio-intelligence/README.md>) · [Details](#example-audio-intelligence) | Extract sentiment, topics, and summaries from a recording. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | intermediate |
| [Call Center Analytics](<../use-cases/03-call-center-analytics/README.md>) · [Details](#example-call-center-analytics) | Analyze recorded calls with channel labels, sentiment, topics, and summaries. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Flutter Mobile Transcription App](<../use-cases/09-flutter-mobile-transcription/README.md>) · [Details](#example-flutter-mobile-transcription) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart | intermediate |

<a id="feature-summarization"></a>
### Summarization

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Speech intelligence - Sentiment, Topics and Summaries](<../basics/04-audio-intelligence/README.md>) · [Details](#example-audio-intelligence) | Extract sentiment, topics, and summaries from a recording. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | intermediate |
| [Call Center Analytics](<../use-cases/03-call-center-analytics/README.md>) · [Details](#example-call-center-analytics) | Analyze recorded calls with channel labels, sentiment, topics, and summaries. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Flutter Mobile Transcription App](<../use-cases/09-flutter-mobile-transcription/README.md>) · [Details](#example-flutter-mobile-transcription) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart | intermediate |

<a id="feature-translation"></a>
### Translation

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Multilingual &amp; Translation](<../basics/05-multilingual-translation/README.md>) · [Details](#example-multilingual-translation) | Stream English microphone audio and display Spanish and Russian translations. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Flutter Mobile Transcription App](<../use-cases/09-flutter-mobile-transcription/README.md>) · [Details](#example-flutter-mobile-transcription) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart | intermediate |

<a id="feature-text-to-speech"></a>
### Text to Speech

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Text to Speech](<../basics/06-text-to-speech/README.md>) · [Details](#example-text-to-speech) | Convert text into speech with the TTS SDK. | [TTS](<https://pypi.org/project/speechmatics-tts/>) | Python | beginner |
| [LiveKit Telephony with Twilio](<../integrations/livekit/02-telephony-twilio/README.md>) · [Details](#example-livekit-telephony-twilio) | Receive phone calls through Twilio SIP and respond with a LiveKit voice assistant. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [AI Receptionist](<../use-cases/04-voice-agent-calendar/README.md>) · [Details](#example-voice-agent-calendar) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Alphanumerics Voice Form Filler](<../use-cases/08-alphanumerics-form-filler/README.md>) · [Details](#example-alphanumerics-form-filler) | Fill a browser form with spoken names, email addresses, and numbers through LiveKit. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |

<a id="feature-turn-detection"></a>
### Turn detection

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Basic Turn Detection](<../basics/07-turn-detection/README.md>) · [Details](#example-turn-detection) | Detect the end of speech using silence-based turn detection. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Intelligent Turn Detection](<../basics/08-voice-agent-turn-detection/README.md>) **Legacy** · [Details](#example-voice-agent-turn-detection) | Compare turn-detection presets in the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Preview WebSocket API Explorer](<../basics/11-voice-api-explorer/README.md>) **Preview** · [Details](#example-voice-api-explorer) | Explore raw WebSocket clients for the Voice API preview. | Direct API / configuration | Python, JavaScript | intermediate |
| [Agent STT Linden 1 - Segments, Turns and Speakers](<../basics/13-agent-stt/README.md>) · [Details](#example-agent-stt) | Handle transcript segments, turns, and speakers with Agent STT Linden 1. | [Agent STT](<https://pypi.org/project/speechmatics-agent-stt/>) | Python | intermediate |
| [LiveKit Voice Assistant](<../integrations/livekit/01-simple-voice-assistant/README.md>) · [Details](#example-livekit-voice-assistant) | Build a LiveKit voice assistant with Agent STT, speaker labels, an LLM, and TTS. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [LiveKit Telephony with Twilio](<../integrations/livekit/02-telephony-twilio/README.md>) · [Details](#example-livekit-telephony-twilio) | Receive phone calls through Twilio SIP and respond with a LiveKit voice assistant. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [Speaker Focus Voice Agent](<../integrations/livekit/03-speaker-focus-voice-agent/README.md>) · [Details](#example-livekit-speaker-focus) | Filter completed Agent STT turns by speaker in a LiveKit app with a browser visualizer. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |
| [Pipecat Simple Voice Bot](<../integrations/pipecat/01-simple-voice-bot/README.md>) · [Details](#example-pipecat-voice-bot) | Run a Pipecat voice assistant through a local microphone and speakers. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |
| [Pipecat Simple Voice Bot (Web)](<../integrations/pipecat/02-simple-voice-bot-web/README.md>) · [Details](#example-pipecat-voice-bot-web) | Build a browser voice assistant with Pipecat WebRTC and local turn analysis. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |
| [Twilio Outbound Dialer](<../integrations/twilio/01-outbound-dialer/README.md>) **Legacy** · [Details](#example-twilio-outbound-dialer) | Start outbound phone calls with Twilio Media Streams and the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>) | Python | advanced |
| [Vapi Voice Assistant](<../integrations/vapi/01-voice-assistant/README.md>) · [Details](#example-vapi-voice-assistant) | Configure a Vapi voice assistant with Speechmatics STT and a custom dictionary. | [Vapi SDK](<https://pypi.org/project/vapi-server-sdk/>) | Python | beginner |
| [AI Receptionist](<../use-cases/04-voice-agent-calendar/README.md>) · [Details](#example-voice-agent-calendar) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Santa Voice Agent](<../use-cases/05-santa-voice-agent/README.md>) · [Details](#example-santa-voice-agent) | Build a Santa character voice assistant with LiveKit and optional phone calls. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Medical Assistant](<../use-cases/06-medical-assistant/README.md>) **Preview** · [Details](#example-medical-assistant) | Transcribe Arabic and English consultations and draft structured fields and SOAP notes. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | advanced |
| [Alphanumerics Voice Form Filler](<../use-cases/08-alphanumerics-form-filler/README.md>) · [Details](#example-alphanumerics-form-filler) | Fill a browser form with spoken names, email addresses, and numbers through LiveKit. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |

<a id="feature-voice-agents"></a>
### Voice agents

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Intelligent Turn Detection](<../basics/08-voice-agent-turn-detection/README.md>) **Legacy** · [Details](#example-voice-agent-turn-detection) | Compare turn-detection presets in the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Speaker ID &amp; Speaker Focus](<../basics/09-voice-agent-speaker-id/README.md>) **Legacy** · [Details](#example-voice-agent-speaker-id) | Save speaker identifiers and apply speaker focus with the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Preview WebSocket API Explorer](<../basics/11-voice-api-explorer/README.md>) **Preview** · [Details](#example-voice-api-explorer) | Explore raw WebSocket clients for the Voice API preview. | Direct API / configuration | Python, JavaScript | intermediate |
| [Agent STT Linden 1 - Segments, Turns and Speakers](<../basics/13-agent-stt/README.md>) · [Details](#example-agent-stt) | Handle transcript segments, turns, and speakers with Agent STT Linden 1. | [Agent STT](<https://pypi.org/project/speechmatics-agent-stt/>) | Python | intermediate |
| [Agora Conversational AI Voice Agent](<../integrations/agora/01-conversational-ai-agent/README.md>) · [Details](#example-agora-conversational-ai-agent) | Build a browser voice agent with Agora audio, transcripts, and a managed LLM/TTS pipeline. | [Agora Agents](<https://pypi.org/project/agora-agents/>) | Python, TypeScript | intermediate |
| [LiveKit Voice Assistant](<../integrations/livekit/01-simple-voice-assistant/README.md>) · [Details](#example-livekit-voice-assistant) | Build a LiveKit voice assistant with Agent STT, speaker labels, an LLM, and TTS. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [LiveKit Telephony with Twilio](<../integrations/livekit/02-telephony-twilio/README.md>) · [Details](#example-livekit-telephony-twilio) | Receive phone calls through Twilio SIP and respond with a LiveKit voice assistant. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [Speaker Focus Voice Agent](<../integrations/livekit/03-speaker-focus-voice-agent/README.md>) · [Details](#example-livekit-speaker-focus) | Filter completed Agent STT turns by speaker in a LiveKit app with a browser visualizer. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |
| [Pipecat Simple Voice Bot](<../integrations/pipecat/01-simple-voice-bot/README.md>) · [Details](#example-pipecat-voice-bot) | Run a Pipecat voice assistant through a local microphone and speakers. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |
| [Pipecat Simple Voice Bot (Web)](<../integrations/pipecat/02-simple-voice-bot-web/README.md>) · [Details](#example-pipecat-voice-bot-web) | Build a browser voice assistant with Pipecat WebRTC and local turn analysis. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |
| [Twilio Outbound Dialer](<../integrations/twilio/01-outbound-dialer/README.md>) **Legacy** · [Details](#example-twilio-outbound-dialer) | Start outbound phone calls with Twilio Media Streams and the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>) | Python | advanced |
| [Vapi Voice Assistant](<../integrations/vapi/01-voice-assistant/README.md>) · [Details](#example-vapi-voice-assistant) | Configure a Vapi voice assistant with Speechmatics STT and a custom dictionary. | [Vapi SDK](<https://pypi.org/project/vapi-server-sdk/>) | Python | beginner |
| [AI Receptionist](<../use-cases/04-voice-agent-calendar/README.md>) · [Details](#example-voice-agent-calendar) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Santa Voice Agent](<../use-cases/05-santa-voice-agent/README.md>) · [Details](#example-santa-voice-agent) | Build a Santa character voice assistant with LiveKit and optional phone calls. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Alphanumerics Voice Form Filler](<../use-cases/08-alphanumerics-form-filler/README.md>) · [Details](#example-alphanumerics-form-filler) | Fill a browser form with spoken names, email addresses, and numbers through LiveKit. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |

<a id="by-language"></a>
## By language

<a id="language-python"></a>
### Python

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Hello World - Your First Transcription](<../basics/01-hello-world/README.md>) · [Details](#example-hello-world) | Transcribe a sample audio file with the Batch SDK. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Batch vs Realtime - Understanding API Modes](<../basics/02-batch-vs-realtime/README.md>) · [Details](#example-batch-vs-realtime) | Compare file transcription with Batch and microphone streaming with Realtime. | [Batch](<https://pypi.org/project/speechmatics-batch/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | beginner |
| [Configuration Guide - Common Configuration Options](<../basics/03-configuration-guide/README.md>) · [Details](#example-configuration-guide) | Configure speaker labels, a custom dictionary, and formatting for Batch transcription. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Text to Speech](<../basics/06-text-to-speech/README.md>) · [Details](#example-text-to-speech) | Convert text into speech with the TTS SDK. | [TTS](<https://pypi.org/project/speechmatics-tts/>) | Python | beginner |
| [Channel Diarization](<../basics/10-channel-diarization/README.md>) · [Details](#example-channel-diarization) | Transcribe separate audio channels and label each channel. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | beginner |
| [Melia 1 Multilingual Transcription](<../basics/12-melia-multilingual/README.md>) · [Details](#example-melia-multilingual) | Transcribe audio that switches between languages with Melia 1. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Speech intelligence - Sentiment, Topics and Summaries](<../basics/04-audio-intelligence/README.md>) · [Details](#example-audio-intelligence) | Extract sentiment, topics, and summaries from a recording. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | intermediate |
| [Multilingual &amp; Translation](<../basics/05-multilingual-translation/README.md>) · [Details](#example-multilingual-translation) | Stream English microphone audio and display Spanish and Russian translations. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Basic Turn Detection](<../basics/07-turn-detection/README.md>) · [Details](#example-turn-detection) | Detect the end of speech using silence-based turn detection. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Intelligent Turn Detection](<../basics/08-voice-agent-turn-detection/README.md>) **Legacy** · [Details](#example-voice-agent-turn-detection) | Compare turn-detection presets in the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Speaker ID &amp; Speaker Focus](<../basics/09-voice-agent-speaker-id/README.md>) **Legacy** · [Details](#example-voice-agent-speaker-id) | Save speaker identifiers and apply speaker focus with the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Preview WebSocket API Explorer](<../basics/11-voice-api-explorer/README.md>) **Preview** · [Details](#example-voice-api-explorer) | Explore raw WebSocket clients for the Voice API preview. | Direct API / configuration | Python, JavaScript | intermediate |
| [Agent STT Linden 1 - Segments, Turns and Speakers](<../basics/13-agent-stt/README.md>) · [Details](#example-agent-stt) | Handle transcript segments, turns, and speakers with Agent STT Linden 1. | [Agent STT](<https://pypi.org/project/speechmatics-agent-stt/>) | Python | intermediate |
| [Agora Conversational AI Voice Agent](<../integrations/agora/01-conversational-ai-agent/README.md>) · [Details](#example-agora-conversational-ai-agent) | Build a browser voice agent with Agora audio, transcripts, and a managed LLM/TTS pipeline. | [Agora Agents](<https://pypi.org/project/agora-agents/>) | Python, TypeScript | intermediate |
| [LiveKit Voice Assistant](<../integrations/livekit/01-simple-voice-assistant/README.md>) · [Details](#example-livekit-voice-assistant) | Build a LiveKit voice assistant with Agent STT, speaker labels, an LLM, and TTS. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [LiveKit Telephony with Twilio](<../integrations/livekit/02-telephony-twilio/README.md>) · [Details](#example-livekit-telephony-twilio) | Receive phone calls through Twilio SIP and respond with a LiveKit voice assistant. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [Speaker Focus Voice Agent](<../integrations/livekit/03-speaker-focus-voice-agent/README.md>) · [Details](#example-livekit-speaker-focus) | Filter completed Agent STT turns by speaker in a LiveKit app with a browser visualizer. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |
| [Pipecat Simple Voice Bot](<../integrations/pipecat/01-simple-voice-bot/README.md>) · [Details](#example-pipecat-voice-bot) | Run a Pipecat voice assistant through a local microphone and speakers. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |
| [Pipecat Simple Voice Bot (Web)](<../integrations/pipecat/02-simple-voice-bot-web/README.md>) · [Details](#example-pipecat-voice-bot-web) | Build a browser voice assistant with Pipecat WebRTC and local turn analysis. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |
| [Twilio Outbound Dialer](<../integrations/twilio/01-outbound-dialer/README.md>) **Legacy** · [Details](#example-twilio-outbound-dialer) | Start outbound phone calls with Twilio Media Streams and the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>) | Python | advanced |
| [Vapi Voice Assistant](<../integrations/vapi/01-voice-assistant/README.md>) · [Details](#example-vapi-voice-assistant) | Configure a Vapi voice assistant with Speechmatics STT and a custom dictionary. | [Vapi SDK](<https://pypi.org/project/vapi-server-sdk/>) | Python | beginner |
| [Medical Transcription - Realtime Enhanced Medical](<../use-cases/01-medical-transcription-realtime/README.md>) · [Details](#example-medical-transcription-realtime) | Stream a medical recording with Enhanced Medical and a custom dictionary. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Video Captioning](<../use-cases/02-video-captioning/README.md>) · [Details](#example-video-captioning) | Generate SRT captions from video with the Batch API. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Call Center Analytics](<../use-cases/03-call-center-analytics/README.md>) · [Details](#example-call-center-analytics) | Analyze recorded calls with channel labels, sentiment, topics, and summaries. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [AI Receptionist](<../use-cases/04-voice-agent-calendar/README.md>) · [Details](#example-voice-agent-calendar) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Santa Voice Agent](<../use-cases/05-santa-voice-agent/README.md>) · [Details](#example-santa-voice-agent) | Build a Santa character voice assistant with LiveKit and optional phone calls. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Medical Assistant](<../use-cases/06-medical-assistant/README.md>) **Preview** · [Details](#example-medical-assistant) | Transcribe Arabic and English consultations and draft structured fields and SOAP notes. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | advanced |
| [Medical Microbatching](<../use-cases/07-medical-microbatching/README.md>) · [Details](#example-medical-microbatching) | Split microphone audio into Batch jobs with optional speaker tracking and Medical settings. | [Batch](<https://pypi.org/project/speechmatics-batch/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Alphanumerics Voice Form Filler](<../use-cases/08-alphanumerics-form-filler/README.md>) · [Details](#example-alphanumerics-form-filler) | Fill a browser form with spoken names, email addresses, and numbers through LiveKit. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |
| [Wall of Voices](<../use-cases/10-wall-of-voices/README.md>) **Preview** · [Details](#example-wall-of-voices) | Display live multilingual transcripts with per-word language labels and colors. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | intermediate |
| [Oak Consultation Studio](<../use-cases/11-oak-consultation-studio/README.md>) · [Details](#example-oak-consultation-studio) | Explore multilingual medical transcripts with Oak 1, audio playback, and speaker labels. | Direct API / configuration | Python, JavaScript | intermediate |

<a id="language-typescript"></a>
### TypeScript

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Agora Conversational AI Voice Agent](<../integrations/agora/01-conversational-ai-agent/README.md>) · [Details](#example-agora-conversational-ai-agent) | Build a browser voice agent with Agora audio, transcripts, and a managed LLM/TTS pipeline. | [Agora Agents](<https://pypi.org/project/agora-agents/>) | Python, TypeScript | intermediate |

<a id="language-javascript"></a>
### JavaScript

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Preview WebSocket API Explorer](<../basics/11-voice-api-explorer/README.md>) **Preview** · [Details](#example-voice-api-explorer) | Explore raw WebSocket clients for the Voice API preview. | Direct API / configuration | Python, JavaScript | intermediate |
| [Speaker Focus Voice Agent](<../integrations/livekit/03-speaker-focus-voice-agent/README.md>) · [Details](#example-livekit-speaker-focus) | Filter completed Agent STT turns by speaker in a LiveKit app with a browser visualizer. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |
| [Medical Assistant](<../use-cases/06-medical-assistant/README.md>) **Preview** · [Details](#example-medical-assistant) | Transcribe Arabic and English consultations and draft structured fields and SOAP notes. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | advanced |
| [Alphanumerics Voice Form Filler](<../use-cases/08-alphanumerics-form-filler/README.md>) · [Details](#example-alphanumerics-form-filler) | Fill a browser form with spoken names, email addresses, and numbers through LiveKit. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |
| [Wall of Voices](<../use-cases/10-wall-of-voices/README.md>) **Preview** · [Details](#example-wall-of-voices) | Display live multilingual transcripts with per-word language labels and colors. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | intermediate |
| [Oak Consultation Studio](<../use-cases/11-oak-consultation-studio/README.md>) · [Details](#example-oak-consultation-studio) | Explore multilingual medical transcripts with Oak 1, audio playback, and speaker labels. | Direct API / configuration | Python, JavaScript | intermediate |

<a id="language-dart"></a>
### Dart

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Flutter Mobile Transcription App](<../use-cases/09-flutter-mobile-transcription/README.md>) · [Details](#example-flutter-mobile-transcription) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart | intermediate |

<a id="language-config"></a>
### Configuration

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Tambourine Healthcare Dictation](<../integrations/tambourine/01-healthcare-dictation/README.md>) · [Details](#example-tambourine-healthcare-dictation) | Configure desktop dictation and clinical formatting prompts in Tambourine. | Direct API / configuration | Configuration | beginner |

<a id="by-integration"></a>
## By integration

<a id="integration-agora"></a>
### Agora

Agora RTC/RTM with Speechmatics Realtime transcription and a managed LLM and speech synthesis pipeline.

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Agora Conversational AI Voice Agent](<../integrations/agora/01-conversational-ai-agent/README.md>) · [Details](#example-agora-conversational-ai-agent) | Build a browser voice agent with Agora audio, transcripts, and a managed LLM/TTS pipeline. | [Agora Agents](<https://pypi.org/project/agora-agents/>) | Python, TypeScript | intermediate |

<a id="integration-livekit"></a>
### LiveKit

Voice assistants with Agent STT, speaker controls, browser tools, and SIP telephony.

[Open the LiveKit guide](<../integrations/livekit/README.md>)

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [LiveKit Voice Assistant](<../integrations/livekit/01-simple-voice-assistant/README.md>) · [Details](#example-livekit-voice-assistant) | Build a LiveKit voice assistant with Agent STT, speaker labels, an LLM, and TTS. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [LiveKit Telephony with Twilio](<../integrations/livekit/02-telephony-twilio/README.md>) · [Details](#example-livekit-telephony-twilio) | Receive phone calls through Twilio SIP and respond with a LiveKit voice assistant. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [Speaker Focus Voice Agent](<../integrations/livekit/03-speaker-focus-voice-agent/README.md>) · [Details](#example-livekit-speaker-focus) | Filter completed Agent STT turns by speaker in a LiveKit app with a browser visualizer. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |
| [AI Receptionist](<../use-cases/04-voice-agent-calendar/README.md>) · [Details](#example-voice-agent-calendar) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Santa Voice Agent](<../use-cases/05-santa-voice-agent/README.md>) · [Details](#example-santa-voice-agent) | Build a Santa character voice assistant with LiveKit and optional phone calls. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Alphanumerics Voice Form Filler](<../use-cases/08-alphanumerics-form-filler/README.md>) · [Details](#example-alphanumerics-form-filler) | Fill a browser form with spoken names, email addresses, and numbers through LiveKit. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |

<a id="integration-pipecat"></a>
### Pipecat AI

Local microphone and browser WebRTC voice agents using the Speechmatics adapter.

[Open the Pipecat AI guide](<../integrations/pipecat/README.md>)

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Pipecat Simple Voice Bot](<../integrations/pipecat/01-simple-voice-bot/README.md>) · [Details](#example-pipecat-voice-bot) | Run a Pipecat voice assistant through a local microphone and speakers. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |
| [Pipecat Simple Voice Bot (Web)](<../integrations/pipecat/02-simple-voice-bot-web/README.md>) · [Details](#example-pipecat-voice-bot-web) | Build a browser voice assistant with Pipecat WebRTC and local turn analysis. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |

<a id="integration-tambourine"></a>
### Tambourine Voice

Desktop healthcare dictation with Speechmatics STT and configurable LLM formatting.

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Tambourine Healthcare Dictation](<../integrations/tambourine/01-healthcare-dictation/README.md>) · [Details](#example-tambourine-healthcare-dictation) | Configure desktop dictation and clinical formatting prompts in Tambourine. | Direct API / configuration | Configuration | beginner |

<a id="integration-twilio"></a>
### Twilio

Phone agents through LiveKit SIP or direct Media Streams; the direct example uses the legacy Voice SDK.

[Open the Twilio guide](<../integrations/twilio/README.md>)

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [LiveKit Telephony with Twilio](<../integrations/livekit/02-telephony-twilio/README.md>) · [Details](#example-livekit-telephony-twilio) | Receive phone calls through Twilio SIP and respond with a LiveKit voice assistant. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [Twilio Outbound Dialer](<../integrations/twilio/01-outbound-dialer/README.md>) **Legacy** · [Details](#example-twilio-outbound-dialer) | Start outbound phone calls with Twilio Media Streams and the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>) | Python | advanced |
| [AI Receptionist](<../use-cases/04-voice-agent-calendar/README.md>) · [Details](#example-voice-agent-calendar) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Santa Voice Agent](<../use-cases/05-santa-voice-agent/README.md>) · [Details](#example-santa-voice-agent) | Build a Santa character voice assistant with LiveKit and optional phone calls. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |

<a id="integration-vapi"></a>
### Vapi

Managed voice assistants with Speechmatics streaming transcription and a custom dictionary.

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Vapi Voice Assistant](<../integrations/vapi/01-voice-assistant/README.md>) · [Details](#example-vapi-voice-assistant) | Configure a Vapi voice assistant with Speechmatics STT and a custom dictionary. | [Vapi SDK](<https://pypi.org/project/vapi-server-sdk/>) | Python | beginner |

<a id="integration-openai"></a>
### OpenAI

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Agora Conversational AI Voice Agent](<../integrations/agora/01-conversational-ai-agent/README.md>) · [Details](#example-agora-conversational-ai-agent) | Build a browser voice agent with Agora audio, transcripts, and a managed LLM/TTS pipeline. | [Agora Agents](<https://pypi.org/project/agora-agents/>) | Python, TypeScript | intermediate |
| [LiveKit Voice Assistant](<../integrations/livekit/01-simple-voice-assistant/README.md>) · [Details](#example-livekit-voice-assistant) | Build a LiveKit voice assistant with Agent STT, speaker labels, an LLM, and TTS. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [LiveKit Telephony with Twilio](<../integrations/livekit/02-telephony-twilio/README.md>) · [Details](#example-livekit-telephony-twilio) | Receive phone calls through Twilio SIP and respond with a LiveKit voice assistant. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [Speaker Focus Voice Agent](<../integrations/livekit/03-speaker-focus-voice-agent/README.md>) · [Details](#example-livekit-speaker-focus) | Filter completed Agent STT turns by speaker in a LiveKit app with a browser visualizer. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |
| [Pipecat Simple Voice Bot](<../integrations/pipecat/01-simple-voice-bot/README.md>) · [Details](#example-pipecat-voice-bot) | Run a Pipecat voice assistant through a local microphone and speakers. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |
| [Twilio Outbound Dialer](<../integrations/twilio/01-outbound-dialer/README.md>) **Legacy** · [Details](#example-twilio-outbound-dialer) | Start outbound phone calls with Twilio Media Streams and the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>) | Python | advanced |
| [Vapi Voice Assistant](<../integrations/vapi/01-voice-assistant/README.md>) · [Details](#example-vapi-voice-assistant) | Configure a Vapi voice assistant with Speechmatics STT and a custom dictionary. | [Vapi SDK](<https://pypi.org/project/vapi-server-sdk/>) | Python | beginner |
| [AI Receptionist](<../use-cases/04-voice-agent-calendar/README.md>) · [Details](#example-voice-agent-calendar) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Santa Voice Agent](<../use-cases/05-santa-voice-agent/README.md>) · [Details](#example-santa-voice-agent) | Build a Santa character voice assistant with LiveKit and optional phone calls. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Medical Assistant](<../use-cases/06-medical-assistant/README.md>) **Preview** · [Details](#example-medical-assistant) | Transcribe Arabic and English consultations and draft structured fields and SOAP notes. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | advanced |
| [Alphanumerics Voice Form Filler](<../use-cases/08-alphanumerics-form-filler/README.md>) · [Details](#example-alphanumerics-form-filler) | Fill a browser form with spoken names, email addresses, and numbers through LiveKit. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |

<a id="integration-elevenlabs"></a>
### ElevenLabs

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [LiveKit Voice Assistant](<../integrations/livekit/01-simple-voice-assistant/README.md>) · [Details](#example-livekit-voice-assistant) | Build a LiveKit voice assistant with Agent STT, speaker labels, an LLM, and TTS. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [Speaker Focus Voice Agent](<../integrations/livekit/03-speaker-focus-voice-agent/README.md>) · [Details](#example-livekit-speaker-focus) | Filter completed Agent STT turns by speaker in a LiveKit app with a browser visualizer. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |
| [Pipecat Simple Voice Bot](<../integrations/pipecat/01-simple-voice-bot/README.md>) · [Details](#example-pipecat-voice-bot) | Run a Pipecat voice assistant through a local microphone and speakers. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |
| [Twilio Outbound Dialer](<../integrations/twilio/01-outbound-dialer/README.md>) **Legacy** · [Details](#example-twilio-outbound-dialer) | Start outbound phone calls with Twilio Media Streams and the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>) | Python | advanced |
| [Vapi Voice Assistant](<../integrations/vapi/01-voice-assistant/README.md>) · [Details](#example-vapi-voice-assistant) | Configure a Vapi voice assistant with Speechmatics STT and a custom dictionary. | [Vapi SDK](<https://pypi.org/project/vapi-server-sdk/>) | Python | beginner |
| [Santa Voice Agent](<../use-cases/05-santa-voice-agent/README.md>) · [Details](#example-santa-voice-agent) | Build a Santa character voice assistant with LiveKit and optional phone calls. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |

<a id="integration-groq"></a>
### Groq

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Pipecat Simple Voice Bot (Web)](<../integrations/pipecat/02-simple-voice-bot-web/README.md>) · [Details](#example-pipecat-voice-bot-web) | Build a browser voice assistant with Pipecat WebRTC and local turn analysis. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |

<a id="integration-cartesia"></a>
### Cartesia

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Pipecat Simple Voice Bot (Web)](<../integrations/pipecat/02-simple-voice-bot-web/README.md>) · [Details](#example-pipecat-voice-bot-web) | Build a browser voice assistant with Pipecat WebRTC and local turn analysis. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |

<a id="integration-minimax"></a>
### MiniMax

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Agora Conversational AI Voice Agent](<../integrations/agora/01-conversational-ai-agent/README.md>) · [Details](#example-agora-conversational-ai-agent) | Build a browser voice agent with Agora audio, transcripts, and a managed LLM/TTS pipeline. | [Agora Agents](<https://pypi.org/project/agora-agents/>) | Python, TypeScript | intermediate |

<a id="integration-google-calendar"></a>
### Google Calendar

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [AI Receptionist](<../use-cases/04-voice-agent-calendar/README.md>) · [Details](#example-voice-agent-calendar) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |

<a id="integration-google-translate"></a>
### Google Cloud Translation

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Flutter Mobile Transcription App](<../use-cases/09-flutter-mobile-transcription/README.md>) · [Details](#example-flutter-mobile-transcription) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart | intermediate |

<a id="integration-flutter"></a>
### Flutter

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Flutter Mobile Transcription App](<../use-cases/09-flutter-mobile-transcription/README.md>) · [Details](#example-flutter-mobile-transcription) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart | intermediate |

<a id="integration-vercel"></a>
### Vercel

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Wall of Voices](<../use-cases/10-wall-of-voices/README.md>) **Preview** · [Details](#example-wall-of-voices) | Display live multilingual transcripts with per-word language labels and colors. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | intermediate |
| [Oak Consultation Studio](<../use-cases/11-oak-consultation-studio/README.md>) · [Details](#example-oak-consultation-studio) | Explore multilingual medical transcripts with Oak 1, audio playback, and speaker labels. | Direct API / configuration | Python, JavaScript | intermediate |

<a id="by-collection"></a>
## By collection

<a id="collection-healthcare"></a>
### Healthcare

Medical transcription, clinical dictation, and consultation interfaces.

[Open the Healthcare guide](<../collections/healthcare/README.md>)

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Tambourine Healthcare Dictation](<../integrations/tambourine/01-healthcare-dictation/README.md>) · [Details](#example-tambourine-healthcare-dictation) | Configure desktop dictation and clinical formatting prompts in Tambourine. | Direct API / configuration | Configuration | beginner |
| [Medical Transcription - Realtime Enhanced Medical](<../use-cases/01-medical-transcription-realtime/README.md>) · [Details](#example-medical-transcription-realtime) | Stream a medical recording with Enhanced Medical and a custom dictionary. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Medical Assistant](<../use-cases/06-medical-assistant/README.md>) **Preview** · [Details](#example-medical-assistant) | Transcribe Arabic and English consultations and draft structured fields and SOAP notes. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | advanced |
| [Medical Microbatching](<../use-cases/07-medical-microbatching/README.md>) · [Details](#example-medical-microbatching) | Split microphone audio into Batch jobs with optional speaker tracking and Medical settings. | [Batch](<https://pypi.org/project/speechmatics-batch/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Oak Consultation Studio](<../use-cases/11-oak-consultation-studio/README.md>) · [Details](#example-oak-consultation-studio) | Explore multilingual medical transcripts with Oak 1, audio playback, and speaker labels. | Direct API / configuration | Python, JavaScript | intermediate |

<a id="collection-telephony"></a>
### Telephony

Phone assistants, SIP and Media Streams, and recorded-call analysis.

[Open the Telephony guide](<../collections/telephony/README.md>)

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [LiveKit Telephony with Twilio](<../integrations/livekit/02-telephony-twilio/README.md>) · [Details](#example-livekit-telephony-twilio) | Receive phone calls through Twilio SIP and respond with a LiveKit voice assistant. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [Twilio Outbound Dialer](<../integrations/twilio/01-outbound-dialer/README.md>) **Legacy** · [Details](#example-twilio-outbound-dialer) | Start outbound phone calls with Twilio Media Streams and the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>) | Python | advanced |
| [Call Center Analytics](<../use-cases/03-call-center-analytics/README.md>) · [Details](#example-call-center-analytics) | Analyze recorded calls with channel labels, sentiment, topics, and summaries. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [AI Receptionist](<../use-cases/04-voice-agent-calendar/README.md>) · [Details](#example-voice-agent-calendar) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Santa Voice Agent](<../use-cases/05-santa-voice-agent/README.md>) · [Details](#example-santa-voice-agent) | Build a Santa character voice assistant with LiveKit and optional phone calls. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |

<a id="collection-multilingual"></a>
### Multilingual

Translation, bilingual transcription, and multilingual code-switching.

[Open the Multilingual guide](<../collections/multilingual/README.md>)

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Melia 1 Multilingual Transcription](<../basics/12-melia-multilingual/README.md>) · [Details](#example-melia-multilingual) | Transcribe audio that switches between languages with Melia 1. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Multilingual &amp; Translation](<../basics/05-multilingual-translation/README.md>) · [Details](#example-multilingual-translation) | Stream English microphone audio and display Spanish and Russian translations. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Medical Assistant](<../use-cases/06-medical-assistant/README.md>) **Preview** · [Details](#example-medical-assistant) | Transcribe Arabic and English consultations and draft structured fields and SOAP notes. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | advanced |
| [Flutter Mobile Transcription App](<../use-cases/09-flutter-mobile-transcription/README.md>) · [Details](#example-flutter-mobile-transcription) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart | intermediate |
| [Wall of Voices](<../use-cases/10-wall-of-voices/README.md>) **Preview** · [Details](#example-wall-of-voices) | Display live multilingual transcripts with per-word language labels and colors. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | intermediate |
| [Oak Consultation Studio](<../use-cases/11-oak-consultation-studio/README.md>) · [Details](#example-oak-consultation-studio) | Explore multilingual medical transcripts with Oak 1, audio playback, and speaker labels. | Direct API / configuration | Python, JavaScript | intermediate |

<a id="collection-voice-agents"></a>
### Voice agents

Speech interfaces, turn handling, and complete conversational pipelines.

[Open the Voice agents guide](<../collections/voice-agents/README.md>)

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Basic Turn Detection](<../basics/07-turn-detection/README.md>) · [Details](#example-turn-detection) | Detect the end of speech using silence-based turn detection. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Intelligent Turn Detection](<../basics/08-voice-agent-turn-detection/README.md>) **Legacy** · [Details](#example-voice-agent-turn-detection) | Compare turn-detection presets in the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Speaker ID &amp; Speaker Focus](<../basics/09-voice-agent-speaker-id/README.md>) **Legacy** · [Details](#example-voice-agent-speaker-id) | Save speaker identifiers and apply speaker focus with the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Preview WebSocket API Explorer](<../basics/11-voice-api-explorer/README.md>) **Preview** · [Details](#example-voice-api-explorer) | Explore raw WebSocket clients for the Voice API preview. | Direct API / configuration | Python, JavaScript | intermediate |
| [Agent STT Linden 1 - Segments, Turns and Speakers](<../basics/13-agent-stt/README.md>) · [Details](#example-agent-stt) | Handle transcript segments, turns, and speakers with Agent STT Linden 1. | [Agent STT](<https://pypi.org/project/speechmatics-agent-stt/>) | Python | intermediate |
| [Agora Conversational AI Voice Agent](<../integrations/agora/01-conversational-ai-agent/README.md>) · [Details](#example-agora-conversational-ai-agent) | Build a browser voice agent with Agora audio, transcripts, and a managed LLM/TTS pipeline. | [Agora Agents](<https://pypi.org/project/agora-agents/>) | Python, TypeScript | intermediate |
| [LiveKit Voice Assistant](<../integrations/livekit/01-simple-voice-assistant/README.md>) · [Details](#example-livekit-voice-assistant) | Build a LiveKit voice assistant with Agent STT, speaker labels, an LLM, and TTS. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [LiveKit Telephony with Twilio](<../integrations/livekit/02-telephony-twilio/README.md>) · [Details](#example-livekit-telephony-twilio) | Receive phone calls through Twilio SIP and respond with a LiveKit voice assistant. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [Speaker Focus Voice Agent](<../integrations/livekit/03-speaker-focus-voice-agent/README.md>) · [Details](#example-livekit-speaker-focus) | Filter completed Agent STT turns by speaker in a LiveKit app with a browser visualizer. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |
| [Pipecat Simple Voice Bot](<../integrations/pipecat/01-simple-voice-bot/README.md>) · [Details](#example-pipecat-voice-bot) | Run a Pipecat voice assistant through a local microphone and speakers. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |
| [Pipecat Simple Voice Bot (Web)](<../integrations/pipecat/02-simple-voice-bot-web/README.md>) · [Details](#example-pipecat-voice-bot-web) | Build a browser voice assistant with Pipecat WebRTC and local turn analysis. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |
| [Twilio Outbound Dialer](<../integrations/twilio/01-outbound-dialer/README.md>) **Legacy** · [Details](#example-twilio-outbound-dialer) | Start outbound phone calls with Twilio Media Streams and the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>) | Python | advanced |
| [Vapi Voice Assistant](<../integrations/vapi/01-voice-assistant/README.md>) · [Details](#example-vapi-voice-assistant) | Configure a Vapi voice assistant with Speechmatics STT and a custom dictionary. | [Vapi SDK](<https://pypi.org/project/vapi-server-sdk/>) | Python | beginner |
| [AI Receptionist](<../use-cases/04-voice-agent-calendar/README.md>) · [Details](#example-voice-agent-calendar) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Santa Voice Agent](<../use-cases/05-santa-voice-agent/README.md>) · [Details](#example-santa-voice-agent) | Build a Santa character voice assistant with LiveKit and optional phone calls. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Alphanumerics Voice Form Filler](<../use-cases/08-alphanumerics-form-filler/README.md>) · [Details](#example-alphanumerics-form-filler) | Fill a browser form with spoken names, email addresses, and numbers through LiveKit. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |

<a id="collection-captions-insights"></a>
### Captions and insights

Captions, live transcript displays, sentiment, topics, and summaries.

[Open the Captions and insights guide](<../collections/captions-insights/README.md>)

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Speech intelligence - Sentiment, Topics and Summaries](<../basics/04-audio-intelligence/README.md>) · [Details](#example-audio-intelligence) | Extract sentiment, topics, and summaries from a recording. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | intermediate |
| [Video Captioning](<../use-cases/02-video-captioning/README.md>) · [Details](#example-video-captioning) | Generate SRT captions from video with the Batch API. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Call Center Analytics](<../use-cases/03-call-center-analytics/README.md>) · [Details](#example-call-center-analytics) | Analyze recorded calls with channel labels, sentiment, topics, and summaries. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Flutter Mobile Transcription App](<../use-cases/09-flutter-mobile-transcription/README.md>) · [Details](#example-flutter-mobile-transcription) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart | intermediate |
| [Wall of Voices](<../use-cases/10-wall-of-voices/README.md>) **Preview** · [Details](#example-wall-of-voices) | Display live multilingual transcripts with per-word language labels and colors. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | intermediate |

<a id="collection-mobile"></a>
### Mobile

Mobile audio capture and transcription applications.

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Flutter Mobile Transcription App](<../use-cases/09-flutter-mobile-transcription/README.md>) · [Details](#example-flutter-mobile-transcription) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart | intermediate |

<a id="by-difficulty"></a>
## By difficulty

<a id="difficulty-beginner"></a>
### Beginner

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Hello World - Your First Transcription](<../basics/01-hello-world/README.md>) · [Details](#example-hello-world) | Transcribe a sample audio file with the Batch SDK. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Batch vs Realtime - Understanding API Modes](<../basics/02-batch-vs-realtime/README.md>) · [Details](#example-batch-vs-realtime) | Compare file transcription with Batch and microphone streaming with Realtime. | [Batch](<https://pypi.org/project/speechmatics-batch/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | beginner |
| [Configuration Guide - Common Configuration Options](<../basics/03-configuration-guide/README.md>) · [Details](#example-configuration-guide) | Configure speaker labels, a custom dictionary, and formatting for Batch transcription. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Text to Speech](<../basics/06-text-to-speech/README.md>) · [Details](#example-text-to-speech) | Convert text into speech with the TTS SDK. | [TTS](<https://pypi.org/project/speechmatics-tts/>) | Python | beginner |
| [Channel Diarization](<../basics/10-channel-diarization/README.md>) · [Details](#example-channel-diarization) | Transcribe separate audio channels and label each channel. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | beginner |
| [Melia 1 Multilingual Transcription](<../basics/12-melia-multilingual/README.md>) · [Details](#example-melia-multilingual) | Transcribe audio that switches between languages with Melia 1. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Vapi Voice Assistant](<../integrations/vapi/01-voice-assistant/README.md>) · [Details](#example-vapi-voice-assistant) | Configure a Vapi voice assistant with Speechmatics STT and a custom dictionary. | [Vapi SDK](<https://pypi.org/project/vapi-server-sdk/>) | Python | beginner |
| [Tambourine Healthcare Dictation](<../integrations/tambourine/01-healthcare-dictation/README.md>) · [Details](#example-tambourine-healthcare-dictation) | Configure desktop dictation and clinical formatting prompts in Tambourine. | Direct API / configuration | Configuration | beginner |
| [Video Captioning](<../use-cases/02-video-captioning/README.md>) · [Details](#example-video-captioning) | Generate SRT captions from video with the Batch API. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |
| [Call Center Analytics](<../use-cases/03-call-center-analytics/README.md>) · [Details](#example-call-center-analytics) | Analyze recorded calls with channel labels, sentiment, topics, and summaries. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | beginner |

<a id="difficulty-intermediate"></a>
### Intermediate

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Speech intelligence - Sentiment, Topics and Summaries](<../basics/04-audio-intelligence/README.md>) · [Details](#example-audio-intelligence) | Extract sentiment, topics, and summaries from a recording. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python | intermediate |
| [Multilingual &amp; Translation](<../basics/05-multilingual-translation/README.md>) · [Details](#example-multilingual-translation) | Stream English microphone audio and display Spanish and Russian translations. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Basic Turn Detection](<../basics/07-turn-detection/README.md>) · [Details](#example-turn-detection) | Detect the end of speech using silence-based turn detection. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Intelligent Turn Detection](<../basics/08-voice-agent-turn-detection/README.md>) **Legacy** · [Details](#example-voice-agent-turn-detection) | Compare turn-detection presets in the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Speaker ID &amp; Speaker Focus](<../basics/09-voice-agent-speaker-id/README.md>) **Legacy** · [Details](#example-voice-agent-speaker-id) | Save speaker identifiers and apply speaker focus with the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Preview WebSocket API Explorer](<../basics/11-voice-api-explorer/README.md>) **Preview** · [Details](#example-voice-api-explorer) | Explore raw WebSocket clients for the Voice API preview. | Direct API / configuration | Python, JavaScript | intermediate |
| [Agent STT Linden 1 - Segments, Turns and Speakers](<../basics/13-agent-stt/README.md>) · [Details](#example-agent-stt) | Handle transcript segments, turns, and speakers with Agent STT Linden 1. | [Agent STT](<https://pypi.org/project/speechmatics-agent-stt/>) | Python | intermediate |
| [Agora Conversational AI Voice Agent](<../integrations/agora/01-conversational-ai-agent/README.md>) · [Details](#example-agora-conversational-ai-agent) | Build a browser voice agent with Agora audio, transcripts, and a managed LLM/TTS pipeline. | [Agora Agents](<https://pypi.org/project/agora-agents/>) | Python, TypeScript | intermediate |
| [LiveKit Voice Assistant](<../integrations/livekit/01-simple-voice-assistant/README.md>) · [Details](#example-livekit-voice-assistant) | Build a LiveKit voice assistant with Agent STT, speaker labels, an LLM, and TTS. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [LiveKit Telephony with Twilio](<../integrations/livekit/02-telephony-twilio/README.md>) · [Details](#example-livekit-telephony-twilio) | Receive phone calls through Twilio SIP and respond with a LiveKit voice assistant. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | intermediate |
| [Speaker Focus Voice Agent](<../integrations/livekit/03-speaker-focus-voice-agent/README.md>) · [Details](#example-livekit-speaker-focus) | Filter completed Agent STT turns by speaker in a LiveKit app with a browser visualizer. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |
| [Pipecat Simple Voice Bot](<../integrations/pipecat/01-simple-voice-bot/README.md>) · [Details](#example-pipecat-voice-bot) | Run a Pipecat voice assistant through a local microphone and speakers. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |
| [Pipecat Simple Voice Bot (Web)](<../integrations/pipecat/02-simple-voice-bot-web/README.md>) · [Details](#example-pipecat-voice-bot-web) | Build a browser voice assistant with Pipecat WebRTC and local turn analysis. | [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>) | Python | intermediate |
| [Medical Transcription - Realtime Enhanced Medical](<../use-cases/01-medical-transcription-realtime/README.md>) · [Details](#example-medical-transcription-realtime) | Stream a medical recording with Enhanced Medical and a custom dictionary. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Medical Microbatching](<../use-cases/07-medical-microbatching/README.md>) · [Details](#example-medical-microbatching) | Split microphone audio into Batch jobs with optional speaker tracking and Medical settings. | [Batch](<https://pypi.org/project/speechmatics-batch/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python | intermediate |
| [Alphanumerics Voice Form Filler](<../use-cases/08-alphanumerics-form-filler/README.md>) · [Details](#example-alphanumerics-form-filler) | Fill a browser form with spoken names, email addresses, and numbers through LiveKit. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python, JavaScript | intermediate |
| [Flutter Mobile Transcription App](<../use-cases/09-flutter-mobile-transcription/README.md>) · [Details](#example-flutter-mobile-transcription) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart | intermediate |
| [Wall of Voices](<../use-cases/10-wall-of-voices/README.md>) **Preview** · [Details](#example-wall-of-voices) | Display live multilingual transcripts with per-word language labels and colors. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | intermediate |
| [Oak Consultation Studio](<../use-cases/11-oak-consultation-studio/README.md>) · [Details](#example-oak-consultation-studio) | Explore multilingual medical transcripts with Oak 1, audio playback, and speaker labels. | Direct API / configuration | Python, JavaScript | intermediate |

<a id="difficulty-advanced"></a>
### Advanced

| Example | Description | Packages | Languages | Difficulty |
| --- | --- | --- | --- | --- |
| [Twilio Outbound Dialer](<../integrations/twilio/01-outbound-dialer/README.md>) **Legacy** · [Details](#example-twilio-outbound-dialer) | Start outbound phone calls with Twilio Media Streams and the deprecated Voice SDK. | [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>) | Python | advanced |
| [AI Receptionist](<../use-cases/04-voice-agent-calendar/README.md>) · [Details](#example-voice-agent-calendar) | Build a LiveKit receptionist that manages appointments in Google Calendar. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Santa Voice Agent](<../use-cases/05-santa-voice-agent/README.md>) · [Details](#example-santa-voice-agent) | Build a Santa character voice assistant with LiveKit and optional phone calls. | [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>) | Python | advanced |
| [Medical Assistant](<../use-cases/06-medical-assistant/README.md>) **Preview** · [Details](#example-medical-assistant) | Transcribe Arabic and English consultations and draft structured fields and SOAP notes. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript | advanced |

<a id="all-example-details"></a>
## Example details

<a id="example-hello-world"></a>
### Hello World - Your First Transcription

Example ID: `hello-world`. [Canonical README](<../basics/01-hello-world/README.md>).

Transcribe a sample audio file with the Batch SDK and a minimal custom dictionary.

Implementation: current; kind: code; difficulty: beginner; languages: Python.

- APIs: [Speechmatics Batch API](<https://docs.speechmatics.com/speech-to-text/batch/quickstart>)
- Packages: [Batch](<https://pypi.org/project/speechmatics-batch/>)
- Features: Batch transcription, Custom dictionary
- Integrations: None listed
- Collections: None listed
- Estimated time: 5 minutes; last updated: 2025-11-27
- Demos: [Local](<../basics/01-hello-world/README.md>): Speechmatics API key; see the walkthrough for runtime and audio requirements.

<a id="example-batch-vs-realtime"></a>
### Batch vs Realtime - Understanding API Modes

Example ID: `batch-vs-realtime`. [Canonical README](<../basics/02-batch-vs-realtime/README.md>).

Learn the difference between Batch and Realtime transcription modes and when to use each.

Implementation: current; kind: code; difficulty: beginner; languages: Python.

- APIs: [Speechmatics Batch API](<https://docs.speechmatics.com/speech-to-text/batch/quickstart>), [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>)
- Packages: [Batch](<https://pypi.org/project/speechmatics-batch/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>)
- Features: Batch transcription, Realtime transcription
- Integrations: None listed
- Collections: None listed
- Estimated time: 10 minutes; last updated: 2025-11-27
- Demos: [Local](<../basics/02-batch-vs-realtime/README.md>): Speechmatics API key; see the walkthrough for runtime and audio requirements.

<a id="example-configuration-guide"></a>
### Configuration Guide - Common Configuration Options

Example ID: `configuration-guide`. [Canonical README](<../basics/03-configuration-guide/README.md>).

Configure Batch transcription with speaker diarization, a custom dictionary, smart formatting, and model quality settings.

Implementation: current; kind: code; difficulty: beginner; languages: Python.

- APIs: [Speechmatics Batch API](<https://docs.speechmatics.com/speech-to-text/batch/quickstart>)
- Packages: [Batch](<https://pypi.org/project/speechmatics-batch/>)
- Features: Batch transcription, Speaker diarization, Custom dictionary
- Integrations: None listed
- Collections: None listed
- Estimated time: 15 minutes; last updated: 2025-11-27
- Demos: [Local](<../basics/03-configuration-guide/README.md>): Speechmatics API key; see the walkthrough for runtime and audio requirements.

<a id="example-text-to-speech"></a>
### Text to Speech

Example ID: `text-to-speech`. [Canonical README](<../basics/06-text-to-speech/README.md>).

Convert text to natural-sounding speech using Speechmatics TTS.

Implementation: current; kind: code; difficulty: beginner; languages: Python.

- APIs: [Speechmatics Text to Speech API](<https://docs.speechmatics.com/text-to-speech/quickstart>)
- Packages: [TTS](<https://pypi.org/project/speechmatics-tts/>)
- Features: Text to Speech
- Integrations: None listed
- Collections: None listed
- Estimated time: 10 minutes; last updated: 2025-11-28
- Demos: [Local](<../basics/06-text-to-speech/README.md>): Speechmatics API key; see the walkthrough for runtime and audio requirements.

<a id="example-channel-diarization"></a>
### Channel Diarization

Example ID: `channel-diarization`. [Canonical README](<../basics/10-channel-diarization/README.md>).

Transcribe separate audio channels with the Realtime SDK and assign a label to each channel.

Implementation: current; kind: code; difficulty: beginner; languages: Python.

- APIs: [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>)
- Packages: [Realtime](<https://pypi.org/project/speechmatics-rt/>)
- Features: Realtime transcription, Channel diarization
- Integrations: None listed
- Collections: None listed
- Estimated time: 10 minutes; last updated: 2025-11-30
- Demos: [Local](<../basics/10-channel-diarization/README.md>): Speechmatics API key; see the walkthrough for runtime and audio requirements.

<a id="example-melia-multilingual"></a>
### Melia 1 Multilingual Transcription

Example ID: `melia-multilingual`. [Canonical README](<../basics/12-melia-multilingual/README.md>).

Transcribe code-switching audio with Melia 1 using the Batch SDK and automatic multilingual recognition.

Implementation: current; kind: code; difficulty: beginner; languages: Python.

- APIs: [Speechmatics Batch API](<https://docs.speechmatics.com/speech-to-text/batch/quickstart>)
- Packages: [Batch](<https://pypi.org/project/speechmatics-batch/>)
- Features: Batch transcription
- Integrations: None listed
- Collections: Multilingual
- Estimated time: 5 minutes; last updated: 2026-06-16
- Demos: [Local](<../basics/12-melia-multilingual/README.md>): Speechmatics API key; see the walkthrough for runtime and audio requirements.
- Demonstrated model IDs: melia-1

<a id="example-audio-intelligence"></a>
### Speech intelligence - Sentiment, Topics and Summaries

Example ID: `audio-intelligence`. [Canonical README](<../basics/04-audio-intelligence/README.md>).

Extract insights with sentiment analysis, topic detection, and automatic summarization.

Implementation: current; kind: code; difficulty: intermediate; languages: Python.

- APIs: [Speechmatics Batch API](<https://docs.speechmatics.com/speech-to-text/batch/quickstart>)
- Packages: [Batch](<https://pypi.org/project/speechmatics-batch/>)
- Features: Batch transcription, Speech intelligence, Sentiment analysis, Topic detection, Summarization
- Integrations: None listed
- Collections: Captions and insights
- Estimated time: 15 minutes; last updated: 2025-11-27
- Demos: [Local](<../basics/04-audio-intelligence/README.md>): Speechmatics API key; see the walkthrough for runtime and audio requirements.

<a id="example-multilingual-translation"></a>
### Multilingual &amp; Translation

Example ID: `multilingual-translation`. [Canonical README](<../basics/05-multilingual-translation/README.md>).

Stream English microphone audio to the Realtime API and display partial and final Spanish and Russian translations.

Implementation: current; kind: code; difficulty: intermediate; languages: Python.

- APIs: [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>)
- Packages: [Realtime](<https://pypi.org/project/speechmatics-rt/>)
- Features: Realtime transcription, Translation
- Integrations: None listed
- Collections: Multilingual
- Estimated time: 10 minutes; last updated: 2025-11-27
- Demos: [Local](<../basics/05-multilingual-translation/README.md>): Speechmatics API key; see the walkthrough for runtime and audio requirements.

<a id="example-turn-detection"></a>
### Basic Turn Detection

Example ID: `turn-detection`. [Canonical README](<../basics/07-turn-detection/README.md>).

Detect when speech ends using silence-based turn detection for real-time applications.

Implementation: current; kind: code; difficulty: intermediate; languages: Python.

- APIs: [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>)
- Packages: [Realtime](<https://pypi.org/project/speechmatics-rt/>)
- Features: Realtime transcription, Turn detection
- Integrations: None listed
- Collections: Voice agents
- Estimated time: 10 minutes; last updated: 2025-11-28
- Demos: [Local](<../basics/07-turn-detection/README.md>): Speechmatics API key; see the walkthrough for runtime and audio requirements.

<a id="example-voice-agent-turn-detection"></a>
### Intelligent Turn Detection

Example ID: `voice-agent-turn-detection`. [Canonical README](<../basics/08-voice-agent-turn-detection/README.md>).

Compare client-side turn-detection presets in the deprecated Voice SDK; start new applications with Agent STT.

Implementation: legacy; kind: code; difficulty: intermediate; languages: Python.

- APIs: [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>)
- Packages: [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>)
- Features: Realtime transcription, Voice agents, Turn detection
- Integrations: None listed
- Collections: Voice agents
- Estimated time: 15 minutes; last updated: 2025-11-28
- Demos: [Local](<../basics/08-voice-agent-turn-detection/README.md>): Speechmatics API key; see the walkthrough for runtime and audio requirements.

<a id="example-voice-agent-speaker-id"></a>
### Speaker ID &amp; Speaker Focus

Example ID: `voice-agent-speaker-id`. [Canonical README](<../basics/09-voice-agent-speaker-id/README.md>).

Extract reusable speaker identifiers and apply speaker focus with the deprecated Voice SDK.

Implementation: legacy; kind: code; difficulty: intermediate; languages: Python.

- APIs: [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>)
- Packages: [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>)
- Features: Realtime transcription, Voice agents, Speaker diarization, Speaker identification
- Integrations: None listed
- Collections: Voice agents
- Estimated time: 15 minutes; last updated: 2025-11-28
- Demos: [Local](<../basics/09-voice-agent-speaker-id/README.md>): Speechmatics API key; see the walkthrough for runtime and audio requirements.

<a id="example-voice-api-explorer"></a>
### Preview WebSocket API Explorer

Example ID: `voice-api-explorer`. [Canonical README](<../basics/11-voice-api-explorer/README.md>).

Explore raw Python and JavaScript WebSocket clients for the Voice API preview and its older agent profile routes; confirm access before running.

Implementation: preview; kind: code; difficulty: intermediate; languages: Python, JavaScript.

- APIs: [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>), Voice API preview
- Packages: Direct API / configuration
- Features: Realtime transcription, Voice agents, Speaker diarization, Speaker identification, Turn detection
- Integrations: None listed
- Collections: Voice agents
- Estimated time: 20 minutes; last updated: 2026-03-12
- Demos: [Local](<../basics/11-voice-api-explorer/README.md>): Local Python or JavaScript clients for the Voice API preview.
- Demo access: Confirm access to the Voice API preview and its older agent profile routes before running.

The Voice API preview is a legacy protocol, separate from Agent STT.

<a id="example-agent-stt"></a>
### Agent STT Linden 1 - Segments, Turns and Speakers

Example ID: `agent-stt`. [Canonical README](<../basics/13-agent-stt/README.md>).

Use Agent STT for transcript segments, speech and turn events, speaker labels and reusable voiceprints, with service VAD or external finalization.

Implementation: current; kind: code; difficulty: intermediate; languages: Python.

- APIs: [Speechmatics Agent STT (Linden 1)](<https://docs.speechmatics.com/speech-to-text/agent-stt>)
- Packages: [Agent STT](<https://pypi.org/project/speechmatics-agent-stt/>)
- Features: Realtime transcription, Turn detection, Voice agents, Speaker diarization, Speaker identification
- Integrations: None listed
- Collections: Voice agents
- Estimated time: 10 minutes; last updated: 2026-09-15
- Demos: [Local](<../basics/13-agent-stt/README.md>): Speechmatics API key; see the walkthrough for runtime and audio requirements.

<a id="example-agora-conversational-ai-agent"></a>
### Agora Conversational AI Voice Agent

Example ID: `agora-conversational-ai-agent`. [Canonical README](<../integrations/agora/01-conversational-ai-agent/README.md>).

Build a Python and TypeScript browser voice agent with Agora RTC/RTM, Speechmatics Realtime transcription, a managed OpenAI LLM, and MiniMax TTS.

Implementation: current; kind: code; difficulty: intermediate; languages: Python, TypeScript.

- APIs: [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>)
- Packages: [Agora Agents](<https://pypi.org/project/agora-agents/>)
- Features: Realtime transcription, Voice agents, Custom dictionary
- Integrations: Agora, OpenAI, MiniMax
- Collections: Voice agents
- Estimated time: 20 minutes; last updated: 2026-09-15
- Demos: [Recording](<../integrations/agora/01-conversational-ai-agent/assets/agora-conversational-ai.gif>): Recorded walkthrough of the browser voice agent and pipeline latency display.<br>[Local](<../integrations/agora/01-conversational-ai-agent/README.md>): Provider accounts and API keys; see the walkthrough for setup requirements.

<a id="example-livekit-voice-assistant"></a>
### LiveKit Voice Assistant

Example ID: `livekit-voice-assistant`. [Canonical README](<../integrations/livekit/01-simple-voice-assistant/README.md>).

Build a LiveKit voice assistant with Agent STT Linden 1, VAD, speaker diarization and identification, an OpenAI LLM, and ElevenLabs TTS.

Implementation: current; kind: code; difficulty: intermediate; languages: Python.

- APIs: [Speechmatics Agent STT (Linden 1)](<https://docs.speechmatics.com/speech-to-text/agent-stt>)
- Packages: [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>)
- Features: Realtime transcription, Speaker diarization, Speaker identification, Turn detection, Voice agents
- Integrations: LiveKit, OpenAI, ElevenLabs
- Collections: Voice agents
- Estimated time: 20 minutes; last updated: 2025-11-28
- Demos: [Local](<../integrations/livekit/01-simple-voice-assistant/README.md>): Provider accounts and API keys; see the walkthrough for setup requirements.

<a id="example-livekit-telephony-twilio"></a>
### LiveKit Telephony with Twilio

Example ID: `livekit-telephony-twilio`. [Canonical README](<../integrations/livekit/02-telephony-twilio/README.md>).

Build an inbound phone assistant with Twilio SIP, LiveKit, Agent STT Linden 1, OpenAI, and Speechmatics TTS.

Implementation: current; kind: code; difficulty: intermediate; languages: Python.

- APIs: [Speechmatics Agent STT (Linden 1)](<https://docs.speechmatics.com/speech-to-text/agent-stt>), [Speechmatics Text to Speech API](<https://docs.speechmatics.com/text-to-speech/quickstart>)
- Packages: [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>)
- Features: Realtime transcription, Text to Speech, Turn detection, Voice agents
- Integrations: LiveKit, Twilio, OpenAI
- Collections: Telephony, Voice agents
- Estimated time: 25 minutes; last updated: 2025-11-29
- Demos: [Local](<../integrations/livekit/02-telephony-twilio/README.md>): Provider accounts and API keys; see the walkthrough for setup requirements.
- Demo access: Phone testing requires a Twilio number and configured SIP trunking.

<a id="example-livekit-speaker-focus"></a>
### Speaker Focus Voice Agent

Example ID: `livekit-speaker-focus`. [Canonical README](<../integrations/livekit/03-speaker-focus-voice-agent/README.md>).

Filter completed Agent STT turns in a LiveKit application using speaker labels and saved identifiers, with a browser visualizer; focus filtering is application-side.

Implementation: current; kind: code; difficulty: intermediate; languages: Python, JavaScript.

- APIs: [Speechmatics Agent STT (Linden 1)](<https://docs.speechmatics.com/speech-to-text/agent-stt>)
- Packages: [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>)
- Features: Realtime transcription, Speaker diarization, Speaker identification, Voice agents, Custom dictionary, Turn detection
- Integrations: LiveKit, OpenAI, ElevenLabs
- Collections: Voice agents
- Estimated time: 20 minutes; last updated: 2026-07-17
- Demos: [Local](<../integrations/livekit/03-speaker-focus-voice-agent/README.md>): Provider accounts and API keys; see the walkthrough for setup requirements.

<a id="example-pipecat-voice-bot"></a>
### Pipecat Simple Voice Bot

Example ID: `pipecat-voice-bot`. [Canonical README](<../integrations/pipecat/01-simple-voice-bot/README.md>).

Run a local-microphone Pipecat assistant with Agent STT Linden 1, external VAD finalization, speaker labels, OpenAI, and ElevenLabs.

Implementation: current; kind: code; difficulty: intermediate; languages: Python.

- APIs: [Speechmatics Agent STT (Linden 1)](<https://docs.speechmatics.com/speech-to-text/agent-stt>)
- Packages: [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>)
- Features: Realtime transcription, Speaker diarization, Turn detection, Voice agents
- Integrations: Pipecat AI, OpenAI, ElevenLabs
- Collections: Voice agents
- Estimated time: 20 minutes; last updated: 2025-11-28
- Demos: [Local](<../integrations/pipecat/01-simple-voice-bot/README.md>): Provider accounts and API keys; see the walkthrough for setup requirements.
- Demo access: Requires local microphone and speaker access plus PortAudio; the Web example uses browser audio.

<a id="example-pipecat-voice-bot-web"></a>
### Pipecat Simple Voice Bot (Web)

Example ID: `pipecat-voice-bot-web`. [Canonical README](<../integrations/pipecat/02-simple-voice-bot-web/README.md>).

Build a browser WebRTC assistant with Pipecat, Agent STT Linden 1, external VAD and local smart-turn analysis, a Groq LLM, and Cartesia TTS.

Implementation: current; kind: code; difficulty: intermediate; languages: Python.

- APIs: [Speechmatics Agent STT (Linden 1)](<https://docs.speechmatics.com/speech-to-text/agent-stt>)
- Packages: [Pipecat adapter](<https://pypi.org/project/pipecat-ai/>)
- Features: Realtime transcription, Speaker diarization, Turn detection, Voice agents
- Integrations: Pipecat AI, Groq, Cartesia
- Collections: Voice agents
- Estimated time: 20 minutes; last updated: 2026-10-21
- Demos: [Local](<../integrations/pipecat/02-simple-voice-bot-web/README.md>): Provider accounts and API keys; see the walkthrough for setup requirements.
- Demo access: Use macOS, Linux, or WSL2 for the documented backend setup; the client runs in a browser.

<a id="example-twilio-outbound-dialer"></a>
### Twilio Outbound Dialer

Example ID: `twilio-outbound-dialer`. [Canonical README](<../integrations/twilio/01-outbound-dialer/README.md>).

Start outbound Twilio calls and process Media Streams with the deprecated Voice SDK, an OpenAI LLM, and ElevenLabs TTS.

Implementation: legacy; kind: code; difficulty: advanced; languages: Python.

- APIs: [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>)
- Packages: [Voice SDK (legacy)](<https://pypi.org/project/speechmatics-voice/>)
- Features: Realtime transcription, Turn detection, Voice agents
- Integrations: Twilio, OpenAI, ElevenLabs
- Collections: Telephony, Voice agents
- Estimated time: 20 minutes; last updated: 2025-11-29
- Demos: [Local](<../integrations/twilio/01-outbound-dialer/README.md>): Provider accounts and API keys; see the walkthrough for setup requirements.
- Demo access: Starts real outbound calls. Protect the dial endpoint and validate Twilio callbacks before exposing a tunnel.

<a id="example-vapi-voice-assistant"></a>
### Vapi Voice Assistant

Example ID: `vapi-voice-assistant`. [Canonical README](<../integrations/vapi/01-voice-assistant/README.md>).

Configure a Vapi assistant with Speechmatics Enhanced streaming STT, a custom dictionary, OpenAI, and ElevenLabs.

Implementation: current; kind: code; difficulty: beginner; languages: Python.

- APIs: [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>)
- Packages: [Vapi SDK](<https://pypi.org/project/vapi-server-sdk/>)
- Features: Realtime transcription, Custom dictionary, Speaker diarization, Turn detection, Voice agents
- Integrations: Vapi, OpenAI, ElevenLabs
- Collections: Voice agents
- Estimated time: 15 minutes; last updated: 2025-11-30
- Demos: [Local](<../integrations/vapi/01-voice-assistant/README.md>): Provider accounts and API keys; see the walkthrough for setup requirements.

<a id="example-tambourine-healthcare-dictation"></a>
### Tambourine Healthcare Dictation

Example ID: `tambourine-healthcare-dictation`. [Canonical README](<../integrations/tambourine/01-healthcare-dictation/README.md>).

Configure Tambourine desktop dictation and clinical LLM formatting prompts; its installed STT adapter determines the Speechmatics endpoint and model.

Implementation: current; kind: configuration; difficulty: beginner; languages: Configuration.

- APIs: [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>)
- Packages: Direct API / configuration
- Features: Realtime transcription
- Integrations: Tambourine Voice
- Collections: Healthcare
- Estimated time: 15 minutes; last updated: 2025-12-30
- Demos: [Local](<../integrations/tambourine/01-healthcare-dictation/README.md>): Install Tambourine and configure Speechmatics plus an LLM provider.
- Demo access: Requires a separate Tambourine desktop installation; its installed STT adapter determines the model and endpoint.

<a id="example-medical-transcription-realtime"></a>
### Medical Transcription - Realtime Enhanced Medical

Example ID: `medical-transcription-realtime`. [Canonical README](<../use-cases/01-medical-transcription-realtime/README.md>).

Stream a medical recording with Realtime Enhanced Medical and a custom dictionary for clinical terminology.

Implementation: current; kind: code; difficulty: intermediate; languages: Python.

- APIs: [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>)
- Packages: [Realtime](<https://pypi.org/project/speechmatics-rt/>)
- Features: Realtime transcription, Custom dictionary, Speaker diarization
- Integrations: None listed
- Collections: Healthcare
- Estimated time: 20 minutes; last updated: 2025-12-01
- Demos: [Local](<../use-cases/01-medical-transcription-realtime/README.md>): Speechmatics API key; see the walkthrough for runtime and audio requirements.

<a id="example-video-captioning"></a>
### Video Captioning

Example ID: `video-captioning`. [Canonical README](<../use-cases/02-video-captioning/README.md>).

Generate SRT captions for video content with timestamp synchronization and batch processing.

Implementation: current; kind: code; difficulty: beginner; languages: Python.

- APIs: [Speechmatics Batch API](<https://docs.speechmatics.com/speech-to-text/batch/quickstart>)
- Packages: [Batch](<https://pypi.org/project/speechmatics-batch/>)
- Features: Batch transcription
- Integrations: None listed
- Collections: Captions and insights
- Estimated time: 15 minutes; last updated: 2025-12-01
- Demos: [Local](<../use-cases/02-video-captioning/README.md>): Speechmatics API key; see the walkthrough for runtime and audio requirements.

<a id="example-call-center-analytics"></a>
### Call Center Analytics

Example ID: `call-center-analytics`. [Canonical README](<../use-cases/03-call-center-analytics/README.md>).

Analyze stereo call recordings with channel labels, sentiment analysis, topic detection, and summaries.

Implementation: current; kind: code; difficulty: beginner; languages: Python.

- APIs: [Speechmatics Batch API](<https://docs.speechmatics.com/speech-to-text/batch/quickstart>)
- Packages: [Batch](<https://pypi.org/project/speechmatics-batch/>)
- Features: Batch transcription, Speech intelligence, Sentiment analysis, Topic detection, Summarization, Channel diarization
- Integrations: None listed
- Collections: Telephony, Captions and insights
- Estimated time: 20 minutes; last updated: 2025-12-01
- Demos: [Local](<../use-cases/03-call-center-analytics/README.md>): Speechmatics API key; see the walkthrough for runtime and audio requirements.

<a id="example-voice-agent-calendar"></a>
### AI Receptionist

Example ID: `voice-agent-calendar`. [Canonical README](<../use-cases/04-voice-agent-calendar/README.md>).

Build a LiveKit demonstration receptionist with Agent STT, Speechmatics TTS, Twilio SIP, OpenAI tools, and Google Calendar booking.

Implementation: current; kind: code; difficulty: advanced; languages: Python.

- APIs: [Speechmatics Agent STT (Linden 1)](<https://docs.speechmatics.com/speech-to-text/agent-stt>), [Speechmatics Text to Speech API](<https://docs.speechmatics.com/text-to-speech/quickstart>)
- Packages: [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>)
- Features: Realtime transcription, Text to Speech, Speaker diarization, Custom dictionary, Turn detection, Voice agents
- Integrations: LiveKit, Twilio, OpenAI, Google Calendar
- Collections: Telephony, Voice agents
- Estimated time: 30 minutes; last updated: 2025-12-02
- Demos: [Local](<../use-cases/04-voice-agent-calendar/README.md>): Provider credentials and a dedicated test Google Calendar; the local agent can change events.
- Demo access: Use a dedicated test calendar: the agent can create, move, and delete real events.

<a id="example-santa-voice-agent"></a>
### Santa Voice Agent

Example ID: `santa-voice-agent`. [Canonical README](<../use-cases/05-santa-voice-agent/README.md>).

Build a Santa character voice agent with LiveKit, Agent STT, an OpenAI LLM, ElevenLabs TTS, and optional Twilio SIP calls.

Implementation: current; kind: code; difficulty: advanced; languages: Python.

- APIs: [Speechmatics Agent STT (Linden 1)](<https://docs.speechmatics.com/speech-to-text/agent-stt>)
- Packages: [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>)
- Features: Voice agents, Custom dictionary, Realtime transcription, Speaker diarization, Turn detection
- Integrations: LiveKit, Twilio, OpenAI, ElevenLabs
- Collections: Telephony, Voice agents
- Estimated time: 20 minutes; last updated: 2025-12-19
- Demos: [Local](<../use-cases/05-santa-voice-agent/README.md>): Provider accounts and API keys; see the walkthrough for setup requirements.

<a id="example-medical-assistant"></a>
### Medical Assistant

Example ID: `medical-assistant`. [Canonical README](<../use-cases/06-medical-assistant/README.md>).

Build a local Arabic and English clinical transcription dashboard with Enhanced Medical on the preview Realtime endpoint, speaker diarization, and OpenAI extraction and SOAP-note drafting; confirm endpoint and language-pack access.

Implementation: preview; kind: code; difficulty: advanced; languages: Python, JavaScript.

- APIs: [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>)
- Packages: [Realtime](<https://pypi.org/project/speechmatics-rt/>)
- Features: Realtime transcription, Speaker diarization, Custom dictionary, Turn detection
- Integrations: OpenAI
- Collections: Healthcare, Multilingual
- Estimated time: 15 minutes; last updated: 2026-02-10
- Demos: [Local](<../use-cases/06-medical-assistant/README.md>): Local browser dashboard for live transcription, structured extraction, and a scripted consultation demo.
- Demo access: Live transcription requires access to the preview Realtime endpoint and the `ar_en` bilingual language pack. Transcripts are sent to OpenAI; use synthetic or de-identified data. The app has no login. Run Demo uses synthetic transcripts but still requires an OpenAI key and makes billable requests.

<a id="example-medical-microbatching"></a>
### Medical Microbatching

Example ID: `medical-microbatching`. [Canonical README](<../use-cases/07-medical-microbatching/README.md>).

Split microphone audio with Silero VAD and submit concurrent Batch Enhanced jobs, with an optional cross-chunk speaker-identification variant; Medical configuration is optional.

Implementation: current; kind: code; difficulty: intermediate; languages: Python.

- APIs: [Speechmatics Batch API](<https://docs.speechmatics.com/speech-to-text/batch/quickstart>)
- Packages: [Batch](<https://pypi.org/project/speechmatics-batch/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>)
- Features: Batch transcription, Speaker diarization, Speaker identification
- Integrations: None listed
- Collections: Healthcare
- Estimated time: 15 minutes; last updated: 2026-04-29
- Demos: [Local](<../use-cases/07-medical-microbatching/README.md>): Speechmatics API key; see the walkthrough for runtime and audio requirements.

<a id="example-alphanumerics-form-filler"></a>
### Alphanumerics Voice Form Filler

Example ID: `alphanumerics-form-filler`. [Canonical README](<../use-cases/08-alphanumerics-form-filler/README.md>).

Fill a local browser form from spoken names, emails, and numbers using Agent STT, Speechmatics TTS, OpenAI tools, and LiveKit RPC.

Implementation: current; kind: code; difficulty: intermediate; languages: Python, JavaScript.

- APIs: [Speechmatics Agent STT (Linden 1)](<https://docs.speechmatics.com/speech-to-text/agent-stt>), [Speechmatics Text to Speech API](<https://docs.speechmatics.com/text-to-speech/quickstart>)
- Packages: [LiveKit adapter](<https://pypi.org/project/livekit-plugins-speechmatics/>)
- Features: Voice agents, Realtime transcription, Text to Speech, Turn detection
- Integrations: LiveKit, OpenAI
- Collections: Voice agents
- Estimated time: 10 minutes; last updated: 2026-05-06
- Demos: [Local](<../use-cases/08-alphanumerics-form-filler/README.md>): Provider accounts and API keys; see the walkthrough for setup requirements.

<a id="example-flutter-mobile-transcription"></a>
### Flutter Mobile Transcription App

Example ID: `flutter-mobile-transcription`. [Canonical README](<../use-cases/09-flutter-mobile-transcription/README.md>).

Build a Dart mobile client for direct Batch API transcription, speaker and channel labels, speaker identification, captions and speech intelligence, with optional Google Cloud translation.

Implementation: current; kind: code; difficulty: intermediate; languages: Dart.

- APIs: [Speechmatics Batch API](<https://docs.speechmatics.com/speech-to-text/batch/quickstart>)
- Packages: Direct API / configuration
- Features: Batch transcription, Speaker diarization, Speaker identification, Channel diarization, Custom dictionary, Translation, Speech intelligence, Summarization, Topic detection
- Integrations: Flutter, Google Cloud Translation
- Collections: Mobile, Multilingual, Captions and insights
- Estimated time: 20 minutes; last updated: 2026-06-16
- Demos: [Local](<../use-cases/09-flutter-mobile-transcription/README.md>): Flutter toolchain and mobile device/emulator; Speechmatics key; optional Google Cloud Translation key.
- Demonstrated model IDs: melia-1, enhanced, standard
- Demo access: Requires a mobile device/emulator and platform toolchain; iOS needs macOS and Xcode. Add keys in-app; do not distribute builds with embedded keys.

<a id="example-wall-of-voices"></a>
### Wall of Voices

Example ID: `wall-of-voices`. [Canonical README](<../use-cases/10-wall-of-voices/README.md>).

Display multilingual microphone transcripts with Melia 1 and per-word language tags; browser audio uses the preview Realtime host, with a Python token broker and optional SDK CLI.

Implementation: preview; kind: code; difficulty: intermediate; languages: Python, JavaScript.

- APIs: [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>)
- Packages: [Realtime](<https://pypi.org/project/speechmatics-rt/>)
- Features: Realtime transcription
- Integrations: Vercel
- Collections: Multilingual, Captions and insights
- Estimated time: 15 minutes; last updated: 2026-08-18
- Demos: [Recording](<../use-cases/10-wall-of-voices/assets/wall-of-voices.gif>): Recorded multilingual transcript wall and code-switching demonstration.<br>[Local](<../use-cases/10-wall-of-voices/README.md>): Local browser and microphone with a Speechmatics key that can access the preview Realtime endpoint.
- Demonstrated model IDs: melia-1
- Demo access: The GIF is a recording; running locally requires microphone access and a key with access to the preview Realtime endpoint.

<a id="example-oak-consultation-studio"></a>
### Oak Consultation Studio

Example ID: `oak-consultation-studio`. [Canonical README](<../use-cases/11-oak-consultation-studio/README.md>).

Build an Oak 1 multilingual medical consultation interface with direct browser Batch API uploads, synchronized playback, language and speaker/channel labels, and a Python token broker.

Implementation: current; kind: code; difficulty: intermediate; languages: Python, JavaScript.

- APIs: [Speechmatics Batch API](<https://docs.speechmatics.com/speech-to-text/batch/quickstart>)
- Packages: Direct API / configuration
- Features: Batch transcription, Speaker diarization, Channel diarization
- Integrations: Vercel
- Collections: Healthcare, Multilingual
- Estimated time: 20 minutes; last updated: 2026-10-14
- Demos: [Hosted](<https://oak-consultation-studio.vercel.app/>): Hosted browser app with scripted consultations, audio uploads, and recording.<br>[Recording](<../use-cases/11-oak-consultation-studio/assets/oak-consultation-studio.gif>): Recorded interface walkthrough and an example Oak 1 transcription.<br>[Local](<../use-cases/11-oak-consultation-studio/README.md>): Run the browser app and Python token broker locally.
- Demonstrated model IDs: oak-1
- Demo access: Scripted consultations need no key; transcribing your own audio requires a Speechmatics key with Oak 1 Batch access. A key entered in Settings is saved in this browser until cleared and sent to the deployment's `/api/token` endpoint to obtain a 10-minute Batch key.

---

[← Back to Academy](<../README.md>)
