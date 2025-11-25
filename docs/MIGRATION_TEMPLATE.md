# Migration Guide Template

Use this template to create migration guides for users switching from other speech-to-text providers to Speechmatics.

---

# Migrating from [Provider Name] to Speechmatics

**Quick Migration** • **Feature Comparison** • **Code Examples**

Switching from [Provider Name]? This guide shows you equivalent features and code patterns to help you migrate smoothly.

## Quick Feature Mapping

| [Provider] Feature | Speechmatics Equivalent | Notes |
|-------------------|------------------------|-------|
| `feature_name` | `speechmatics_equivalent` | Description of mapping |
| `another_feature` | `another_equivalent` | Additional context |
| `premium_feature` | `standard_feature` | Included in standard pricing |

**Key Differences:**
- **What's Better** - Highlight Speechmatics advantages
- **What's Different** - Call out important differences
- **What's the Same** - Reassure users about familiar features

---

## Side-by-Side Comparison

### Batch/File Transcription

**[Provider Name]:**
```python
# Their SDK code example
from their_sdk import Client

client = Client(api_key="YOUR_API_KEY")
response = client.transcribe(
    audio_file,
    option1=value1,
    option2=value2
)
transcript = response.get_transcript()
```

**Speechmatics:**
```python
# Equivalent Speechmatics code
from speechmatics.batch import AsyncClient, TranscriptionConfig

async with AsyncClient(api_key="YOUR_API_KEY") as client:
    result = await client.transcribe(
        audio_file,
        transcription_config=TranscriptionConfig(
            language="en",
            # Equivalent configuration
        )
    )
    transcript = result.transcript_text
```

**What Changed:**
- Configuration is now in `TranscriptionConfig` object
- Simpler result access with `result.transcript_text`
- Async-first for better performance

---

### Real-time Streaming

**[Provider Name]:**
```python
# Their streaming implementation
from their_sdk import StreamingClient

def on_transcript(data):
    print(data.get("transcript"))

client = StreamingClient(api_key="YOUR_API_KEY")
client.on("transcript", on_transcript)
client.connect()
client.send_audio(audio_chunk)
```

**Speechmatics:**
```python
# Equivalent Speechmatics streaming
from speechmatics.rt import AsyncClient, ServerMessageType, TranscriptResult

async with AsyncClient(api_key="YOUR_API_KEY") as client:
    @client.on(ServerMessageType.ADD_TRANSCRIPT)
    def on_transcript(message):
        result = TranscriptResult.from_message(message)
        print(result.metadata.transcript)

    await client.start_session(
        transcription_config=TranscriptionConfig(language="en"),
        audio_format=AudioFormat(...)
    )

    await client.send_audio(audio_chunk)
```

**What Changed:**
- Event-driven architecture with decorators
- Structured message types
- Better type safety with result objects

---

### Speaker Diarization

**[Provider Name]:**
```python
# Their diarization approach
```

**Speechmatics:**
```python
# Speechmatics diarization
config = TranscriptionConfig(
    language="en",
    diarization="speaker",
    speaker_diarization_config={
        "max_speakers": 4
    }
)
```

**Advantages:**
- Higher accuracy in multi-speaker scenarios
- Automatic speaker count detection
- Lower word error rates per speaker

---

### Custom Vocabulary

**[Provider Name]:**
```python
# Their vocabulary implementation
```

**Speechmatics:**
```python
config = TranscriptionConfig(
    language="en",
    additional_vocab=[
        {"content": "Speechmatics", "sounds_like": ["speech matics"]},
        {"content": "ProductName"},
        {"content": "TechTerm", "sounds_like": ["tech term", "tek term"]},
    ]
)
```

**Features:**
- Phonetic alternatives with `sounds_like`
- No limit on vocabulary size
- Better recognition of domain-specific terms

---

## What You Gain by Switching

### **Superior Accuracy**
- Industry-leading word error rates
- Better performance on accented speech
- Improved technical terminology recognition

### **More Languages**
- 50+ languages supported
- Auto language detection
- Real-time translation

### **Audio Intelligence**
- Built-in sentiment analysis
- Automatic topic detection
- AI-powered summarization
- Entity recognition (dates, numbers, etc.)

### **Flexible Pricing**
- Pay-as-you-go with no commitments
- Volume discounts available
- No hidden fees or premium tiers for features

### **Better Developer Experience**
- Modern async/await Python SDK
- Clear documentation with examples
- Responsive support team
- Active community

---

## Migration Checklist

Use this checklist to ensure a smooth migration:

### **Pre-Migration**
- [ ] Review feature mapping table above
- [ ] Identify features you're currently using
- [ ] Check language support for your use case
- [ ] Sign up for Speechmatics account
- [ ] Get API key from [portal.speechmatics.com](https://portal.speechmatics.com/)

### **Code Migration**
- [ ] Install Speechmatics SDK: `pip install speechmatics-batch speechmatics-rt`
- [ ] Replace API key in environment variables
- [ ] Update import statements
- [ ] Convert configuration to Speechmatics format
- [ ] Update event handlers (for streaming)
- [ ] Adjust result parsing logic

### **Testing**
- [ ] Test with sample audio files
- [ ] Verify accuracy meets requirements
- [ ] Test error handling
- [ ] Validate output format
- [ ] Performance testing (if applicable)

### **Deployment**
- [ ] Update production environment variables
- [ ] Deploy updated code
- [ ] Monitor initial usage
- [ ] Verify billing/usage metrics

---

## Common Gotchas

### **1. Configuration Structure**
**Issue:** Configuration is structured differently

**Solution:**
```python
# [Provider] - flat configuration
client.transcribe(file, language="en", diarization=True, custom_vocab=[...])

# Speechmatics - structured configuration
config = TranscriptionConfig(
    language="en",
    diarization="speaker",
    additional_vocab=[...]
)
result = await client.transcribe(file, transcription_config=config)
```

### **2. Response Structure**
**Issue:** Result object structure is different

**Solution:**
```python
# [Provider]
text = response["results"]["transcript"]

# Speechmatics
text = result.transcript_text  # Simple property access
```

### **3. Async/Await Pattern**
**Issue:** Speechmatics SDK is async-first

**Solution:**
```python
import asyncio

async def main():
    async with AsyncClient(api_key) as client:
        result = await client.transcribe(audio_file)
        print(result.transcript_text)

if __name__ == "__main__":
    asyncio.run(main())
```

### **4. Event Types (Streaming)**
**Issue:** Different event naming conventions

**Solution:** See the streaming comparison table above for event mappings

---

## Complete Example

### **Before ([Provider Name])**

```python
# Complete working example with [Provider]
from their_sdk import Client

def transcribe_audio():
    client = Client(api_key="YOUR_API_KEY")

    response = client.transcribe(
        "audio.wav",
        language="en",
        diarization=True,
        custom_vocabulary=["ProductName", "TechTerm"]
    )

    transcript = response.get_transcript()
    speakers = response.get_speakers()

    return {
        "transcript": transcript,
        "speakers": speakers
    }

result = transcribe_audio()
print(result["transcript"])
```

### **After (Speechmatics)**

```python
# Migrated Speechmatics example
import asyncio
from speechmatics.batch import AsyncClient, TranscriptionConfig

async def transcribe_audio():
    async with AsyncClient(api_key="YOUR_API_KEY") as client:

        config = TranscriptionConfig(
            language="en",
            diarization="speaker",
            additional_vocab=[
                {"content": "ProductName"},
                {"content": "TechTerm"}
            ]
        )

        result = await client.transcribe(
            "audio.wav",
            transcription_config=config
        )

        return {
            "transcript": result.transcript_text,
            "speakers": [s for s in result.results if s.type == "word"]
        }

result = asyncio.run(transcribe_audio())
print(result["transcript"])
```

**See complete working examples in:**
- [Batch Transcription](./examples/batch/)
- [Real-time Streaming](./examples/streaming/)
- [Speaker Diarization](./examples/diarization/)

---

## Need Help?

### **Migration Support**
- [Community Discord](https://discord.gg/speechmatics)
- Email: academy@speechmatics.com
- [SDK Documentation](https://docs.speechmatics.com)

### **Related Academy Examples**
- [Hello World](../../basics/01-hello-world/) - Start here
- [Batch vs Real-time](../../basics/02-batch-vs-realtime/) - Understand API modes
- [Configuration Guide](../../basics/03-configuration-guide/) - All config options
- [Audio Intelligence](../../basics/04-audio-intelligence/) - Advanced features

### **Official Documentation**
- [Batch API Reference](https://docs.speechmatics.com/batch-api-ref)
- [Real-time API Reference](https://docs.speechmatics.com/rt-api-ref)
- [Python SDK GitHub](https://github.com/speechmatics/speechmatics-python-sdk)

---

## Feedback

Help us improve this migration guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/speechmatics/speechmatics-academy/discussions)
- Migrated successfully? Share your experience!

---

**Time to Migrate**: 30-60 minutes
**Difficulty**: Intermediate
**Languages**: Python

[Back to Migration Guides](../README.md) | [Back to Academy Home](../../README.md)
