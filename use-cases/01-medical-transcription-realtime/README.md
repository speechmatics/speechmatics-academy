# Healthcare Medical - Real-Time Transcription

**Live transcription for clinical notes, patient interviews, and telemedicine with custom medical vocabulary.**

Supports on-premise deployment for HIPAA compliance.

## What You'll Learn

- Real-time transcription with medical vocabulary
- Adding custom terminology (drugs, procedures, conditions)
- Event-driven transcript handling
- Streaming audio for live transcription
- HIPAA-compliant deployment options

## Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.8+**
- **Audio file**: Medical recording in WAV, MP3, or other supported format

## Quick Start

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

**Step 2: Install dependencies and run**

```bash
pip install -r requirements.txt
cp ../.env.example .env
# Edit .env and add your SPEECHMATICS_API_KEY
python main.py
```

Place your medical recording as `sample.wav` in the `assets/` folder before running.

## How It Works

> [!NOTE]
> This example uses the Real-Time API for live transcription:
>
> 1. **Connect** - Establish WebSocket connection
> 2. **Stream** - Send audio chunks in real-time
> 3. **Receive** - Get partial and final transcripts via events
> 4. **Save** - Output saved to assets folder

### Configuration

```python
from speechmatics.rt import (
    AsyncClient,
    AuthenticationError,
    TranscriptionConfig,
    ServerMessageType,
)

config = TranscriptionConfig(
    language="en",
    enable_partials=True,
    additional_vocab=[
        {"content": "hypertension"},
        {"content": "metformin"},
        {"content": "echocardiogram"},
        {"content": "MRI", "sounds_like": ["M R I", "M. R. I."]},
        {"content": "CT scan", "sounds_like": ["C T scan"]},
        {"content": "diabetes mellitus"},
    ],
)

try:
    async with AsyncClient() as client:  # Auto-reads SPEECHMATICS_API_KEY from env
        @client.on(ServerMessageType.ADD_TRANSCRIPT)
        def handle_transcript(msg):
            print(f"Final: {msg['metadata']['transcript']}")

        @client.on(ServerMessageType.ADD_PARTIAL_TRANSCRIPT)
        def handle_partial(msg):
            print(f"Partial: {msg['metadata']['transcript']}")

        with open(audio_file, "rb") as f:
            await client.transcribe(f, transcription_config=config)

except (AuthenticationError, ValueError) as e:
    print(f"Authentication Error: {e}")
```

### Configuration Options

| Parameter | Options | Description |
|-----------|---------|-------------|
| `language` | `"en"`, `"es"`, `"fr"`, etc. | Transcription language |
| `enable_partials` | `True`, `False` | Show real-time partial transcripts |
| `additional_vocab` | `[{...}]` | Custom medical terminology |
| `diarization` | `"speaker"`, `"none"` | Identify doctor vs patient |

## Expected Output

```
================================================================================
MEDICAL TRANSCRIPTION (Real-Time)
================================================================================
Processing: sample.wav

================================================================================
MEDICAL TRANSCRIPTION (Real-Time)
================================================================================
Processing: sample.wav

Partial: Good
Partial: Good morning
Partial: Good morning, Mr. Ramirez
Partial: Good morning, Mr. Ramirez
Partial: Good morning, Mr. Ramirez de
Partial: Good morning, Mr. Ramirez. Based on
Partial: Good morning, Mr. Ramirez. Based on your recent
Partial: Good morning, Mr. Ramirez. Based on your recent
Partial: Good morning, Mr. Ramirez. Based on your recent vitals and the
Partial: Good morning, Mr. Ramirez. Based on your recent vitals and the symptoms
Partial: Good morning, Mr. Ramirez. Based on your recent vitals and the symptoms, you
Partial: Good morning, Mr. Ramirez. Based on your recent vitals and the symptoms you reported
Final: Good morning,
Partial: Mr. Ramirez. Based on your recent vitals and the symptoms you reported
Final: Mr.
Partial: Ramirez. Based on your recent vitals and the symptoms you reported. I'm
Partial: Ramirez. Based on your recent vitals and the symptoms you reported, I'm concerned about
Final: Ramirez.
Partial: Based on your recent vitals and the symptoms you reported, I'm concerned about
Final: Based on
Partial: your recent vitals and the symptoms you reported, I'm concerned about possible
Final: your
Partial: recent vitals and the symptoms you reported, I'm concerned about possible
Final: recent
Partial: vitals and the symptoms you reported, I'm concerned about possible
Final: vitals and the
Partial: symptoms you reported, I'm concerned about possible cardiovascular involvement
Final: symptoms
Partial: you reported, I'm concerned about possible cardiovascular involvement
Final: you
Partial: reported, I'm concerned about possible cardiovascular involvement.
Partial: reported, I'm concerned about possible cardiovascular involvement.
Final: reported,
Partial: I'm concerned about possible cardiovascular involvement. Given your

================================================================================
Transcript saved to: .../assets/transcript.txt
================================================================================
```

## Key Features Demonstrated

**Real-Time Transcription:**
- WebSocket streaming connection
- Partial transcripts for live feedback
- Final transcripts with high accuracy

**Medical Vocabulary:**
- Custom terminology boost
- Drug names and procedures
- Phonetic hints with `sounds_like`

**Use Cases:**
- Clinical documentation
- Patient interviews
- Telemedicine consultations
- Medical dictation

## Customizing Medical Vocabulary

Add your specific medical terms to `additional_vocab`:

```python
additional_vocab=[
    {"content": "hypertension"},
    {"content": "metformin"},
    {"content": "your_drug_name"},
    {"content": "your_procedure_name"},
    {"content": "MRI", "sounds_like": ["M R I", "M. R. I."]},
]
```

**Common terms to add:**
- Drug names (generic and brand)
- Surgical procedures
- Medical devices
- Disease names
- Lab tests

## HIPAA Compliance

**Cloud Deployment**: For non-PHI or de-identified data.

**On-Premise Deployment**: For PHI compliance, set in `.env`:
```
SPEECHMATICS_ONPREMISE_URL=https://speechmatics.yourhospital.local
```

**Best Practices:**
- Use on-premise for PHI
- Encrypt data at rest and in transit
- Never commit audio with PHI to version control

## Supported Audio Formats

- WAV (recommended)
- MP3
- FLAC
- M4A
- OGG

## Troubleshooting

**"Audio file not found"**
- Ensure `sample.wav` exists in the `assets/` folder

**"Authentication failed"**
- Check your API key in the `.env` file

**"Poor accuracy on medical terms"**
- Add domain-specific terms to `additional_vocab`

**"Connection errors"**
- Verify internet connection
- Check API endpoint URL

## Resources

- [Real-Time API Documentation](https://docs.speechmatics.com/introduction/rt-guide)
- [Custom Vocabulary Guide](https://docs.speechmatics.com/features/custom-dictionary)
- [HIPAA Compliance](https://docs.speechmatics.com/security)

---

**Time to Complete**: 10 minutes
**Difficulty**: Intermediate
**API Mode**: Real-Time

[Back to Academy](../../README.md)
