<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../../logos/speechmatics-academy-white-2400x600.png">
  <source media="(prefers-color-scheme: light)" srcset="../../logos/speechmatics-academy-black-2400x600.png">
  <img alt="Speechmatics Academy" src="../../logos/speechmatics-academy-black-2400x600.png" width="320">
</picture>

# Multilingual examples

**Transcribe speech across languages, follow code-switching, or translate transcript text.**

</div>

Multilingual recognition preserves the spoken languages in the transcript. Translation produces text in a target language. Choose the workflow and model that match your audio.

**Start with [Melia 1 Multilingual Transcription](../../basics/12-melia-multilingual/README.md)** for a small Python Batch example that transcribes a recording which switches between languages.

## Choose a workflow

- **Transcribe a multilingual file:** [Melia 1 Multilingual Transcription](../../basics/12-melia-multilingual/README.md) selects Melia 1 and automatic multilingual recognition through the Batch SDK.
- **Translate live microphone speech:** [Multilingual and Translation](../../basics/05-multilingual-translation/README.md) transcribes English and receives Spanish and Russian translations through the Realtime API.
- **Display live code-switching:** [Wall of Voices](../../use-cases/10-wall-of-voices/README.md) renders Melia 1 per-word language tags in the browser. The example uses the preview Realtime endpoint; confirm access before running it.
- **Explore healthcare audio:** [Oak Consultation Studio](../../use-cases/11-oak-consultation-studio/README.md) uses Oak 1 for multilingual Batch consultations. [Medical Assistant](../../use-cases/06-medical-assistant/README.md) instead uses an Arabic and English Enhanced Medical language pack on a preview Realtime endpoint; confirm endpoint and language-pack access.
- **Build a mobile interface:** [Flutter Mobile Transcription](../../use-cases/09-flutter-mobile-transcription/README.md) calls the Batch API directly and uses optional Google Cloud Translation for its translation feature.

Code-switching, bilingual language packs, and translation use separate configurations. Check the [model documentation](https://docs.speechmatics.com/speech-to-text/models): support can differ between Batch and Realtime, even within a model family.

## Choose an example

<!-- BEGIN GENERATED: examples -->
| Example | What you'll build | SDK / adapter | Language / level | Demo |
| --- | --- | --- | --- | --- |
| [Melia 1 Multilingual Transcription](<../../basics/12-melia-multilingual/README.md>) | Transcribe audio that switches between languages with Melia 1. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python<br>beginner | [Local](<../../basics/12-melia-multilingual/README.md>) |
| [Multilingual &amp; Translation](<../../basics/05-multilingual-translation/README.md>) | Stream English microphone audio and display Spanish and Russian translations. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python<br>intermediate | [Local](<../../basics/05-multilingual-translation/README.md>) |
| [Medical Assistant](<../../use-cases/06-medical-assistant/README.md>) **Preview** | Transcribe Arabic and English consultations and draft structured fields and SOAP notes. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript<br>advanced | [Local](<../../use-cases/06-medical-assistant/README.md>) |
| [Flutter Mobile Transcription App](<../../use-cases/09-flutter-mobile-transcription/README.md>) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart<br>intermediate | [Local](<../../use-cases/09-flutter-mobile-transcription/README.md>) |
| [Wall of Voices](<../../use-cases/10-wall-of-voices/README.md>) **Preview** | Display live multilingual transcripts with per-word language labels and colors. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript<br>intermediate | [Recording](<../../use-cases/10-wall-of-voices/assets/wall-of-voices.gif>) · [Local](<../../use-cases/10-wall-of-voices/README.md>) |
| [Oak Consultation Studio](<../../use-cases/11-oak-consultation-studio/README.md>) | Explore multilingual medical transcripts with Oak 1, audio playback, and speaker labels. | Direct API / configuration | Python, JavaScript<br>intermediate | [Hosted](<https://oak-consultation-studio.vercel.app/>) · [Recording](<../../use-cases/11-oak-consultation-studio/assets/oak-consultation-studio.gif>) · [Local](<../../use-cases/11-oak-consultation-studio/README.md>) |

### Demo access

- [Medical Assistant](<../../use-cases/06-medical-assistant/README.md>): Live transcription requires access to the preview Realtime endpoint and the `ar_en` bilingual language pack. Transcripts are sent to OpenAI; use synthetic or de-identified data. The app has no login. Run Demo uses synthetic transcripts but still requires an OpenAI key and makes billable requests.
- [Flutter Mobile Transcription App](<../../use-cases/09-flutter-mobile-transcription/README.md>): Requires a mobile device/emulator and platform toolchain; iOS needs macOS and Xcode. Add keys in-app; do not distribute builds with embedded keys.
- [Wall of Voices](<../../use-cases/10-wall-of-voices/README.md>): The GIF is a recording; running locally requires microphone access and a key with access to the preview Realtime endpoint.
- [Oak Consultation Studio](<../../use-cases/11-oak-consultation-studio/README.md>): Scripted consultations need no key; transcribing your own audio requires a Speechmatics key with Oak 1 Batch access. A key entered in Settings is saved in this browser until cleared and sent to the deployment's `/api/token` endpoint to obtain a 10-minute Batch key.

API reference: [Speechmatics Batch API](<https://docs.speechmatics.com/speech-to-text/batch/quickstart>) · [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>).
<!-- END GENERATED: examples -->

## Related workflows

- [Healthcare examples](../healthcare/README.md) — compare medical transcription, dictation, and consultation interfaces.
- [Captions and insights](../captions-insights/README.md) — display transcripts and extract insights.
- [Complete Academy catalog](../../docs/CATALOG.md) — browse by language, package, collection, or feature.

[Back to Academy](../../README.md)
