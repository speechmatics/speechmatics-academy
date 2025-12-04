# Media & Entertainment - Generate Captions

**Auto-generate accurate SRT captions for video content with timestamp synchronization.**

Perfect for streaming platforms, video production, content creation, and accessibility compliance.

## What You'll Learn

- Generating SRT subtitle files from video/audio
- Using the Batch API for media processing
- Working with different output formats (SRT, VTT, TXT)
- Timestamp synchronization for captions
- Batch processing video content

## Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.8+**
- **Video/Audio file**: MP4, MOV, WAV, MP3, or other supported format

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

Place your video file as `sample.mp4` in the `assets/` folder before running.

## How It Works

> [!NOTE]
> This example uses the Batch API to generate SRT captions:
>
> 1. **Submit job** - Upload video with transcription config
> 2. **Process** - Speechmatics extracts and transcribes audio
> 3. **Output** - Get timestamped SRT file ready for use

### Configuration

```python
from speechmatics.batch import AsyncClient, TranscriptionConfig, FormatType

async with AsyncClient(api_key=api_key) as client:
    job = await client.submit_job(
        str(video_file),
        transcription_config=TranscriptionConfig(language="en")
    )

    # Get SRT format captions
    captions = await client.wait_for_completion(job.id, format_type=FormatType.SRT)

    # Save to file
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(captions)
```

### Configuration Options

| Parameter | Options | Description |
|-----------|---------|-------------|
| `language` | `"en"`, `"es"`, `"fr"`, `"auto"` | Transcription language |
| `format_type` | `FormatType.SRT`, `FormatType.VTT` | Output format |
| `diarization` | `"speaker"`, `"none"` | Add speaker labels |

## Expected Output

```
Submitting job for: .../assets/sample.mp4
Job submitted with ID: eav4svksl1
Waiting for completion...

================================================================================
SUCCESS: Captions saved to .../assets/sample.srt
================================================================================

Preview of captions:
--------------------------------------------------------------------------------
1
00:00:00,640 --> 00:00:03,080
Hey everyone, this is Eli from
Speechmatics and today we're going

2
00:00:03,080 --> 00:00:05,920
to talk about text to speech.
How you can take any bit of text,

3
00:00:05,960 --> 00:00:08,920
turn it into actual speech.
...
```

## Key Features Demonstrated

**Caption Generation:**
- Automatic SRT subtitle creation
- Precise timestamp synchronization
- UTF-8 encoding support

**Media Processing:**
- Video and audio file support
- Async job submission
- Multiple output formats

**Use Cases:**
- Streaming platform captions (Netflix, YouTube)
- Accessibility compliance (ADA, WCAG)
- Video podcasts and educational content
- Social media content
- Film and documentary production

## Using the SRT File

### With Video Editors

- **Adobe Premiere Pro**: File > Import > select .srt file
- **Final Cut Pro**: Import as captions track
- **DaVinci Resolve**: File > Import > Subtitle

### With Media Players

- **VLC**: Video > Subtitles > Add Subtitle File
- **QuickTime**: View > Subtitles > Select your .srt file

### Embedding in Video

```bash
# Using FFmpeg to burn subtitles into video
ffmpeg -i sample.mp4 -vf subtitles=sample.srt output_with_subs.mp4
```

## Supported Formats

### Video
- MP4, MOV, AVI, MKV, WebM

### Audio
- WAV, MP3, FLAC, OGG, M4A, AAC

## Troubleshooting

**"Video file not found"**
- Ensure `sample.mp4` exists in the `assets/` folder
- Or update `video_file` path in `media_captions.py`

**"Authentication failed"**
- Check your API key in the `.env` file
- Verify your key at [portal.speechmatics.com](https://portal.speechmatics.com/)

**"Large file timeout"**
- For long videos, processing may take several minutes
- Consider splitting very large files

**"Unsupported format"**
- Convert to MP4, MOV, or WAV

## Resources

- [Batch API Documentation](https://docs.speechmatics.com/introduction/batch-guide)
- [Output Formats](https://docs.speechmatics.com/features/output-formats)
- [SRT Format Specification](https://www.matroska.org/technical/subtitles.html)

---

## Feedback

Help us improve this guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/orgs/speechmatics/discussions/categories/academy)

---

**Time to Complete**: 10 minutes
**Difficulty**: Beginner
**API Mode**: Batch

[Back to Use Cases](../) | [Back to Academy](../../README.md)
