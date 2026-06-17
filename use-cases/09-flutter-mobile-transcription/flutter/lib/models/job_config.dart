import 'speaker_profile.dart';

/// Immutable snapshot of the transcription settings used for one job.
///
/// Taken from `SettingsStore` at submit time so a job is unaffected by later
/// settings edits. `ConfigMapper` turns this into the omni-v1
/// `transcription_config`; the translation fields drive Google Translate only.
class JobConfig {
  const JobConfig({
    this.model = 'omni-v1',
    this.region = 'eu1',
    this.languageMode = 'omnilingual',
    this.singleLanguage = 'en',
    this.classicLanguageMode = 'auto', // 'auto' | 'specific'
    this.classicLanguage = 'en', // ClassicLangCatalog id
    this.domain = 'none', // 'none' | 'medical' | 'finance' (Enhanced only)
    this.languageHints = const [],
    this.languageHintsStrict = false,
    this.diarization = true,
    this.diarizationType = 'speaker', // 'speaker' | 'channel'
    this.customDictEnabled = false,
    this.customDictText = '',
    this.translationEnabled = true,
    this.targetLanguageCode = 'en',
    this.targetLanguageName = 'English',
    this.audioFiltering = false,
    this.volumeThreshold = 4,
    this.punctuation = true,
    this.sensitivity = 0.5,
    this.marks = const ['comma', 'period', 'question_mark', 'exclamation_mark'],
    this.audioEvents = false,
    this.eventTypes = const ['laughter', 'music', 'applause'],
    this.subtitlesEnabled = false,
    this.subtitleMaxLineLength = 37,
    this.subtitleMaxLines = 2,
    this.summaryEnabled = false,
    this.summaryType = 'bullets', // 'bullets' | 'paragraphs'
    this.summaryLength = 'brief', // 'brief' | 'detailed'
    this.topicsEnabled = false,
    this.topicsText = '', // raw comma-separated seed topics
    this.chaptersEnabled = false,
    this.speakers = const [],
    this.speakerIdentification = true,
    this.speakerSensitivity = 0.5,
  });

  final String model; // API model id, e.g. 'omni-v1' (melia-1 is display-only)
  final String region; // 'eu1' | 'us1'
  final String languageMode; // omni-v1: 'omnilingual' | 'single'
  final String singleLanguage; // omni-v1 single-language code
  final String classicLanguageMode; // classic: 'auto' | 'specific'
  final String classicLanguage; // classic catalog id (may carry a domain)
  // Domain language pack (probe-verified 2026-06-12: medical/finance, Enhanced
  // + specific language only; bilingual packs carry their own domain).
  final String domain;
  final List<String> languageHints; // lower-case api codes
  final bool languageHintsStrict; // constrain output to ONLY the hinted languages
  final bool diarization;
  final String diarizationType;
  final bool customDictEnabled;
  final String customDictText;
  final bool translationEnabled;
  final String targetLanguageCode; // for Google Translate, e.g. 'en'
  final String targetLanguageName; // display, e.g. 'English'
  final bool audioFiltering;
  final double volumeThreshold;
  final bool punctuation;
  final double sensitivity;
  final List<String> marks;
  final bool audioEvents;
  final List<String> eventTypes;

  // ---- speech intelligence (classic engine only) ----
  final bool subtitlesEnabled;
  final int subtitleMaxLineLength;
  final int subtitleMaxLines;
  final bool summaryEnabled;
  final String summaryType;
  final String summaryLength;
  final bool topicsEnabled;
  final String topicsText;
  final bool chaptersEnabled;

  // ---- speaker identification (probe-verified 2026-06-12: classic only —
  // omni-v1 accepts the block but ignores it) ----
  final List<SpeakerProfile> speakers; // enrolled profiles to identify
  final bool speakerIdentification; // master toggle from Settings
  // Matching sensitivity (API param `speaker_sensitivity` — the documented
  // `speakers_sensitivity` is rejected by the deployed schema). Lower →
  // favours matching enrolled speakers; higher → detects new ones.
  final double speakerSensitivity;

  bool get isOmnilingual => languageMode == 'omnilingual';

  /// Classic engine (standard/enhanced) vs next-gen omni-v1. Both engines are
  /// addressed via `model` — the API normalizes classic values to
  /// operating_point internally.
  bool get isClassic => model != 'omni-v1';

  /// Marketing/display name for an API model id.
  static String displayNameFor(String model) => switch (model) {
        'standard' => 'Standard',
        'enhanced' => 'Enhanced',
        _ => 'Melia-1',
      };

  String get modelDisplayName => displayNameFor(model);
}
