# Multilingual & Translation

**Real-time transcription and translation using microphone input - speak in English and see live translations in multiple languages.**

Demonstrate multilingual capabilities by transcribing live audio and translating it to Spanish and Russian in real-time.

## What You'll Learn

- How to configure real-time transcription with translation
- Working with multiple target languages simultaneously
- Handling real-time translation events
- Understanding translation timing vs transcription timing
- Managing microphone input for live processing

## Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.8+**
- **Microphone**: Built-in or external microphone
- **PyAudio**: For microphone access (installation instructions below)

## Quick Start

### Python

**Step 1: Create and activate a virtual environment**

**On Windows:**
```bash
cd python
python -m venv venv
venv\Scripts\activate
```

**On Mac/Linux:**
```bash
cd python
python3 -m venv venv
source venv/bin/activate
```

**Step 2: Install dependencies**

```bash
pip install -r requirements.txt
```

> [!NOTE]
> If PyAudio installation fails, see [PyAudio Installation Issues](#pyaudio-installation-issues) in Troubleshooting.

**Step 3: Configure API key**

```bash
cp ../.env.example .env
# Edit .env and add your SPEECHMATICS_API_KEY
```

**Step 4: Run the example**

```bash
python main.py
```

Speak into your microphone and watch the real-time transcription and translations appear!

## How It Works

> [!NOTE]
> This example demonstrates real-time translation by:
>
> 1. **Capturing microphone input** - Uses PyAudio to stream audio from your microphone
> 2. **Configuring source language** - Sets English as the transcription language
> 3. **Enabling translation** - Configures Spanish and Russian as target languages
> 4. **Streaming to Speechmatics** - Sends audio chunks via WebSocket
> 5. **Receiving real-time results** - Processes both transcription and translation events
> 6. **Displaying results** - Shows English transcription and translations as they arrive

### Code Walkthrough

**1. Audio and Transcription Configuration**

```python
audio_format = AudioFormat(
    encoding=AudioEncoding.PCM_S16LE,
    chunk_size=4096,
    sample_rate=16000,
)

transcription_config = TranscriptionConfig(
    language="en",  # Source language: English
    enable_partials=True,  # Show partial results
)

translation_config = TranslationConfig(
    target_languages=["es", "ru"],  # Spanish and Russian
    enable_partials=True,
)
```

**2. Event Handlers**

The example registers four event handlers:

**English Transcription (Final):**
```python
@client.on(ServerMessageType.ADD_TRANSCRIPT)
def handle_final_transcript(message):
    result = TranscriptResult.from_message(message)
    transcript = result.metadata.transcript
    if transcript:
        print(f"[EN]: {transcript}")
        transcript_parts.append(transcript.strip())
```

**English Transcription (Partial):**
```python
@client.on(ServerMessageType.ADD_PARTIAL_TRANSCRIPT)
def handle_partial_transcript(message):
    result = TranscriptResult.from_message(message)
    transcript = result.metadata.transcript
    if transcript:
        print(f"[EN partial]: {transcript}")
```

**Translations (Final):**
```python
@client.on(ServerMessageType.ADD_TRANSLATION)
def handle_final_translation(message):
    language = message.get("language")
    if "results" in message and message["results"]:
        translation = " ".join([r["content"] for r in message["results"]])
        if translation:
            lang_name = "ES" if language == "es" else "RU"
            print(f"[{lang_name}]: {translation}")
            translations[language].append(translation.strip())
```

**Translations (Partial):**
```python
@client.on(ServerMessageType.ADD_PARTIAL_TRANSLATION)
def handle_partial_translation(message):
    language = message.get("language")
    if "results" in message and message["results"]:
        translation = " ".join([r["content"] for r in message["results"]])
        if translation:
            lang_name = "ES" if language == "es" else "RU"
            print(f"[{lang_name} partial]: {translation}")
```

**3. Streaming Audio**

```python
async with AsyncClient() as client:
    await client.start_session(
        transcription_config=transcription_config,
        translation_config=translation_config,
        audio_format=audio_format,
    )

    while True:
        frame = await mic.read(audio_format.chunk_size)
        await client.send_audio(frame)
```

## Expected Output

When you speak "Hello, how are you today?" you'll see:

```
Microphone started - speak now...
Press Ctrl+C to stop transcription

[EN]: Hello.
[ES]: Hola.
[RU]: Добрый день.
[EN partial]: How's it going?
[EN]: How's it
[EN partial]: going?
[EN]: going?
[ES]: ¿Cómo va todo?
[RU]: Как обстоят дела?

^C
Transcription session cancelled

Full transcript: Hello. How's it going?
Spanish: Hola. ¿Cómo va todo?
Russian: Добрый день. Как обстоят дела?
```

## Key Features Demonstrated

**Real-time Processing:**
- Live microphone input streaming
- Immediate transcription feedback
- Concurrent translation to multiple languages

**Event Types:**
- **ADD_TRANSCRIPT**: Finalized English transcription segments
- **ADD_PARTIAL_TRANSCRIPT**: Real-time English preview as you speak
- **ADD_TRANSLATION**: Complete translated sentences
- **ADD_PARTIAL_TRANSLATION**: Translation previews

**Translation Behavior:**
- English transcription is word-by-word (incremental)
- Translations wait for sentence context (complete phrases)
- This is by design - translations need context for accuracy

## Understanding Translation Timing

**Why English shows fragments but translations show complete sentences:**

**English (Transcription):**
- Fires as each word is finalized
- Example: "How's it", "going?"
- Incremental real-time updates

**Spanish/Russian (Translation):**
- Waits for enough context
- Example: "¿Cómo va todo?" (complete sentence)
- Better accuracy through context

This is expected behavior - the translation engine batches words together to provide coherent, accurate translations rather than word-for-word fragments.

## Configuration Options

### Change Target Languages

Modify the `TranslationConfig` to translate to different languages:

```python
translation_config = TranslationConfig(
    target_languages=["fr", "de", "it"],  # French, German, Italian
    enable_partials=True,
)
```

### Change Source Language

Transcribe in a different language:

```python
transcription_config = TranscriptionConfig(
    language="es",  # Spanish input
    enable_partials=True,
)
```

### Disable Partial Results

Only show final results:

```python
transcription_config = TranscriptionConfig(
    language="en",
    enable_partials=False,  # No partial results
)

translation_config = TranslationConfig(
    target_languages=["es", "ru"],
    enable_partials=False,  # No partial translations
)
```

## Supported Languages

### Translation Support

**Source Languages (55+):**
- English (en), Spanish (es), French (fr), German (de), Italian (it)
- Portuguese (pt), Dutch (nl), Russian (ru), Japanese (ja), Korean (ko)
- Chinese (zh), Arabic (ar), Hindi (hi), and 40+ more

**Target Languages (55+):**
- All major European languages
- Asian languages (Chinese, Japanese, Korean)
- Middle Eastern languages (Arabic, Hebrew)
- View full list: [Supported Languages](https://docs.speechmatics.com/speech-to-text/languages#translation-languages)

## Next Steps

- **[Text-to-Speech](../06-text-to-speech/)** - Convert translated text back to speech
- **[Audio Intelligence](../04-audio-intelligence/)** - Extract insights from transcribed content
- **[Video Captioning](../../use-cases/02-video-captioning/)** - Generate subtitles with translation
- **[Call Center Analytics](../../use-cases/03-call-center-analytics/)** - Analyze multilingual customer calls

## Troubleshooting

### PyAudio Installation Issues

**Windows:**
```bash
# If pip install pyaudio fails, try:
pip install pipwin
pipwin install pyaudio

# Or download pre-built wheel from:
# https://www.lfd.uci.edu/~gohlke/pythonlibs/#pyaudio
pip install PyAudio‑0.2.11‑cp39‑cp39‑win_amd64.whl
```

**Mac:**
```bash
# Install portaudio first
brew install portaudio
pip install pyaudio
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install portaudio19-dev
pip install pyaudio
```

**"Microphone not available" message**
- Check that PyAudio is installed: `pip list | grep PyAudio`
- Verify microphone permissions in your system settings
- Test your microphone with another application

**"Authentication failed" error**
- Verify your API key in `.env` file
- Check your key at [portal.speechmatics.com](https://portal.speechmatics.com/)
- Ensure no extra spaces in the `.env` file

**No translations appearing**
- Speak complete sentences (translations need context)
- Wait 1-2 seconds after speaking
- Check that target languages are supported for translation

**Double spaces in final transcript**
- This is handled by `.strip()` on each segment


## Resources

- [Speechmatics Real-time](https://docs.speechmatics.com/speech-to-text/realtime/quickstart)
- [Translation Documentation](https://docs.speechmatics.com/speech-to-text/features/translation)
- [Languages Models](https://docs.speechmatics.com/speech-to-text/languages)
- [WebSocket API Reference](https://docs.speechmatics.com/api-ref/realtime-transcription-websocket)

---

## Feedback

Help us improve this guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/orgs/speechmatics/discussions/categories/academy)

---

**Time to Complete**: 15 minutes
**Difficulty**: Intermediate
**API Mode**: Real-time
**Languages**: Python

[Back to Basics](../) | [Back to Academy](../../README.md)

