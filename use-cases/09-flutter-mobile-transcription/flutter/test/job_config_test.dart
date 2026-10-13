import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:speechmatics_translate/models/job_config.dart';
import 'package:speechmatics_translate/models/speaker_profile.dart';

void main() {
  group('JobConfig serialization', () {
    test('round-trips every field through JSON', () {
      const config = JobConfig(
        model: 'enhanced',
        region: 'us1',
        languageMode: 'single',
        singleLanguage: 'de',
        classicLanguageMode: 'specific',
        classicLanguage: 'en_medical',
        domain: 'medical',
        languageHints: ['en', 'de'],
        languageHintsStrict: true,
        diarization: false,
        diarizationType: 'channel',
        customDictEnabled: true,
        customDictText: 'Speechmatics, Melia',
        translationEnabled: false,
        targetLanguageCode: 'fr',
        targetLanguageName: 'French',
        audioFiltering: true,
        volumeThreshold: 2.5,
        punctuation: false,
        sensitivity: 0.8,
        marks: ['comma'],
        audioEvents: true,
        eventTypes: ['music'],
        subtitlesEnabled: true,
        subtitleMaxLineLength: 42,
        subtitleMaxLines: 3,
        summaryEnabled: true,
        summaryType: 'paragraphs',
        summaryLength: 'detailed',
        topicsEnabled: true,
        topicsText: 'billing, support',
        chaptersEnabled: true,
        speakers: [
          SpeakerProfile(id: 's1', name: 'Edgar', identifiers: ['abc']),
        ],
        speakerIdentification: false,
        speakerSensitivity: 0.3,
      );

      final back = JobConfig.fromJson(
          (jsonDecode(jsonEncode(config.toJson())) as Map).cast<String, dynamic>());

      expect(back.model, 'enhanced');
      expect(back.region, 'us1');
      expect(back.languageMode, 'single');
      expect(back.singleLanguage, 'de');
      expect(back.classicLanguageMode, 'specific');
      expect(back.classicLanguage, 'en_medical');
      expect(back.domain, 'medical');
      expect(back.languageHints, ['en', 'de']);
      expect(back.languageHintsStrict, isTrue);
      expect(back.diarization, isFalse);
      expect(back.diarizationType, 'channel');
      expect(back.customDictEnabled, isTrue);
      expect(back.customDictText, 'Speechmatics, Melia');
      expect(back.translationEnabled, isFalse);
      expect(back.targetLanguageCode, 'fr');
      expect(back.targetLanguageName, 'French');
      expect(back.audioFiltering, isTrue);
      expect(back.volumeThreshold, 2.5);
      expect(back.punctuation, isFalse);
      expect(back.sensitivity, 0.8);
      expect(back.marks, ['comma']);
      expect(back.audioEvents, isTrue);
      expect(back.eventTypes, ['music']);
      expect(back.subtitlesEnabled, isTrue);
      expect(back.subtitleMaxLineLength, 42);
      expect(back.subtitleMaxLines, 3);
      expect(back.summaryEnabled, isTrue);
      expect(back.summaryType, 'paragraphs');
      expect(back.summaryLength, 'detailed');
      expect(back.topicsEnabled, isTrue);
      expect(back.topicsText, 'billing, support');
      expect(back.chaptersEnabled, isTrue);
      expect(back.speakers.single.name, 'Edgar');
      expect(back.speakers.single.identifiers, ['abc']);
      expect(back.speakerIdentification, isFalse);
      expect(back.speakerSensitivity, 0.3);
    });

    test('fromJson tolerates an empty map (all defaults)', () {
      final config = JobConfig.fromJson(const {});
      const d = JobConfig();
      expect(config.model, d.model);
      expect(config.region, d.region);
      expect(config.diarization, d.diarization);
      expect(config.marks, d.marks);
      expect(config.speakers, isEmpty);
    });

    test('fromJson tolerates malformed field types', () {
      final config = JobConfig.fromJson(const {
        'model': 'enhanced',
        'languageHints': 'not-a-list',
        'volumeThreshold': 'NaNish',
        'speakers': [
          {'bogus': true},
        ],
      });
      expect(config.model, 'enhanced');
      expect(config.languageHints, const JobConfig().languageHints);
      expect(config.volumeThreshold, const JobConfig().volumeThreshold);
      expect(config.speakers, isEmpty);
    });
  });
}
