<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../../logos/speechmatics-academy-white-2400x600.png">
  <source media="(prefers-color-scheme: light)" srcset="../../logos/speechmatics-academy-black-2400x600.png">
  <img alt="Speechmatics Academy" src="../../logos/speechmatics-academy-black-2400x600.png" width="320">
</picture>

# Captions and insights

**Turn audio into caption files, live transcript displays, and useful transcript analysis.**

</div>

Choose the output you need: Batch captions, speech intelligence, or a live transcript display.

**Start with [Speech intelligence](../../basics/04-audio-intelligence/README.md)** to request sentiment analysis, topic detection, and summaries with the Batch SDK. For a caption file first, use [Video Captioning](../../use-cases/02-video-captioning/README.md).

## Choose a workflow

- **Produce SRT captions:** [Video Captioning](../../use-cases/02-video-captioning/README.md) submits audio or video to the Batch API and retrieves timestamped subtitles. Review the text and timing before publishing.
- **Extract transcript insights:** [Speech intelligence](../../basics/04-audio-intelligence/README.md) requests sentiment, topics, and summaries. [Call Center Analytics](../../use-cases/03-call-center-analytics/README.md) applies them to stereo recordings with channel labels.
- **Build a mobile viewer:** [Flutter Mobile Transcription](../../use-cases/09-flutter-mobile-transcription/README.md) renders transcripts, subtitles, and supported speech-intelligence results from direct Batch API jobs.
- **Display speech as it happens:** [Wall of Voices](../../use-cases/10-wall-of-voices/README.md) turns per-word language tags into a live multilingual wall. It uses the preview Realtime endpoint and requires the appropriate access.

Captions, diarization, summaries, sentiment, and topics are separate request features. Check the [model comparison](https://docs.speechmatics.com/speech-to-text/models) for support in your selected model and API.

## Choose an example

<!-- BEGIN GENERATED: examples -->
| Example | What you'll build | SDK / adapter | Language / level | Demo |
| --- | --- | --- | --- | --- |
| [Speech intelligence - Sentiment, Topics and Summaries](<../../basics/04-audio-intelligence/README.md>) | Extract sentiment, topics, and summaries from a recording. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python<br>intermediate | [Local](<../../basics/04-audio-intelligence/README.md>) |
| [Video Captioning](<../../use-cases/02-video-captioning/README.md>) | Generate SRT captions from video with the Batch API. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python<br>beginner | [Local](<../../use-cases/02-video-captioning/README.md>) |
| [Call Center Analytics](<../../use-cases/03-call-center-analytics/README.md>) | Analyze recorded calls with channel labels, sentiment, topics, and summaries. | [Batch](<https://pypi.org/project/speechmatics-batch/>) | Python<br>beginner | [Local](<../../use-cases/03-call-center-analytics/README.md>) |
| [Flutter Mobile Transcription App](<../../use-cases/09-flutter-mobile-transcription/README.md>) | Record or upload audio from a mobile app, then view transcripts, captions, and insights. | Direct API / configuration | Dart<br>intermediate | [Local](<../../use-cases/09-flutter-mobile-transcription/README.md>) |
| [Wall of Voices](<../../use-cases/10-wall-of-voices/README.md>) **Preview** | Display live multilingual transcripts with per-word language labels and colors. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript<br>intermediate | [Recording](<../../use-cases/10-wall-of-voices/assets/wall-of-voices.gif>) · [Local](<../../use-cases/10-wall-of-voices/README.md>) |

### Demo access

- [Flutter Mobile Transcription App](<../../use-cases/09-flutter-mobile-transcription/README.md>): Requires a mobile device/emulator and platform toolchain; iOS needs macOS and Xcode. Add keys in-app; do not distribute builds with embedded keys.
- [Wall of Voices](<../../use-cases/10-wall-of-voices/README.md>): The GIF is a recording; running locally requires microphone access and a key with access to the preview Realtime endpoint.

API reference: [Speechmatics Batch API](<https://docs.speechmatics.com/speech-to-text/batch/quickstart>) · [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>).
<!-- END GENERATED: examples -->

## Related workflows

- [Telephony examples](../telephony/README.md) — compare recorded-call analysis with live phone agents.
- [Multilingual examples](../multilingual/README.md) — code-switching, language tags, and translation.
- [Complete Academy catalog](../../docs/CATALOG.md) — browse by feature, package, collection, or language.

[Back to Academy](../../README.md)
