# Migrating from Deepgram to Speechmatics

**Migration** • **Feature Comparison** • **Code Examples**

Switching from Deepgram? This guide shows you equivalent features and code patterns to help you migrate smoothly.

> 💰 **Migration Incentive**: Get **$200 free credit** with code `SWITCH200` when switching from Deepgram!
> [Learn more](https://www.speechmatics.com/how-we-compare/deepgram-alternative)

---

## Table of Contents

- [Feature Mapping](#feature-mapping)
  - [Core Configuration](#core-configuration)
  - [Real-time Streaming & Voice Features](#real-time-streaming--voice-features)
  - [Batch Transcription Features](#batch-transcription-features)
  - [Output Formatting & Filtering](#output-formatting--filtering)
  - [Text-to-Speech (TTS)](#text-to-speech-tts)
- [Why Switch?](#why-switch)
- [Code Migration Examples](#code-migration-examples)
- [Response Structure](#response-structure)
- [Migration Checklist](#migration-checklist)
- [Common Gotchas](#common-gotchas)
- [Need Help?](#need-help)

---

## Feature Mapping

### Core Configuration

| Feature | Deepgram | Speechmatics | Notes |
|---------|----------|--------------|-------|
| **Model Selection** | `model="nova-3"` | `operating_point="enhanced"` | Enhanced for best accuracy, `"standard"` for faster turnaround |
| **Language** | `language="en-US"` | `language="en"` | Speechmatics uses ISO 639-1 codes |
| **Sample Rate** | `sample_rate=16000` | `sample_rate=16000` | Same parameter in AudioFormat |
| **Encoding** | `encoding="linear16"` | `encoding="pcm_s16le"` | Slightly different naming |
| **Channels** | `channels=1` | Via `diarization="channel"` + `AsyncMultiChannelClient` | Speechmatics uses separate streams per channel |
| **API Key** | `DEEPGRAM_API_KEY` | `SPEECHMATICS_API_KEY` | Environment variable naming |
<br/>

<details id="real-time-streaming--voice-features">
<summary><strong style="font-size: 1.25em;">Real-time Streaming & Voice Features</strong></summary>

> **Speechmatics Packages:** 
`speechmatics-rt` for basic real-time streaming, `speechmatics-voice` for voice agent features (turn detection, segments, VAD events). Voice SDK is built on top of RT SDK.

| Feature | Deepgram | Speechmatics | Package | Notes |
|---------|----------|--------------|---------|-------|
| **Interim Results** | `interim_results=True` | `enable_partials=True` | `rt`, `voice` | Partial transcripts while processing |
| **Endpointing** | `endpointing=500` (ms) | `max_delay=0.5` (seconds) | `rt`, `voice` | Max delay before returning results |
| **Max Delay Mode** | Not available | `max_delay_mode="flexible"` or `"fixed"` | `rt`, `voice` | Flexible allows entity completion |
| **Utterance End** | `utterance_end_ms=1000` | `conversation_config=`<br/>`ConversationConfig(end_of_utterance_silence_trigger=1.0)` | `rt`, `voice` | Silence trigger |
| **Force End Utterance** | Not available | `ClientMessageType.FORCE_END_OF_UTTERANCE` | `rt`, `voice` | Manually trigger end of utterance |
| **VAD Events** | `vad_events=True` (Beta) | `AgentServerMessageType.SPEAKER_STARTED`<br/>`AgentServerMessageType.SPEAKER_ENDED` | `voice` | Voice activity detection events |
| **Diarization** | `diarize=True`,<br/> `diarize_version="latest"` | `diarization="speaker"` | `rt`, `voice` | Speaker identification |
| **Speaker Config** | Not available | `speaker_diarization_config=` <br/>  `SpeakerDiarizationConfig(...)` | `rt`, `voice` | Fine-tune diarization |
| **Known Speakers** | Not available | `known_speakers=`<br/>`[SpeakerIdentifier(label, speaker_identifiers)]` | `rt`, `voice` | Pre-register speaker voices |
| **Speaker Focus** | Not available | `SpeakerFocusConfig(focus_speakers, ignore_speakers)` | `voice` | Focus on specific speakers |
| **Multichannel** | `multichannel=True` | `diarization="channel"` or `"channel_and_speaker"` | `rt`, `voice` | Channel-based diarization |
| **Channel Labels** | Not available | `channel_diarization_labels=["agent", "customer"]` | `rt`, `voice` | Label audio channels |
| **Keywords/Keyterms** | `keywords=["term"]`,<br/> `keyterm=["term"]` | `additional_vocab=[{"content": "term"}]` | `rt`, `voice` | Boost specific terms |
| **Translation** | Not available | `translation_config=`<br/>`TranslationConfig(target_languages=["es"]` | `rt` | Real-time translation |
| **Audio Events** | Not available | `audio_events_config=AudioEventsConfig(types=[...])` | `rt` | Detect laughter, applause, etc. |
| **Domain** | Not available | `domain="medical"` | `rt`, `voice` | Domain-optimized language pack |

**Turn Detection (Voice SDK):**
| Feature | Deepgram | Speechmatics | Notes |
|---------|----------|--------------|-------|
| **Fixed Delay** | Via settings | `EndOfUtteranceMode.FIXED` | Basic silence detection |
| **Adaptive Delay** | Not available | `EndOfUtteranceMode.ADAPTIVE` | Content-aware timing |
| **Smart Turn (ML)** | Not available | `EndOfUtteranceMode.SMART_TURN` | ML-based turn detection |
| **External Control** | Not available | `EndOfUtteranceMode.EXTERNAL` + `client.finalize()` | Manual finalization |
| **Silence Trigger** | Via settings | `end_of_utterance_silence_trigger` | Configurable silence duration |
| **Presets** | Not available | `preset="scribe"`, `"low_latency"`, `"conversation_adaptive"` | Ready-to-use configurations |

**Server Message Types:**
| Deepgram Event | Speechmatics Event | Package | Notes |
|----------------|-------------------|---------|-------|
| `EventType.MESSAGE` (is_final=True) | `ServerMessageType.ADD_TRANSCRIPT` | `rt` | Final transcript |
| `EventType.MESSAGE` (is_final=False) | `ServerMessageType.ADD_PARTIAL_TRANSCRIPT` | `rt` | Partial results |
| `EventType.MESSAGE` (UtteranceEnd) | `ServerMessageType.END_OF_UTTERANCE` | `rt` | End of utterance |
| `EventType.MESSAGE` (SpeechStarted) | `AgentServerMessageType.SPEAKER_STARTED` | `voice` | Speech detected |
| `EventType.MESSAGE` (Metadata) | `ServerMessageType.RECOGNITION_STARTED` | `rt`, `voice` | Session metadata |
| Not available | `AgentServerMessageType.SPEAKER_ENDED` | `voice` | Speech ended |
| Not available | `AgentServerMessageType.ADD_SEGMENT` | `voice` | Final segment |
| Not available | `AgentServerMessageType.ADD_PARTIAL_SEGMENT` | `voice` | Partial segment |
| Not available | `AgentServerMessageType.START_OF_TURN` | `voice` | Turn started |
| Not available | `AgentServerMessageType.END_OF_TURN` | `voice` | Turn completed |
| Not available | `AgentServerMessageType.END_OF_TURN_PREDICTION` | `voice` | Turn prediction timing |
| Not available | `ServerMessageType.ADD_TRANSLATION` | `rt` | Translation result |
| Not available | `ServerMessageType.AUDIO_EVENT_STARTED` / `ENDED` | `rt` | Audio events |
| Not available | `ServerMessageType.SPEAKERS_RESULT` | `rt` | Speaker identification |

**Usage - Basic RT Streaming:**
```python
from speechmatics.rt import AsyncClient, ServerMessageType, TranscriptionConfig, AudioFormat, AudioEncoding

async with AsyncClient(api_key="YOUR_KEY") as client:
    @client.on(ServerMessageType.ADD_TRANSCRIPT)
    def on_transcript(message):
        print(message['metadata']['transcript'])

    await client.transcribe(
        audio_file,
        transcription_config=TranscriptionConfig(language="en", diarization="speaker"),
        audio_format=AudioFormat(encoding=AudioEncoding.PCM_S16LE, sample_rate=16000)
    )
```

**Usage - Voice SDK (Turn Detection):**
```python
from speechmatics.voice import VoiceAgentClient, VoiceAgentConfig, EndOfUtteranceMode, AgentServerMessageType

config = VoiceAgentConfig(
    language="en",
    enable_diarization=True,
    end_of_utterance_mode=EndOfUtteranceMode.ADAPTIVE,
    end_of_utterance_silence_trigger=0.5
)

async with VoiceAgentClient(api_key="YOUR_KEY", config=config) as client:
    @client.on(AgentServerMessageType.ADD_SEGMENT)
    def on_segment(message):
        for segment in message['segments']:
            print(f"[{segment['speaker_id']}]: {segment['text']}")

    @client.on(AgentServerMessageType.END_OF_TURN)
    def on_turn_end(message):
        print("User finished speaking - ready for response")

    await client.send_audio(audio_chunk)
```

</details>

<br/>

<details id="batch-transcription-features">
<summary><strong style="font-size: 1.25em;">Batch Transcription Features</strong></summary>

> **Speechmatics Package:** `speechmatics-batch`

| Feature | Deepgram | Speechmatics | Package | Notes |
|---------|----------|--------------|---------|-------|
| **Diarization** | `diarize=True`, `diarize_version="latest"` | `diarization="speaker"` | `batch` | Speaker identification |
| **Multichannel** | `multichannel=True` | `diarization="channel"` or `"channel_and_speaker"` | `batch` | Channel-based diarization |
| **Sentiment** | `sentiment=True` | `sentiment_analysis_config=SentimentAnalysisConfig()` | `batch` | Sentiment analysis |
| **Topic Detection** | `topics=True` | `topic_detection_config=TopicDetectionConfig(topics=[...])` | `batch` | Automatic topic extraction |
| **Summarization** | `summarize=True` | `summarization_config=`<br/>`SummarizationConfig(content_type, summary_length, summary_type)` | `batch` | AI-powered summaries |
| **Intent Recognition** | `intents=True` | Not available | - | Detect user intents |
| **Entity Detection** | `detect_entities=True` | `enable_entities=True` | `batch` | Detect named entities |
| **Utterances** | `utterances=True`, `utt_split=0.8` | Not available | - | Split into utterances |
| **Paragraphs** | `paragraphs=True` | Not available | - | Paragraph segmentation |
| **Dictation** | `dictation=True` | Not available | - | Dictation mode formatting |
| **Measurements** | `measurements=True` | `enable_entities=True` | `batch` | Format measurements (e.g., "10 km/s") |
| **Auto Chapters** | Not available | `auto_chapters_config=AutoChaptersConfig()` | `batch` | Automatic chapter generation |
| **Audio Events** | Not available | `audio_events_config=AudioEventsConfig(types=[...])` | `batch` | Detect laughter, applause, etc. |
| **Translation** | Not available | `translation_config=TranslationConfig(target_languages=["es", "fr"])` | `batch` | Translate transcript |
| **Language ID** | `detect_language=True` | `language_identification_config=`<br/>`LanguageIdentificationConfig(expected_languages=[...])` | `batch` | Identify spoken language |
| **Domain** | Not available | `domain="medical"` | `batch` | Domain-optimized language pack |
| **Output Locale** | Not available | `output_locale="en-US"` | `batch` | RFC-5646 locale for output |
| **Output Format** | `?format=srt` | `get_transcript(job_id, format_type=FormatType.SRT)` | `batch` | JSON, TXT, SRT formats |
| **Webhooks** | `callback="url"` | `notification_config=`<br/>`[NotificationConfig(url, contents, method)]` | `batch` | Job completion notifications |
| **Job Tracking** | `tag=["label"]` | `tracking=TrackingConfig(title, reference, tags)` | `batch` | Custom job metadata |
| **Fetch from URL** | `url=...` | `fetch_data=FetchData(url, auth_headers)` | `batch` | Transcribe from URL |

**Usage:**
```python
from speechmatics.batch import AsyncClient, JobConfig, JobType, TranscriptionConfig, SummarizationConfig

async with AsyncClient(api_key="YOUR_KEY") as client:
    config = JobConfig(
        type=JobType.TRANSCRIPTION,
        transcription_config=TranscriptionConfig(
            language="en",
            diarization="speaker",
            enable_entities=True
        ),
        summarization_config=SummarizationConfig(
            content_type="conversational",
            summary_length="brief"
        )
    )

    result = await client.transcribe("audio.wav", config=config)
    print(result.transcript_text)
    print(result.summary)
```

</details>

<br/>

<details id="output-formatting--filtering">
<summary><strong style="font-size: 1.25em;">Output Formatting & Filtering</strong></summary>

> **Speechmatics Packages:** `speechmatics-batch`, `speechmatics-rt` - formatting features available in both batch and real-time.
>
> **Note:** Parameters like `punctuation_overrides`, `transcript_filtering_config`, and `audio_filtering_config` accept `dict` objects. The SDK passes these directly to the API - refer to [API documentation](https://docs.speechmatics.com/speech-to-text/formatting#punctuation) for valid keys.

| Feature | Deepgram | Speechmatics | Package | Notes |
|---------|----------|--------------|---------|-------|
| **Smart Formatting** | `smart_format=True` | `enable_entities=True` | `batch`, `rt` | Dates, numbers, currencies, emails, etc. |
| **Punctuation** | `punctuate=True` | Enabled by default | `batch`, `rt` | Automatic punctuation |
| **Punctuation Sensitivity** | Not available | `punctuation_overrides={"sensitivity": 0.4}` | `batch`, `rt` | Control punctuation frequency (0-1) |
| **Punctuation Marks** | Not available | `punctuation_overrides={"permitted_marks": [".", ","]}` | `batch`, `rt` | Limit allowed punctuation marks |
| **Output Locale** | Not available | `output_locale="en-GB"` | `batch`, `rt` | Regional spelling (en-GB, en-US, en-AU) |
| **Profanity** | `profanity_filter=True` | Auto-tagged for en, it, es | `batch`, `rt` | Deepgram removes, Speechmatics tags as `$PROFANITY` |
| **Disfluencies** | `filler_words=True` (include) | `transcript_filtering_config=`<br/>`{"remove_disfluencies": True}` | `batch`, `rt` | Deepgram includes by opt-in; Speechmatics auto-tags, optionally removes (EN only) |
| **Word Replacement** | `replace=["old:new"]` | `transcript_filtering_config={"replacements": [{"from": "old", "to": "new"}]}` | `batch`, `rt` | Find/replace with regex support |
| **Redaction** | `redact=["pci", "ssn", "numbers"]` | `transcript_filtering_config={"replacements": [...]}` | `batch`, `rt` | Use replacements to redact sensitive data |
| **Audio Filtering** | Not available | `audio_filtering_config={"volume_threshold": 3.4}` | `batch`, `rt` | Remove background speech by volume (0-100) |
| **Custom Vocab** | `keywords=["term"]`, `keyterm=["term"]` | `additional_vocab=[{"content": "term", "sounds_like": [...]}]` | `batch`, `rt` | Phonetic hints available |

**Usage (Batch):**
```python
from speechmatics.batch import AsyncClient, TranscriptionConfig

config = TranscriptionConfig(
    language="en",
    enable_entities=True,
    output_locale="en-GB",
    punctuation_overrides={"sensitivity": 0.4},
    transcript_filtering_config={"remove_disfluencies": True},
    additional_vocab=[
        {"content": "acetaminophen", "sounds_like": ["ah see tah min oh fen"]},
        {"content": "myocardial infarction", "sounds_like": ["my oh car dee al in fark shun"]}
    ]
)

async with AsyncClient(api_key="YOUR_KEY") as client:
    result = await client.transcribe("audio.wav", transcription_config=config)
    print(result.transcript_text)
```

**Usage (Real-time):**
```python
from speechmatics.rt import AsyncClient, TranscriptionConfig, AudioFormat, AudioEncoding

config = TranscriptionConfig(
    language="en",
    enable_entities=True,
    punctuation_overrides={"sensitivity": 0.4},
    transcript_filtering_config={"remove_disfluencies": True}
)

async with AsyncClient(api_key="YOUR_KEY") as client:
    await client.transcribe(
        audio_file,
        transcription_config=config,
        audio_format=AudioFormat(encoding=AudioEncoding.PCM_S16LE, sample_rate=16000)
    )
```

</details>

<br/>

<details id="text-to-speech-tts">
<summary><strong style="font-size: 1.25em;">Text-to-Speech (TTS)</strong></summary>

> **Speechmatics Package:** `speechmatics-tts`

| Feature | Deepgram | Speechmatics | Package | Notes |
|---------|----------|--------------|---------|-------|
| **API Style** | REST + WebSocket | REST | `tts` | Both support audio output |
| **Voices (EN)** | Multiple Voices| 4 curated voices (sarah, theo, megan, jack) | `tts` | Different voice selection approaches |
| **Output Formats** | Multiple encodings | `wav_16000`, `pcm_16000` | `tts` | Standard formats supported |
| **Sample Rate** | Configurable | 16kHz (optimized for speech) | `tts` | Speech-optimized defaults |
| **Bit Rate** | Configurable | Optimized defaults | `tts` | Quality settings |
| **Streaming TTS** | WebSocket | HTTP chunked streaming | `tts` | Both support streaming audio output |
| **Callback** | `callback="url"` | Not available | - | Webhook support |
| **Model Opt-out** | `mip_opt_out=True` | Options available post-preview | `tts` | Privacy controls |
| **Request Tags** | `tag=["label"]` | Via API headers | `tts` | Request identification |

**Usage:**
```python
# Deepgram TTS
from deepgram import DeepgramClient
client = DeepgramClient(api_key="YOUR_KEY")
with client.speak.v1.audio.generate(
    text="Hello world",
    model="aura-asteria-en",
    encoding="linear16",
    sample_rate=16000
) as response:
    audio_data = response.data

# Speechmatics TTS
from speechmatics.tts import AsyncClient, Voice, OutputFormat
async with AsyncClient(api_key="YOUR_KEY") as client:
    response = await client.generate(
        text="Hello world",
        voice=Voice.SARAH,
        output_format=OutputFormat.WAV_16000
    )
    audio_data = await response.read()
```

</details>

<br/>

---

## Why Switch?

### Superior Accuracy

| Metric | Speechmatics | Deepgram |
|--------|--------------|----------|
| **Word Error Rate (WER)** | 4.11% | 4.96% |
| **Medical Keyword Recall** | 96% | - |
| **Noisy Environments** | Excellent | Standard |
| **Accent Recognition** | Market-leading | Standard |
| **Multi-speaker Accuracy** | Market-leading | Standard |

### More Languages

| Capability | Speechmatics | Deepgram |
|------------|--------------|----------|
| **Languages Supported** | 55+ | 30+ |
| **Accuracy Consistency** | Industry-leading across all | Varies by language |
| **Bilingual Packs** | Mandarin, Tamil, Malay, Tagalog + English | 10 European languages only |
| **Real-time Translation** | 30+ languages | ❌ |
| **Auto Language Detection** | ✅ | ✅ |



### Advanced Features

| Feature | Speechmatics | Deepgram |
|---------|--------------|----------|
| **Domain-Specific Models** | Medical, finance, and more | Limited |
| **Custom Dictionary Size** | 1,000 words included | 100 words |
| **Speaker Diarization** | Included | Extra charge |
| **Speaker Identification** | Known speaker pre-registration | ❌ |
| **Speaker Focus** | Focus/ignore specific speakers | ❌ |

### Flexible Deployment Options

| Deployment | Speechmatics | Deepgram |
|------------|--------------|----------|
| **SaaS/Cloud** | ✅ | ✅ |
| **On-Premise** | ✅ | Limited |
| **On-Device** | ✅ | ❌ |
| **Air-Gapped** | ✅ | ❌ |

### Enterprise-Grade Security
- ISO 27001 certified
- GDPR compliant
- HIPAA compliant

### Industries & Use Cases

Speechmatics excels in:
- **Healthcare** - 96% medical keyword recall with medical domain model
- **Contact Centers** - Speaker ID, focus, and multi-speaker accuracy
- **Media & Captioning** - High accuracy in noisy environments
- **Finance** - Enterprise security with air-gapped deployment
- **Education** - 55+ languages with consistent accuracy

---

## Code Migration Examples

### Batch Transcription

**Deepgram:**
```python
from deepgram import DeepgramClient, PrerecordedOptions

client = DeepgramClient(api_key="YOUR_API_KEY")

with open("audio.wav", "rb") as audio_file:
    response = client.listen.prerecorded.transcribe_file(
        audio_file,
        PrerecordedOptions(
            model="nova-3",
            smart_format=True,
            diarize=True
        )
    )

transcript = response.results.channels[0].alternatives[0].transcript
```

**Speechmatics:**
```python
import asyncio
from speechmatics.batch import AsyncClient, TranscriptionConfig

async def transcribe():
    async with AsyncClient(api_key="YOUR_API_KEY") as client:
        config = TranscriptionConfig(
            language="en",
            operating_point="enhanced",
            diarization="speaker",
            enable_entities=True
        )

        with open("audio.wav", "rb") as audio_file:
            result = await client.transcribe(audio_file, transcription_config=config)
            transcript = result.transcript_text

asyncio.run(transcribe())
```

**What Changed:**
- Configuration is now in `TranscriptionConfig` object
- Simpler result access with `result.transcript_text`
- Async-first for better performance and resource management

---

### Real-time Streaming

**Deepgram:**
```python
from deepgram import DeepgramClient, LiveOptions
from deepgram.core.events import EventType

client = DeepgramClient(api_key="YOUR_API_KEY")
connection = client.listen.live.v("1")

def on_message(self, result, **kwargs):
    # Check if this is a final transcript result
    if hasattr(result, 'is_final') and result.is_final:
        sentence = result.channel.alternatives[0].transcript
        if len(sentence) > 0:
            print(sentence)

connection.on(EventType.MESSAGE, on_message)
connection.start(LiveOptions(model="nova-3", language="en-US", diarize=True))
connection.send(audio_chunk)
connection.finish()
```

**Speechmatics:**
```python
from speechmatics.rt import AsyncClient, ServerMessageType, TranscriptResult, AudioFormat, AudioEncoding, TranscriptionConfig

async def stream_audio():
    async with AsyncClient(api_key="YOUR_API_KEY") as client:

        @client.on(ServerMessageType.ADD_TRANSCRIPT)
        def on_transcript(message):
            result = TranscriptResult.from_message(message)
            print(result.metadata.transcript)

        @client.on(ServerMessageType.ADD_PARTIAL_TRANSCRIPT)
        def on_partial(message):
            result = TranscriptResult.from_message(message)
            print(f"Partial: {result.metadata.transcript}")

        with open("audio.wav", "rb") as audio_file:
            await client.transcribe(
                audio_file,
                transcription_config=TranscriptionConfig(
                    language="en",
                    operating_point="enhanced",
                    diarization="speaker",
                    enable_partials=True
                ),
                audio_format=AudioFormat(
                    encoding=AudioEncoding.PCM_S16LE,
                    sample_rate=16000
                )
            )

asyncio.run(stream_audio())
```

**What Changed:**
- Event-driven architecture with decorators
- Structured message types via `ServerMessageType` enum
- Better type safety with `TranscriptResult` objects
- Separate events for final and partial transcripts

---

### Speaker Diarization

**Deepgram:**
```python
options = PrerecordedOptions(
    model="nova-3",
    diarize=True,
    utterances=True
)

response = client.listen.prerecorded.transcribe_file(audio_file, options)

for word in response.results.channels[0].alternatives[0].words:
    print(f"Speaker {word.speaker}: {word.word}")
```

**Speechmatics:**
```python
config = TranscriptionConfig(
    language="en",
    diarization="speaker",
    speaker_diarization_config={
        "max_speakers": 4  # Optional: limit speaker count
    }
)

result = await client.transcribe(audio_file, transcription_config=config)

for item in result.results:
    if item.type == "word":
        print(f"Speaker {item.attaches_to}: {item.alternatives[0].content}")
```

**Advantages:**
- Higher accuracy in multi-speaker scenarios
- Automatic speaker count detection
- Optional `max_speakers` constraint for optimization

---

### Custom Vocabulary

**Deepgram:**
```python
options = PrerecordedOptions(
    model="nova-3",
    keywords=["Speechmatics", "DeepSeek", "TechTerm:2"]  # keyword:boost
)
```

**Speechmatics:**
```python
config = TranscriptionConfig(
    language="en",
    additional_vocab=[
        {"content": "Speechmatics", "sounds_like": ["speech matics"]},
        {"content": "DeepSeek"},
        {"content": "TechTerm", "sounds_like": ["tek term", "tech term"]},
    ]
)
```

**Features:**
- Phonetic alternatives with `sounds_like` for pronunciation variants
- 1,000 words included (vs Deepgram's 100)
- Better recognition of domain-specific terms

---

### Content Filtering

**Deepgram:**
```python
options = PrerecordedOptions(
    model="nova-3",
    profanity_filter=True,  # Removes profanities
    filler_words=True,       # Removes filler words
    replace=["SSN:REDACTED", "password:REDACTED"]
)
```

**Speechmatics:**
```python
# Profanity tagging is automatic for en, it, es
config = {
    "language": "en",
    "transcript_filtering_config": {
        "remove_disfluencies": True,  # Remove "um", "uh", etc.
        "replacements": [
            {"from": "SSN", "to": "REDACTED"},
            {"from": "password", "to": "REDACTED"}
        ]
    }
}
```

**Key Differences:**
- **Profanity**: Deepgram removes, Speechmatics auto-tags (appears as `$PROFANITY`)
- **Disfluencies**: Both support removal of filler words
- **Redaction**: Both support word replacement

---

## Response Structure

### Deepgram Response

```json
{
  "metadata": {...},
  "results": {
    "channels": [{
      "alternatives": [{
        "transcript": "Full transcript text",
        "confidence": 0.98,
        "words": [
          {
            "word": "hello",
            "start": 0.0,
            "end": 0.5,
            "confidence": 0.99,
            "speaker": 0
          }
        ]
      }]
    }]
  }
}
```

### Speechmatics Response

```json
{
  "transcript_text": "Full transcript text",
  "results": [
    {
      "type": "word",
      "start_time": 0.0,
      "end_time": 0.5,
      "alternatives": [
        {
          "content": "hello",
          "confidence": 0.99
        }
      ],
      "attaches_to": "speaker_1"
    }
  ],
  "metadata": {...}
}
```

**Key Differences:**
- Speechmatics provides `transcript_text` at the top level for quick access
- Results are flat arrays instead of nested channels
- Speaker is referenced via `attaches_to` field

---

## Features Unique to Each Platform

### Deepgram Only
- Text-to-text search/keyword boosting

### Speechmatics Only
- Phonetic hints (`sounds_like` in `additional_vocab`)
- Real-time translation (`TranslationConfig`)
- Force end of utterance (`ClientMessageType.FORCE_END_OF_UTTERANCE`)
- Turn detection for voice agents (Voice SDK)
- Comprehensive audio intelligence (sentiment + topics + summary together)
- More granular speaker diarization controls (`SpeakerDiarizationConfig`)
- Known speaker pre-registration (`speaker_diarization_config.speakers`)
- Voice SDK for conversational AI
- Auto-disfluency tagging (automatic for English)
- On-device and air-gapped deployment

---

## Migration Checklist

### Pre-Migration
-  Review feature mapping table above
-  Identify features you're currently using in Deepgram
-  Check language support for your use case
-  Sign up at [portal.speechmatics.com](https://portal.speechmatics.com)
-  Get API key from portal
-  Apply code `SWITCH200` for $200 free credit

### Code Migration
-  Install SDK: `pip install speechmatics-batch speechmatics-rt`
-  Replace `DEEPGRAM_API_KEY` with `SPEECHMATICS_API_KEY`
-  Update imports from `deepgram` to `speechmatics.batch` or `speechmatics.rt`
-  Convert `PrerecordedOptions`/`LiveOptions` to `TranscriptionConfig`
-  Update event handlers (replace `EventType` with `ServerMessageType`)
-  Adjust result parsing (use `result.transcript_text`)

### Testing
-  Test with same audio files used in Deepgram
-  Verify accuracy meets or exceeds previous results
-  Test error handling and retry logic
-  Performance testing for streaming use cases

### Deployment
-  Update production environment variables
-  Deploy to staging environment
-  Monitor transcription quality
-  Verify usage metrics in portal

---

## Common Gotchas

### 1. Async/Await Pattern
Speechmatics SDK is async-first:
```python
import asyncio

async def main():
    async with AsyncClient(api_key="YOUR_API_KEY") as client:
        result = await client.transcribe(audio_file, transcription_config=config)
        print(result.transcript_text)

asyncio.run(main())
```

### 2. Response Structure
```python
# Deepgram
text = response.results.channels[0].alternatives[0].transcript

# Speechmatics - simpler
text = result.transcript_text
```

### 3. Event Types (Streaming)
```python
# Deepgram - uses generic MESSAGE event, check is_final for final vs partial
connection.on(EventType.MESSAGE, on_message)

# Speechmatics - separate events for final and partial
@client.on(ServerMessageType.ADD_TRANSCRIPT)
def on_transcript(message):
    ...
```

### 4. Audio Format
```python
# Deepgram - in options
options = LiveOptions(encoding="linear16", sample_rate=16000)

# Speechmatics - separate object
audio_format = AudioFormat(encoding=AudioEncoding.PCM_S16LE, sample_rate=16000)
```

---

## Complete Before/After Example

### Before (Deepgram)

```python
from deepgram import DeepgramClient, PrerecordedOptions
import os

def transcribe_audio():
    client = DeepgramClient(api_key=os.getenv("DEEPGRAM_API_KEY"))

    with open("audio.wav", "rb") as audio_file:
        response = client.listen.prerecorded.transcribe_file(
            audio_file,
            PrerecordedOptions(
                model="nova-3",
                smart_format=True,
                diarize=True,
                language="en-US",
                keywords=["ProductName", "TechTerm"]
            )
        )

    return response.results.channels[0].alternatives[0].transcript

print(transcribe_audio())
```

### After (Speechmatics)

```python
import asyncio
import os
from speechmatics.batch import AsyncClient, TranscriptionConfig

async def transcribe_audio():
    async with AsyncClient(api_key=os.getenv("SPEECHMATICS_API_KEY")) as client:
        config = TranscriptionConfig(
            language="en",
            operating_point="enhanced",
            diarization="speaker",
            enable_entities=True,
            additional_vocab=[
                {"content": "ProductName"},
                {"content": "TechTerm"}
            ]
        )

        with open("audio.wav", "rb") as audio_file:
            result = await client.transcribe(audio_file, transcription_config=config)
            return result.transcript_text

print(asyncio.run(transcribe_audio()))
```

**See complete working examples in:**
- [Batch Transcription](./examples/batch/)
- [Real-time Streaming](./examples/streaming/)
- [Speaker Diarization](./examples/diarization/)

---

## Need Help?

### Migration Support
- Email: devrel@speechmatics.com
- [SDK Documentation](https://docs.speechmatics.com)
- [Why Switch from Deepgram](https://www.speechmatics.com/how-we-compare/deepgram-alternative) - Official comparison

### Related Academy Examples
- [Hello World](../../../basics/01-hello-world/) - Start here
- [Batch vs Real-time](../../../basics/02-batch-vs-realtime/) - Understand API modes
- [Configuration Guide](../../../basics/03-configuration-guide/) - All config options

### Official Documentation
- [Batch API Reference](https://docs.speechmatics.com/api-ref/batch/create-a-new-job)
- [Real-time API Reference](https://docs.speechmatics.com/rt-api-ref)
- [Python SDK GitHub](https://github.com/speechmatics/speechmatics-python-sdk)

---

## Feedback

Help us improve this migration guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/speechmatics/speechmatics-academy/discussions)

---

**Time to Migrate**: 30-60 minutes
**Difficulty**: Intermediate
**Languages**: Python

[Back to Migration Guides](../README.md) | [Back to Academy Home](../../../README.md)
