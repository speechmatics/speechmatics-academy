# Melia Multilingual Transcription

**Transcribe a multilingual recording with Melia, Speechmatics' multilingual speech-to-text model, over the Batch API. Set the model to "melia-1" and the language to "multi", and a recording that moves between languages comes back as one continuous transcript.**

Melia handles code-switching across 55+ languages in a single file, with no language to choose in advance and no language packs to manage. This example sends the minimal job config with the `speechmatics-batch` SDK and prints the transcript.

## What You'll Learn

- **How to select Melia**: the entire change is `model: "melia-1"` and `language: "multi"` in the transcription config.
- **The minimal Batch SDK flow**: submit a job and wait for the finished transcript in two calls, with the SDK handling the waiting.

## Prerequisites

- **Python 3.12+**
- **Speechmatics API Key**. Sign up at [portal.speechmatics.com](https://portal.speechmatics.com/) and create a key under **API Keys**.
- **An audio file**. Any supported format (WAV, MP3, M4A, FLAC, OGG). Use a recording that switches between languages to see Melia at its best.

## Quick Start

### Python

**Step 1: Create and activate a virtual environment**

**On Windows:**
```bash
cd python
python -m venv .venv
.venv\Scripts\activate
```

**On Mac/Linux:**
```bash
cd python
python3 -m venv .venv
source .venv/bin/activate
```

**Step 2: Install dependencies**

```bash
pip install -r requirements.txt
```

**Step 3: Configure environment**

```bash
cp ../.env.example ../.env
# Edit ../.env and add your real API key
```

**Step 4: Run it**

```bash
python main.py path/to/your-audio.wav
```

If you place a file at `assets/sample.wav`, you can also run `python main.py` with no arguments.

## How It Works

The config is the whole story. This is what Melia needs:

```json
{
  "type": "transcription",
  "transcription_config": {
    "model": "melia-1",
    "language": "multi"
  }
}
```

`main.py` submits that config with the audio file, waits for the job to finish, prints the plain-text transcript, then lists the languages Melia tagged across the words:

```python
job = await client.submit_job(audio_file, config=melia)
transcript = await client.wait_for_completion(job.id, format_type=FormatType.TXT)
print(transcript)

# Melia tags every word with its language; list the distinct ones.
result = await client.get_transcript(job.id, format_type=FormatType.JSON)
```

`wait_for_completion` does the waiting for you, so there is no polling loop to write.

> [!NOTE]
> `melia-1` is the newest model and is not yet a typed field on the SDK's `TranscriptionConfig`, which still exposes only `operating_point`. The example subclasses `JobConfig` and sets `model` when the config is serialized.

## Expected Output

For the bundled sample, which switches from English into Latvian partway through:

```
Speechmatics is a voice technology company that helps people and businesses work with spoken language in a smarter, faster and more efficient way. Instead of leaving speech only as audio, it turns conversations, recordings, meetings, interviews, and podcasts and live voice into useful. Digital Text. Lielākā vērtība ir tā spēja padarīt runu pieejamāku un vieglāk izmantojama ikdienas darbā. Tas palīdz uzņēmumiem ietaupīt laiku, uzlabot saziņu un veidot pakalpojumus, kas labāk saprot dažādas balsis.

Languages detected: en, lv
```

The whole recording comes back as one transcript, even where it switches language mid-recording, and every word carries a language tag.

## Key Features Demonstrated

- **One model, many languages**: a single config transcribes mixed-language audio without selecting a language up front.
- **Code-switching**: the transcript stays continuous across language changes within a recording.
- **Per-word language tags**: the json-v2 result tags each word with its language, so you can see exactly which languages appeared.

## Configuration Options

- **Diarization**: add `"diarization": "speaker"` to the `transcription_config` (in `MeliaJob.to_dict`) to label speakers.
- **Output format**: this example requests `FormatType.TXT` for plain text. Use `FormatType.JSON` to get word-level timings and a `language` tag on every word.

## Troubleshooting

**`SPEECHMATICS_API_KEY not set`**
- Add your key to `.env` (copied from `.env.example`), or export it in your shell.

**`model must be one of ...`**
- Model identifiers can change over time. Confirm the current name for Melia in the [models documentation](https://docs.speechmatics.com/) and update `MeliaJob.to_dict` in `main.py`.

**`No such file` or a file error**
- Pass a path to an audio file as the first argument (`python main.py path/to/audio.wav`), or place one at `assets/sample.wav`.

**The transcript looks single-language**
- The recording may be in one language. Melia still transcribes it; try a clip that switches languages to see code-switching in a single transcript.

## Resources

- [Speechmatics documentation](https://docs.speechmatics.com/)
- [Speechmatics Batch API reference](https://docs.speechmatics.com/jobsapi)
- [Supported languages](https://docs.speechmatics.com/introduction/supported-languages)
- [Speechmatics Portal](https://portal.speechmatics.com/)

---

## Feedback

Help us improve this guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/orgs/speechmatics/discussions/categories/academy)

---

**Time to Complete**: 5 minutes
**Difficulty**: Beginner
**API Mode**: Batch
**Languages**: Python

[Back to Basics](../) | [Back to Academy](../../README.md)
