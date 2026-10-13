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

  // ---- serialization (persisted on failed HistoryItems so Retry re-runs the
  // job with the settings it was submitted with, not today's settings) ----

  Map<String, dynamic> toJson() => {
        'model': model,
        'region': region,
        'languageMode': languageMode,
        'singleLanguage': singleLanguage,
        'classicLanguageMode': classicLanguageMode,
        'classicLanguage': classicLanguage,
        'domain': domain,
        'languageHints': languageHints,
        'languageHintsStrict': languageHintsStrict,
        'diarization': diarization,
        'diarizationType': diarizationType,
        'customDictEnabled': customDictEnabled,
        'customDictText': customDictText,
        'translationEnabled': translationEnabled,
        'targetLanguageCode': targetLanguageCode,
        'targetLanguageName': targetLanguageName,
        'audioFiltering': audioFiltering,
        'volumeThreshold': volumeThreshold,
        'punctuation': punctuation,
        'sensitivity': sensitivity,
        'marks': marks,
        'audioEvents': audioEvents,
        'eventTypes': eventTypes,
        'subtitlesEnabled': subtitlesEnabled,
        'subtitleMaxLineLength': subtitleMaxLineLength,
        'subtitleMaxLines': subtitleMaxLines,
        'summaryEnabled': summaryEnabled,
        'summaryType': summaryType,
        'summaryLength': summaryLength,
        'topicsEnabled': topicsEnabled,
        'topicsText': topicsText,
        'chaptersEnabled': chaptersEnabled,
        'speakers': speakers.map((s) => s.toJson()).toList(),
        'speakerIdentification': speakerIdentification,
        'speakerSensitivity': speakerSensitivity,
      };

  /// Tolerant: any missing or wrong-typed field falls back to its default, so
  /// a retry never fails on a config persisted by an older build.
  factory JobConfig.fromJson(Map<String, dynamic> j) {
    const d = JobConfig();
    String str(String k, String fb) => j[k] is String ? j[k] as String : fb;
    bool flag(String k, bool fb) => j[k] is bool ? j[k] as bool : fb;
    double dbl(String k, double fb) => j[k] is num ? (j[k] as num).toDouble() : fb;
    int intOf(String k, int fb) => j[k] is num ? (j[k] as num).toInt() : fb;
    List<String> strings(String k, List<String> fb) =>
        j[k] is List ? (j[k] as List).whereType<String>().toList() : fb;
    return JobConfig(
      model: str('model', d.model),
      region: str('region', d.region),
      languageMode: str('languageMode', d.languageMode),
      singleLanguage: str('singleLanguage', d.singleLanguage),
      classicLanguageMode: str('classicLanguageMode', d.classicLanguageMode),
      classicLanguage: str('classicLanguage', d.classicLanguage),
      domain: str('domain', d.domain),
      languageHints: strings('languageHints', d.languageHints),
      languageHintsStrict: flag('languageHintsStrict', d.languageHintsStrict),
      diarization: flag('diarization', d.diarization),
      diarizationType: str('diarizationType', d.diarizationType),
      customDictEnabled: flag('customDictEnabled', d.customDictEnabled),
      customDictText: str('customDictText', d.customDictText),
      translationEnabled: flag('translationEnabled', d.translationEnabled),
      targetLanguageCode: str('targetLanguageCode', d.targetLanguageCode),
      targetLanguageName: str('targetLanguageName', d.targetLanguageName),
      audioFiltering: flag('audioFiltering', d.audioFiltering),
      volumeThreshold: dbl('volumeThreshold', d.volumeThreshold),
      punctuation: flag('punctuation', d.punctuation),
      sensitivity: dbl('sensitivity', d.sensitivity),
      marks: strings('marks', d.marks),
      audioEvents: flag('audioEvents', d.audioEvents),
      eventTypes: strings('eventTypes', d.eventTypes),
      subtitlesEnabled: flag('subtitlesEnabled', d.subtitlesEnabled),
      subtitleMaxLineLength: intOf('subtitleMaxLineLength', d.subtitleMaxLineLength),
      subtitleMaxLines: intOf('subtitleMaxLines', d.subtitleMaxLines),
      summaryEnabled: flag('summaryEnabled', d.summaryEnabled),
      summaryType: str('summaryType', d.summaryType),
      summaryLength: str('summaryLength', d.summaryLength),
      topicsEnabled: flag('topicsEnabled', d.topicsEnabled),
      topicsText: str('topicsText', d.topicsText),
      chaptersEnabled: flag('chaptersEnabled', d.chaptersEnabled),
      speakers: j['speakers'] is List
          ? (j['speakers'] as List)
              .whereType<Map>()
              .map((m) => SpeakerProfile.fromJson(m.cast<String, dynamic>()))
              .whereType<SpeakerProfile>()
              .toList()
          : d.speakers,
      speakerIdentification: flag('speakerIdentification', d.speakerIdentification),
      speakerSensitivity: dbl('speakerSensitivity', d.speakerSensitivity),
    );
  }
}
