// Prints the exact ConfigMapper output for live-probe verification.
// Usage: dart run tool/print_configs.dart
// ignore_for_file: avoid_print — printing is this tool's entire job.
import 'dart:convert';

import 'package:speechmatics_translate/data/config_mapper.dart';
import 'package:speechmatics_translate/models/job_config.dart';
import 'package:speechmatics_translate/models/speaker_profile.dart';

void main() {
  final scenarios = <String, JobConfig>{
    'standard-everything-on': JobConfig(
      model: 'standard',
      singleLanguage: 'en',
      diarization: true,
      diarizationType: 'speaker',
      customDictEnabled: true,
      customDictText: 'gnocchi (nyohki, nochi), Speechmatics',
      punctuation: true,
      sensitivity: 0.5,
      marks: const ['comma', 'period', 'question_mark', 'exclamation_mark'],
      audioFiltering: true,
      volumeThreshold: 50,
      audioEvents: true,
      eventTypes: const ['laughter', 'music', 'applause'],
    ),
    'enhanced-punctuation-off': JobConfig(
      model: 'enhanced',
      singleLanguage: 'de',
      diarization: true,
      punctuation: false,
      customDictEnabled: false,
      audioFiltering: false,
      audioEvents: false,
    ),
    'omni-v1-defaults': JobConfig(
      languageHints: const ['en', 'es', 'ru'],
      languageHintsStrict: true,
      diarization: true,
    ),
    'enhanced-auto-with-expected': JobConfig(
      model: 'enhanced',
      classicLanguageMode: 'auto',
      languageHints: const ['en', 'lv', 'ru'],
      diarization: true,
    ),
    'standard-es-bilingual': JobConfig(
      model: 'standard',
      classicLanguageMode: 'specific',
      classicLanguage: 'es-bilingual',
    ),
    'enhanced-medical-en': JobConfig(
      model: 'enhanced',
      classicLanguageMode: 'specific',
      classicLanguage: 'en',
      domain: 'medical',
      diarization: true,
    ),
    'enhanced-identify-speakers': JobConfig(
      model: 'enhanced',
      classicLanguageMode: 'specific',
      classicLanguage: 'en',
      diarization: true,
      diarizationType: 'speaker',
      speakers: const [
        SpeakerProfile(id: 'spk1', name: 'Edgars A', identifiers: ['IDENTIFIER_PLACEHOLDER']),
      ],
    ),
    'enhanced-si-everything-on': JobConfig(
      model: 'enhanced',
      singleLanguage: 'en',
      diarization: true,
      summaryEnabled: true,
      summaryType: 'bullets',
      summaryLength: 'brief',
      topicsEnabled: true,
      topicsText: 'cooking, space',
      chaptersEnabled: true,
      subtitlesEnabled: true,
      subtitleMaxLineLength: 30,
      subtitleMaxLines: 1,
      audioEvents: true,
      eventTypes: const ['laughter', 'music', 'applause'],
    ),
  };
  scenarios.forEach((name, cfg) {
    print('===$name===');
    print(jsonEncode(ConfigMapper.build(cfg)));
  });
}
