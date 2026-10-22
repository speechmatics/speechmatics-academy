<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../../logos/speechmatics-academy-white-2400x600.png">
  <source media="(prefers-color-scheme: light)" srcset="../../logos/speechmatics-academy-black-2400x600.png">
  <img alt="Speechmatics Academy" src="../../logos/speechmatics-academy-black-2400x600.png" width="320">
</picture>

# Healthcare examples

**Build healthcare transcription, dictation, and transcript-based applications with Speechmatics.**

</div>

Choose a healthcare workflow, then follow its README for setup and model configuration.

**Start with [Realtime medical transcription](../../use-cases/01-medical-transcription-realtime/README.md)** to configure Enhanced Medical and stream audio. For a browser preview, [explore Oak Consultation Studio's scripted consultations](https://oak-consultation-studio.vercel.app/).

## Choose a workflow

- **Live transcription:** [Medical Transcription](../../use-cases/01-medical-transcription-realtime/README.md) uses the Realtime API with Enhanced Medical and a custom dictionary.
- **Multilingual recordings:** [Oak Consultation Studio](../../use-cases/11-oak-consultation-studio/README.md) uses Oak 1 with the Batch API and provides playback, language labels, and transcript exploration.
- **Microphone audio submitted in chunks:** [Medical Microbatching](../../use-cases/07-medical-microbatching/README.md) demonstrates voice activity detection, Batch jobs, and a speaker-identification variant.
- **Desktop dictation:** [Tambourine Healthcare Dictation](../../integrations/tambourine/01-healthcare-dictation/README.md) is a configuration guide for a separate desktop application.
- **Transcription plus extraction:** [Medical Assistant](../../use-cases/06-medical-assistant/README.md) combines bilingual transcription with an LLM to produce draft structured information and clinical notes.

## Choose an example

<!-- BEGIN GENERATED: examples -->
| Example | What you'll build | SDK / adapter | Language / level | Demo |
| --- | --- | --- | --- | --- |
| [Tambourine Healthcare Dictation](<../../integrations/tambourine/01-healthcare-dictation/README.md>) | Configure desktop dictation and clinical formatting prompts in Tambourine. | Direct API / configuration | Configuration<br>beginner | [Local](<../../integrations/tambourine/01-healthcare-dictation/README.md>) |
| [Medical Transcription - Realtime Enhanced Medical](<../../use-cases/01-medical-transcription-realtime/README.md>) | Stream a medical recording with Enhanced Medical and a custom dictionary. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python<br>intermediate | [Local](<../../use-cases/01-medical-transcription-realtime/README.md>) |
| [Medical Assistant](<../../use-cases/06-medical-assistant/README.md>) **Preview** | Transcribe Arabic and English consultations and draft structured fields and SOAP notes. | [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python, JavaScript<br>advanced | [Local](<../../use-cases/06-medical-assistant/README.md>) |
| [Medical Microbatching](<../../use-cases/07-medical-microbatching/README.md>) | Split microphone audio into Batch jobs with optional speaker tracking and Medical settings. | [Batch](<https://pypi.org/project/speechmatics-batch/>), [Realtime](<https://pypi.org/project/speechmatics-rt/>) | Python<br>intermediate | [Local](<../../use-cases/07-medical-microbatching/README.md>) |
| [Oak Consultation Studio](<../../use-cases/11-oak-consultation-studio/README.md>) | Explore multilingual medical transcripts with Oak 1, audio playback, and speaker labels. | Direct API / configuration | Python, JavaScript<br>intermediate | [Hosted](<https://oak-consultation-studio.vercel.app/>) · [Recording](<../../use-cases/11-oak-consultation-studio/assets/oak-consultation-studio.gif>) · [Local](<../../use-cases/11-oak-consultation-studio/README.md>) |

### Demo access

- [Tambourine Healthcare Dictation](<../../integrations/tambourine/01-healthcare-dictation/README.md>): Requires a separate Tambourine desktop installation; its installed STT adapter determines the model and endpoint.
- [Medical Assistant](<../../use-cases/06-medical-assistant/README.md>): Live transcription requires access to the preview Realtime endpoint and the `ar_en` bilingual language pack. Transcripts are sent to OpenAI; use synthetic or de-identified data. The app has no login. Run Demo uses synthetic transcripts but still requires an OpenAI key and makes billable requests.
- [Oak Consultation Studio](<../../use-cases/11-oak-consultation-studio/README.md>): Scripted consultations need no key; transcribing your own audio requires a Speechmatics key with Oak 1 Batch access. A key entered in Settings is saved in this browser until cleared and sent to the deployment's `/api/token` endpoint to obtain a 10-minute Batch key.

API reference: [Speechmatics Batch API](<https://docs.speechmatics.com/speech-to-text/batch/quickstart>) · [Speechmatics Realtime API](<https://docs.speechmatics.com/speech-to-text/realtime/quickstart>).
<!-- END GENERATED: examples -->

## Model selection

Enhanced Medical is the Medical sub-variant of Enhanced, selected with `domain="medical"` and a supported language. Oak 1 is a separate multilingual model for Batch transcription, selected with `model="oak-1"` and `language="multi"`. Their feature support differs; see the [current model comparison](https://docs.speechmatics.com/speech-to-text/models).

The microbatching example uses general Enhanced by default. The Tambourine guide's healthcare formatting prompt does not by itself select a Speechmatics medical model. Follow the configuration documented for the chosen example.

## Continue learning

- [LiveKit examples](../../integrations/livekit/README.md) — build voice-agent applications with a framework, an LLM, and speech synthesis.
- [Multilingual examples](../multilingual/README.md) — compare automatic code-switching and translation workflows.
- [Complete Academy catalog](../../docs/CATALOG.md) — browse by API package, feature, language, integration, collection, or difficulty.
- [Contribute an example](../../docs/CONTRIBUTING.md) — add one metadata entry and regenerate the discovery pages.

[Back to Academy](../../README.md)
