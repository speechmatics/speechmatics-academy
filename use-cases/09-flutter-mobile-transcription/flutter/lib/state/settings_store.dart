import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../data/rt_protocol.dart';
import '../models/agent_personality_templates.dart';
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

  // ---- Real-Time (v4) — fully independent from Batch by design: language,
  // dictionary, punctuation, filtering etc. are separate values, never shared.
  String rtEndpointMode = 'auto'; // 'auto' (global) | 'eu' | 'us'
  String rtLanguage = 'en';
  String rtOperatingPoint = 'enhanced'; // 'enhanced' | 'standard'
  String rtDomain = 'none'; // 'none' | 'medical' | 'finance' (Enhanced only)
  bool rtPartials = true;
  bool rtDiarization = false;
  int rtMaxSpeakers = 50;
  double rtMaxDelay = 2.0; // 0.7–4.0 s
  String rtMaxDelayMode = 'flexible'; // 'flexible' | 'fixed'
  String rtOutputLocale = ''; // '', 'en-GB', 'en-US', 'en-AU' (en only)
  bool rtDisfluencyRemoval = false;
  bool rtCustomDict = false;
  String rtCustomDictText = '';
  bool rtPunctuation = true;
  double rtSensitivity = 0.5;
  Set<String> rtMarks = {'comma', 'period', 'question_mark', 'exclamation_mark'};
  bool rtAudioFiltering = false;
  double rtVolume = 4;
  // Google-powered, single target — the same pipeline Batch uses.
  // (Native RT translation stays in the protocol layer for a future Melia
  // engine, but the app no longer sends it.)
  bool rtTranslation = false;
  String rtTargetLanguageCode = 'en';
  String rtTargetLanguageName = 'English';
  bool rtAudioEvents = false;
  Set<String> rtEventTypes = {'laughter', 'music', 'applause'};

  // Agent personality is sent to the hosted agent when a new session starts.
  // Keep existing user instructions when retiring the old on-device runtime.
  String agentPersonalityTemplate = 'assistant';
  String agentPersonalityText = AgentPersonalityTemplates.assistant;

  // ---- persistence ----
  void _load() {
    final raw = _box.get(_key);
    if (raw is! String) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      mode = m['mode'] ?? mode;
      // Three-way settings body since v4; sanitize unknown values.
      if (!const {'batch', 'realtime', 'agent'}.contains(mode)) mode = 'batch';
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

      // v4 (Real-Time + Agent) — additive, defaults cover old installs.
      rtEndpointMode = m['rtEndpointMode'] ?? rtEndpointMode;
      if (!const {'auto', 'eu', 'us'}.contains(rtEndpointMode)) {
        rtEndpointMode = 'auto';
      }
      rtLanguage = m['rtLanguage'] ?? rtLanguage;
      rtOperatingPoint = m['rtOperatingPoint'] ?? rtOperatingPoint;
      rtDomain = m['rtDomain'] ?? rtDomain;
      if (!const {'none', 'medical', 'finance'}.contains(rtDomain)) {
        rtDomain = 'none';
      }
      rtPartials = m['rtPartials'] ?? rtPartials;
      rtDiarization = m['rtDiarization'] ?? rtDiarization;
      rtMaxSpeakers = (m['rtMaxSpeakers'] as num?)?.toInt() ?? rtMaxSpeakers;
      rtMaxDelay =
          ((m['rtMaxDelay'] as num?)?.toDouble() ?? rtMaxDelay).clamp(0.7, 4.0);
      rtMaxDelayMode = m['rtMaxDelayMode'] ?? rtMaxDelayMode;
      rtOutputLocale = m['rtOutputLocale'] ?? rtOutputLocale;
      rtDisfluencyRemoval = m['rtDisfluencyRemoval'] ?? rtDisfluencyRemoval;
      rtCustomDict = m['rtCustomDict'] ?? rtCustomDict;
      rtCustomDictText = m['rtCustomDictText'] ?? rtCustomDictText;
      rtPunctuation = m['rtPunctuation'] ?? rtPunctuation;
      rtSensitivity = (m['rtSensitivity'] as num?)?.toDouble() ?? rtSensitivity;
      rtMarks = (m['rtMarks'] as List?)?.cast<String>().toSet() ?? rtMarks;
      rtAudioFiltering = m['rtAudioFiltering'] ?? rtAudioFiltering;
      rtVolume = (m['rtVolume'] as num?)?.toDouble() ?? rtVolume;
      rtTranslation = m['rtTranslation'] ?? rtTranslation;
      rtTargetLanguageCode = m['rtTargetLanguageCode'] ?? rtTargetLanguageCode;
      rtTargetLanguageName = m['rtTargetLanguageName'] ?? rtTargetLanguageName;
      rtAudioEvents = m['rtAudioEvents'] ?? rtAudioEvents;
      rtEventTypes =
          (m['rtEventTypes'] as List?)?.cast<String>().toSet() ?? rtEventTypes;
      agentPersonalityTemplate =
          m['agentPersonalityTemplate'] ?? agentPersonalityTemplate;
      agentPersonalityText = m['agentPersonalityText'] ?? agentPersonalityText;

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
        'v': 6, // Hosted Agent; only personality remains in shared settings.
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
        // v4: Real-Time (independent of Batch) + Agent
        'rtEndpointMode': rtEndpointMode,
        'rtLanguage': rtLanguage,
        'rtOperatingPoint': rtOperatingPoint,
        'rtDomain': rtDomain,
        'rtPartials': rtPartials,
        'rtDiarization': rtDiarization,
        'rtMaxSpeakers': rtMaxSpeakers,
        'rtMaxDelay': rtMaxDelay,
        'rtMaxDelayMode': rtMaxDelayMode,
        'rtOutputLocale': rtOutputLocale,
        'rtDisfluencyRemoval': rtDisfluencyRemoval,
        'rtCustomDict': rtCustomDict,
        'rtCustomDictText': rtCustomDictText,
        'rtPunctuation': rtPunctuation,
        'rtSensitivity': rtSensitivity,
        'rtMarks': rtMarks.toList(),
        'rtAudioFiltering': rtAudioFiltering,
        'rtVolume': rtVolume,
        'rtTranslation': rtTranslation,
        'rtTargetLanguageCode': rtTargetLanguageCode,
        'rtTargetLanguageName': rtTargetLanguageName,
        'rtAudioEvents': rtAudioEvents,
        'rtEventTypes': rtEventTypes.toList(),
        'agentPersonalityTemplate': agentPersonalityTemplate,
        'agentPersonalityText': agentPersonalityText,
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

  // ---- Real-Time setters ----
  void setRtEndpointMode(String v) => _commit(() => rtEndpointMode = v);
  void setRtLanguage(String v) => _commit(() => rtLanguage = v);
  void setRtOperatingPoint(String v) => _commit(() => rtOperatingPoint = v);
  void setRtDomain(String v) => _commit(() => rtDomain = v);
  void setRtPartials(bool v) => _commit(() => rtPartials = v);
  void setRtDiarization(bool v) => _commit(() => rtDiarization = v);
  void setRtMaxSpeakers(int v) => _commit(() => rtMaxSpeakers = v.clamp(2, 100));
  void setRtMaxDelay(double v) => _commit(() => rtMaxDelay = v.clamp(0.7, 4.0));
  void setRtMaxDelayMode(String v) => _commit(() => rtMaxDelayMode = v);
  void setRtOutputLocale(String v) => _commit(() => rtOutputLocale = v);
  void setRtDisfluencyRemoval(bool v) => _commit(() => rtDisfluencyRemoval = v);
  void setRtCustomDict(bool v) => _commit(() => rtCustomDict = v);
  void setRtCustomDictText(String v) => _commit(() => rtCustomDictText = v);
  void setRtPunctuation(bool v) => _commit(() => rtPunctuation = v);
  void setRtSensitivity(double v) => _commit(() => rtSensitivity = v);
  void toggleRtMark(String id) =>
      _commit(() => rtMarks.contains(id) ? rtMarks.remove(id) : rtMarks.add(id));
  void setRtAudioFiltering(bool v) => _commit(() => rtAudioFiltering = v);
  void setRtVolume(double v) => _commit(() => rtVolume = v);
  void setRtTranslation(bool v) => _commit(() => rtTranslation = v);
  void setRtTarget(String code, String name) => _commit(() {
        rtTargetLanguageCode = code;
        rtTargetLanguageName = name;
      });
  void setRtAudioEvents(bool v) => _commit(() => rtAudioEvents = v);
  void toggleRtEventType(String id) => _commit(() =>
      rtEventTypes.contains(id) ? rtEventTypes.remove(id) : rtEventTypes.add(id));

  // ---- Agent personality ----
  void setAgentPersonality(String template, String text) => _commit(() {
        agentPersonalityTemplate = template;
        agentPersonalityText = text;
      });

  /// Session config for a standard-RT live session. RT settings are fully
  /// independent of Batch by design — nothing here reads batch fields.
  RtSessionConfig rtSnapshot() => RtSessionConfig(
        engine: LiveEngine.standard,
        language: rtLanguage,
        operatingPoint: rtOperatingPoint,
        // Domain packs are an Enhanced feature (probe-verified on batch:
        // standard rejects them) — drop silently on Standard.
        domain: rtOperatingPoint == 'enhanced' ? rtDomain : 'none',
        partials: rtPartials,
        diarization: rtDiarization,
        maxSpeakers: rtDiarization ? rtMaxSpeakers : null,
        maxDelay: rtMaxDelay,
        maxDelayMode: rtMaxDelayMode,
        outputLocale: rtLanguage == 'en' ? rtOutputLocale : '',
        disfluencyRemoval: rtDisfluencyRemoval,
        customDictWords: rtCustomDict
            ? rtCustomDictText
                .split(RegExp(r'[,\n]'))
                .map((w) => w.trim())
                .where((w) => w.isNotEmpty)
                .toList()
            : const [],
        punctuationEnabled: rtPunctuation,
        punctuationSensitivity: rtSensitivity,
        punctuationMarks: rtMarks.toList(),
        audioFiltering: rtAudioFiltering,
        volumeThreshold: rtVolume,
        // RT translation is Google-powered app-side; nothing native is sent.
        translationTargets: const [],
        eouTrigger: 0.8,
        audioEventTypes: rtAudioEvents ? rtEventTypes.toList() : const [],
        rtEndpointMode: rtEndpointMode,
      );

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
