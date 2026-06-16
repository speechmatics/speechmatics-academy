import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/job_config.dart';
import '../models/speaker_profile.dart';

/// Persisted transcription settings — the single source of truth that drives
/// every job. Backed by a Hive box holding one JSON string. Secrets (API keys)
/// are NOT stored here; see ApiKeys (flutter_secure_storage).
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._box) {
    _load();
  }

  static const boxName = 'settings';
  static const _key = 'config';
  final Box _box;

  // ---- state (defaults mirror the original Settings screen) ----
  String mode = 'batch'; // 'batch' | 'realtime'
  String region = 'eu1'; // 'eu1' | 'us1'
  String model = 'omni-v1'; // 'omni-v1' (melia-1) | 'standard' | 'enhanced'
  String languageMode = 'omnilingual'; // omni-v1: 'omnilingual' | 'single'
  String singleLanguage = 'en';
  // Classic models keep their OWN language preferences (switching models must
  // not destroy either side's choices).
  String classicLanguageMode = 'auto'; // 'auto' | 'specific'
  String classicLanguage = 'en'; // ClassicLangCatalog id
  String domain = 'none'; // 'none' | 'medical' | 'finance' (Enhanced only)
  // Identify enrolled speakers in new jobs (profiles live in SpeakerStore).
  bool speakerIdentification = true;
  // Matching sensitivity: lower → more likely to match enrolled speakers,
  // higher → more likely to detect new generic speakers. API default 0.5.
  double speakerSensitivity = 0.5;
  List<String> languageHints = ['en', 'es', 'ru', 'lv'];
  bool languageHintsStrict = false;
  bool diarization = true;
  String diarizationType = 'speaker'; // 'speaker' | 'channel'
  bool customDict = true;
  String customDictText = '';
  bool translation = true;
  String targetLanguageCode = 'en';
  String targetLanguageName = 'English';
  // OFF by default — and keep the threshold low: values like 50 filter out
  // ALL speech (verified live: threshold 50 → empty transcript, 4 → full).
  bool audioFiltering = false;
  double volume = 4;
  bool punctuation = true;
  double sensitivity = 0.5;
  Set<String> marks = {'comma', 'period', 'question_mark', 'exclamation_mark'};
  bool audioEvents = true;
  Set<String> events = {'laughter', 'music', 'applause'};
  // ---- speech intelligence (classic engine only; v3 fields) ----
  bool subtitles = false;
  double subtitleMaxLineLength = 37;
  int subtitleMaxLines = 2;
  bool summary = false;
  String summaryType = 'bullets'; // 'bullets' | 'paragraphs'
  String summaryLength = 'brief'; // 'brief' | 'detailed'
  bool topics = false;
  String topicsText = '';
  bool chapters = false;

  // ---- persistence ----
  void _load() {
    final raw = _box.get(_key);
    if (raw is! String) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      mode = m['mode'] ?? mode;
      // Real-Time is locked in the UI (not implemented) — never load into an
      // unreachable state.
      if (mode != 'batch') mode = 'batch';
      region = m['region'] ?? region;
      model = m['model'] ?? model;
      // Old installs have no model key; sanitize unknown values to the default.
      if (!const {'omni-v1', 'standard', 'enhanced'}.contains(model)) {
        model = 'omni-v1';
      }
      languageMode = m['languageMode'] ?? languageMode;
      // Melia-1 is always omnilingual now (Classic Mode belongs to the
      // classic models) — normalize any stale 'single' preference.
      if (languageMode != 'omnilingual') languageMode = 'omnilingual';
      singleLanguage = m['singleLanguage'] ?? singleLanguage;
      classicLanguageMode = m['classicLanguageMode'] ?? classicLanguageMode;
      classicLanguage = m['classicLanguage'] ?? classicLanguage;
      domain = m['domain'] ?? domain;
      if (!const {'none', 'medical', 'finance'}.contains(domain)) domain = 'none';
      speakerIdentification = m['speakerIdentification'] ?? speakerIdentification;
      speakerSensitivity =
          ((m['speakerSensitivity'] as num?)?.toDouble() ?? speakerSensitivity).clamp(0.0, 1.0);
      languageHints = (m['languageHints'] as List?)?.cast<String>() ?? languageHints;
      languageHintsStrict = m['languageHintsStrict'] ?? languageHintsStrict;
      diarization = m['diarization'] ?? diarization;
      diarizationType = m['diarizationType'] ?? diarizationType;
      customDict = m['customDict'] ?? customDict;
      customDictText = m['customDictText'] ?? customDictText;
      translation = m['translation'] ?? translation;
      targetLanguageCode = m['targetLanguageCode'] ?? targetLanguageCode;
      targetLanguageName = m['targetLanguageName'] ?? targetLanguageName;
      audioFiltering = m['audioFiltering'] ?? audioFiltering;
      volume = (m['volume'] as num?)?.toDouble() ?? volume;
      punctuation = m['punctuation'] ?? punctuation;
      sensitivity = (m['sensitivity'] as num?)?.toDouble() ?? sensitivity;
      marks = (m['marks'] as List?)?.cast<String>().toSet() ?? marks;
      audioEvents = m['audioEvents'] ?? audioEvents;
      events = (m['events'] as List?)?.cast<String>().toSet() ?? events;
      // v3 (speech intelligence) — additive, defaults cover old installs.
      subtitles = m['subtitles'] ?? subtitles;
      subtitleMaxLineLength =
          (m['subtitleMaxLineLength'] as num?)?.toDouble() ?? subtitleMaxLineLength;
      subtitleMaxLines = (m['subtitleMaxLines'] as num?)?.toInt() ?? subtitleMaxLines;
      summary = m['summary'] ?? summary;
      summaryType = m['summaryType'] ?? summaryType;
      summaryLength = m['summaryLength'] ?? summaryLength;
      topics = m['topics'] ?? topics;
      topicsText = m['topicsText'] ?? topicsText;
      chapters = m['chapters'] ?? chapters;

      // v1 → v2 migration: audio filtering shipped (locked) with a destructive
      // default — enabled at threshold 50, which silently filters out ALL
      // speech on classic models. Nobody set those values deliberately.
      final v = (m['v'] as num?)?.toInt() ?? 1;
      if (v < 2) {
        audioFiltering = false;
        volume = 4;
      }
    } catch (_) {/* keep defaults */}
  }

  /// Apply a mutation then persist + notify.
  void _commit(VoidCallback mutate) {
    mutate();
    _box.put(_key, jsonEncode(_toJson()));
    notifyListeners();
  }

  Map<String, dynamic> _toJson() => {
        'v': 3, // v3 = speech-intelligence fields (additive)
        'mode': mode,
        'region': region,
        'model': model,
        'languageMode': languageMode,
        'singleLanguage': singleLanguage,
        'classicLanguageMode': classicLanguageMode,
        'classicLanguage': classicLanguage,
        'domain': domain,
        'speakerIdentification': speakerIdentification,
        'speakerSensitivity': speakerSensitivity,
        'languageHints': languageHints,
        'languageHintsStrict': languageHintsStrict,
        'diarization': diarization,
        'diarizationType': diarizationType,
        'customDict': customDict,
        'customDictText': customDictText,
        'translation': translation,
        'targetLanguageCode': targetLanguageCode,
        'targetLanguageName': targetLanguageName,
        'audioFiltering': audioFiltering,
        'volume': volume,
        'punctuation': punctuation,
        'sensitivity': sensitivity,
        'marks': marks.toList(),
        'audioEvents': audioEvents,
        'events': events.toList(),
        'subtitles': subtitles,
        'subtitleMaxLineLength': subtitleMaxLineLength,
        'subtitleMaxLines': subtitleMaxLines,
        'summary': summary,
        'summaryType': summaryType,
        'summaryLength': summaryLength,
        'topics': topics,
        'topicsText': topicsText,
        'chapters': chapters,
      };

  /// Classic engine (standard/enhanced) vs the next-gen omni-v1.
  bool get isClassic => model != 'omni-v1';

  // ---- setters (each persists + notifies) ----
  void setMode(String v) => _commit(() => mode = v);
  void setRegion(String v) => _commit(() => region = v);
  void setModel(String v) => _commit(() => model = v);
  void setLanguageMode(String v) => _commit(() => languageMode = v);
  void setSingleLanguage(String v) => _commit(() => singleLanguage = v);
  void setClassicLanguageMode(String v) => _commit(() => classicLanguageMode = v);
  void setClassicLanguage(String v) => _commit(() => classicLanguage = v);
  void setDomain(String v) => _commit(() => domain = v);
  void setSpeakerIdentification(bool v) => _commit(() => speakerIdentification = v);
  void setSpeakerSensitivity(double v) => _commit(() => speakerSensitivity = v);
  void setLanguageHints(List<String> v) =>
      _commit(() => languageHints = v.map((e) => e.toLowerCase()).toList());
  void setLanguageHintsStrict(bool v) => _commit(() => languageHintsStrict = v);
  void setDiarization(bool v) => _commit(() => diarization = v);
  void setDiarizationType(String v) => _commit(() => diarizationType = v);
  void setCustomDict(bool v) => _commit(() => customDict = v);
  void setCustomDictText(String v) => _commit(() => customDictText = v);
  void setTranslation(bool v) => _commit(() => translation = v);
  void setTarget(String code, String name) => _commit(() {
        targetLanguageCode = code;
        targetLanguageName = name;
      });
  void setAudioFiltering(bool v) => _commit(() => audioFiltering = v);
  void setVolume(double v) => _commit(() => volume = v);
  void setPunctuation(bool v) => _commit(() => punctuation = v);
  void setSensitivity(double v) => _commit(() => sensitivity = v);
  void toggleMark(String id) =>
      _commit(() => marks.contains(id) ? marks.remove(id) : marks.add(id));
  void setAudioEvents(bool v) => _commit(() => audioEvents = v);
  void toggleEvent(String id) =>
      _commit(() => events.contains(id) ? events.remove(id) : events.add(id));
  void setSubtitles(bool v) => _commit(() => subtitles = v);
  void setSubtitleMaxLineLength(double v) => _commit(() => subtitleMaxLineLength = v);
  void setSubtitleMaxLines(int v) => _commit(() => subtitleMaxLines = v);
  void setSummary(bool v) => _commit(() => summary = v);
  void setSummaryType(String v) => _commit(() => summaryType = v);
  void setSummaryLength(String v) => _commit(() => summaryLength = v);
  void setTopics(bool v) => _commit(() => topics = v);
  void setTopicsText(String v) => _commit(() => topicsText = v);
  void setChapters(bool v) => _commit(() => chapters = v);

  /// Immutable snapshot for one job. [speakers] = the enrolled profiles to
  /// identify (callers pass SpeakerStore.profiles; the list is copied so
  /// later edits can't touch an in-flight job).
  JobConfig snapshot({List<SpeakerProfile> speakers = const []}) => JobConfig(
        model: model,
        region: region,
        languageMode: languageMode,
        singleLanguage: singleLanguage,
        classicLanguageMode: classicLanguageMode,
        classicLanguage: classicLanguage,
        domain: domain,
        languageHints: List.of(languageHints),
        languageHintsStrict: languageHintsStrict,
        diarization: diarization,
        diarizationType: diarizationType,
        customDictEnabled: customDict,
        customDictText: customDictText,
        translationEnabled: translation,
        targetLanguageCode: targetLanguageCode,
        targetLanguageName: targetLanguageName,
        audioFiltering: audioFiltering,
        volumeThreshold: volume,
        punctuation: punctuation,
        sensitivity: sensitivity,
        marks: marks.toList(),
        audioEvents: audioEvents,
        eventTypes: events.toList(),
        subtitlesEnabled: subtitles,
        subtitleMaxLineLength: subtitleMaxLineLength.round(),
        subtitleMaxLines: subtitleMaxLines,
        summaryEnabled: summary,
        summaryType: summaryType,
        summaryLength: summaryLength,
        topicsEnabled: topics,
        topicsText: topicsText,
        chaptersEnabled: chapters,
        speakers: List.of(speakers),
        speakerIdentification: speakerIdentification,
        speakerSensitivity: speakerSensitivity,
      );
}
