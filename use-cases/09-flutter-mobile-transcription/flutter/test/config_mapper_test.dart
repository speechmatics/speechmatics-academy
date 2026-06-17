import 'package:flutter_test/flutter_test.dart';
import 'package:speechmatics_translate/data/config_mapper.dart';
import 'package:speechmatics_translate/models/job_config.dart';
import 'package:speechmatics_translate/models/speaker_profile.dart';

void main() {
  group('ConfigMapper', () {
    test('builds an omni-v1 transcription config with the expected keys', () {
      final cfg = ConfigMapper.build(JobConfig(
        languageMode: 'omnilingual',
        languageHints: ['EN', 'Es'], // mixed case -> lowercased
        diarization: true,
        diarizationType: 'speaker',
        punctuation: true,
        sensitivity: 0.5,
        marks: const ['comma', 'period'],
        translationEnabled: true,
        targetLanguageCode: 'fr',
        audioFiltering: false,
        audioEvents: false,
        customDictEnabled: false,
      ));

      expect(cfg['type'], 'transcription');
      final tc = cfg['transcription_config'] as Map<String, dynamic>;
      // Wire value is 'melia-1' (deployed schema rejects 'omni-v1' since
      // 2026-06-12; internal model id stays 'omni-v1').
      expect(tc['model'], 'melia-1');
      expect(tc['language'], 'multi');
      expect(tc['language_hints'], ['en', 'es']);
      expect(tc['diarization'], 'speaker');
      // Only the four omni-v1 keys are present.
      expect(tc.keys.toSet(), {'model', 'language', 'language_hints', 'diarization'});
    });

    test('never emits keys that omni-v1 rejects', () {
      // Even with every enhancement toggle ON, the omni-v1-unsupported keys
      // must be absent.
      final tc = ConfigMapper.build(JobConfig(
        translationEnabled: true,
        customDictEnabled: true,
        customDictText: 'gnocchi (nyohki)',
        audioFiltering: true,
        audioEvents: true,
      ))['transcription_config'] as Map<String, dynamic>;
      for (final rejected in const [
        'translation_config',
        'target_languages',
        'enable_entities',
        'summarization_config',
        'sentiment_analysis_config',
        'domain',
        'additional_vocab', // custom dictionary — not supported by omni-v1
        'audio_filtering', // audio volume filtering — not available
        'audio_events_config', // audio events — not available
        'punctuation_overrides', // punctuation is automatic, not configurable
      ]) {
        expect(tc.containsKey(rejected), isFalse, reason: '$rejected must not be present');
      }
    });

    test('strict hints emit language_hints_strict (only with hints)', () {
      final strict = ConfigMapper.build(JobConfig(
        languageHints: ['ru', 'en'],
        languageHintsStrict: true,
      ))['transcription_config'] as Map<String, dynamic>;
      expect(strict['language_hints'], ['ru', 'en']);
      expect(strict['language_hints_strict'], true);

      // No hints -> neither key, even if strict is on.
      final noHints = ConfigMapper.build(JobConfig(
        languageHints: const [],
        languageHintsStrict: true,
      ))['transcription_config'] as Map<String, dynamic>;
      expect(noHints.containsKey('language_hints'), isFalse);
      expect(noHints.containsKey('language_hints_strict'), isFalse);
    });

    test('all selected hints are sent — 3 hints + strict, none dropped', () {
      // Mirrors the field report: pick 3 languages with strict on. The app must
      // send all 3 (the model then decides which actually appear in the audio).
      final tc = ConfigMapper.build(JobConfig(
        languageMode: 'omnilingual',
        languageHints: ['EN', 'es', 'Ru'], // mixed case in, lowercased out
        languageHintsStrict: true,
      ))['transcription_config'] as Map<String, dynamic>;
      expect(tc['language_hints'], ['en', 'es', 'ru']);
      expect((tc['language_hints'] as List).length, 3);
      expect(tc['language_hints_strict'], true);
    });

    test('single language sets language code and omits empty hints', () {
      final tc = ConfigMapper.build(
              JobConfig(languageMode: 'single', singleLanguage: 'DE', languageHints: const []))[
          'transcription_config'] as Map<String, dynamic>;
      expect(tc['language'], 'de');
      expect(tc.containsKey('language_hints'), isFalse);
    });

    test('parseVocab handles content + sounds_like', () {
      final v = ConfigMapper.parseVocab('gnocchi (nyohki, nochi), CEO');
      expect(v.length, 2);
      expect(v[0]['content'], 'gnocchi');
      expect(v[0]['sounds_like'], ['nyohki', 'nochi']);
      expect(v[1]['content'], 'CEO');
      expect(v[1].containsKey('sounds_like'), isFalse);
    });

    test('omni regression: explicit model + classic toggles on → still omni 4 keys', () {
      final tc = ConfigMapper.build(JobConfig(
        model: 'omni-v1',
        languageHints: ['en'],
        customDictEnabled: true,
        customDictText: 'gnocchi',
        audioFiltering: true,
        audioEvents: true,
        punctuation: true,
      ))['transcription_config'] as Map<String, dynamic>;
      expect(tc.keys.toSet(), {'model', 'language', 'language_hints', 'diarization'});
    });
  });

  group('ConfigMapper classic (standard/enhanced)', () {
    test('defaults to auto language identification; hints are Melia-1-only', () {
      for (final m in ['standard', 'enhanced']) {
        final body = ConfigMapper.build(JobConfig(
          model: m,
          languageMode: 'omnilingual', // omni preference preserved but ignored
          singleLanguage: 'DE', // omni preference, never used by classic
          languageHints: ['EN', 'es', 'LV'], // omni-only — never emitted here
          languageHintsStrict: true,
          diarization: true,
          diarizationType: 'speaker',
          customDictEnabled: false,
          audioFiltering: false,
          audioEvents: false,
          punctuation: true,
          sensitivity: 0.5,
          marks: const ['comma', 'period'],
        ));
        final tc = body['transcription_config'] as Map<String, dynamic>;
        // Classic uses the same `model` param as Melia-1 — the API normalizes
        // it to operating_point internally (read-back verified 2026-06-12).
        expect(tc['model'], m);
        expect(tc['language'], 'auto'); // classic defaults to auto-detect
        expect(tc.containsKey('operating_point'), isFalse);
        expect(tc.containsKey('language_hints'), isFalse);
        expect(tc.containsKey('language_hints_strict'), isFalse);
        expect(body.containsKey('language_identification_config'), isFalse,
            reason: 'language hints are a Melia-1 feature — classic auto is unbiased');
        expect(tc.keys.toSet(),
            {'language', 'model', 'diarization', 'punctuation_overrides'});
      }
    });

    test('specific language uses the classic catalog id', () {
      final tc = ConfigMapper.build(JobConfig(
        model: 'standard',
        classicLanguageMode: 'specific',
        classicLanguage: 'lv',
        languageHints: ['en'], // hints only apply to auto mode
      ));
      final inner = tc['transcription_config'] as Map<String, dynamic>;
      expect(inner['language'], 'lv');
      expect(inner.containsKey('domain'), isFalse);
      expect(tc.containsKey('language_identification_config'), isFalse);
    });

    test('bilingual packs pass through; Spanish & English adds domain', () {
      final pack = ConfigMapper.build(JobConfig(
        model: 'enhanced',
        classicLanguageMode: 'specific',
        classicLanguage: 'cmn_en_ms_ta',
      ))['transcription_config'] as Map<String, dynamic>;
      expect(pack['language'], 'cmn_en_ms_ta');
      expect(pack.containsKey('domain'), isFalse);

      final es = ConfigMapper.build(JobConfig(
        model: 'enhanced',
        classicLanguageMode: 'specific',
        classicLanguage: 'es-bilingual',
      ))['transcription_config'] as Map<String, dynamic>;
      expect(es['language'], 'es');
      expect(es['domain'], 'bilingual-en');
    });

    test('additional_vocab: enabled+text emits, empty/disabled omits', () {
      Map<String, dynamic> tc({required bool enabled, required String text}) =>
          ConfigMapper.build(JobConfig(
            model: 'enhanced',
            customDictEnabled: enabled,
            customDictText: text,
          ))['transcription_config'] as Map<String, dynamic>;

      final withVocab = tc(enabled: true, text: 'gnocchi (nyohki), CEO');
      expect(withVocab['additional_vocab'], [
        {'content': 'gnocchi', 'sounds_like': ['nyohki']},
        {'content': 'CEO'},
      ]);
      expect(tc(enabled: true, text: '   ').containsKey('additional_vocab'), isFalse);
      expect(tc(enabled: false, text: 'gnocchi').containsKey('additional_vocab'), isFalse);
    });

    test('punctuation_overrides: marks→symbols + sensitivity; off → empty marks', () {
      final on = ConfigMapper.build(JobConfig(
        model: 'standard',
        punctuation: true,
        sensitivity: 0.7,
        marks: const ['comma', 'question_mark'],
      ))['transcription_config'] as Map<String, dynamic>;
      expect(on['punctuation_overrides'],
          {'permitted_marks': [',', '?'], 'sensitivity': 0.7});

      final off = ConfigMapper.build(JobConfig(model: 'standard', punctuation: false))[
          'transcription_config'] as Map<String, dynamic>;
      expect(off['punctuation_overrides'], {'permitted_marks': <String>[]});
    });

    test('audio_filtering_config inside transcription_config when enabled', () {
      final on = ConfigMapper.build(JobConfig(
        model: 'enhanced',
        audioFiltering: true,
        volumeThreshold: 12,
      ))['transcription_config'] as Map<String, dynamic>;
      expect(on['audio_filtering_config'], {'volume_threshold': 12});

      final off = ConfigMapper.build(JobConfig(model: 'enhanced', audioFiltering: false))[
          'transcription_config'] as Map<String, dynamic>;
      expect(off.containsKey('audio_filtering_config'), isFalse);
    });

    test('audio filtering defaults are safe: OFF, low threshold', () {
      // Threshold 50 filters out ALL speech (verified live: 0 results vs 37
      // at threshold 4) — the destructive old default must never come back.
      const c = JobConfig(model: 'standard');
      expect(c.audioFiltering, isFalse);
      expect(c.volumeThreshold, lessThanOrEqualTo(10));
      final tc = ConfigMapper.build(c)['transcription_config'] as Map<String, dynamic>;
      expect(tc.containsKey('audio_filtering_config'), isFalse);
    });

    test('audio_events_config at TOP LEVEL when enabled', () {
      final on = ConfigMapper.build(JobConfig(
        model: 'standard',
        audioEvents: true,
        eventTypes: const ['laughter', 'music'],
      ));
      expect(on['audio_events_config'], {'types': ['laughter', 'music']});
      expect((on['transcription_config'] as Map).containsKey('audio_events_config'), isFalse);

      final off = ConfigMapper.build(JobConfig(model: 'standard', audioEvents: false));
      expect(off.containsKey('audio_events_config'), isFalse);
    });

    test('classic never emits forbidden/SI keys', () {
      final body = ConfigMapper.build(JobConfig(
        model: 'enhanced',
        translationEnabled: true,
        customDictEnabled: true,
        customDictText: 'x',
        audioFiltering: true,
        audioEvents: true,
      ));
      final tc = body['transcription_config'] as Map<String, dynamic>;
      expect(tc['model'], 'enhanced'); // same param as Melia-1 (API-normalized)
      for (final k in const [
        'operating_point', // replaced by model
        'language_hints',
        'language_hints_strict',
        'translation_config',
        'summarization_config',
        'sentiment_analysis_config',
        'topic_detection_config',
        'auto_chapters_config',
      ]) {
        expect(tc.containsKey(k), isFalse, reason: '$k must not be in transcription_config');
        expect(body.containsKey(k), isFalse, reason: '$k must not be top-level');
      }
    });

    test('domain: enhanced + specific language emits; gated everywhere else', () {
      Map<String, dynamic> tc(
              {String model = 'enhanced',
              String mode = 'specific',
              String lang = 'en',
              String domain = 'medical'}) =>
          ConfigMapper.build(JobConfig(
            model: model,
            classicLanguageMode: mode,
            classicLanguage: lang,
            domain: domain,
          ))['transcription_config'] as Map<String, dynamic>;

      expect(tc()['domain'], 'medical');
      expect(tc(domain: 'finance')['domain'], 'finance');
      expect(tc(domain: 'none').containsKey('domain'), isFalse);
      // Standard has no domains (live: "Domain medical is not supported for en-standard").
      expect(tc(model: 'standard').containsKey('domain'), isFalse);
      // Domains need a specific language (live: "Languagepack 'auto-medical' is not supported").
      expect(tc(mode: 'auto').containsKey('domain'), isFalse);
      // A bilingual pack's own domain wins over the user selection.
      expect(tc(lang: 'es-bilingual')['domain'], 'bilingual-en');
    });

    test('omni-v1 never emits domain (strict v3 schema rejects it)', () {
      final tc = ConfigMapper.build(JobConfig(model: 'omni-v1', domain: 'medical'))[
          'transcription_config'] as Map<String, dynamic>;
      expect(tc.containsKey('domain'), isFalse);
    });

    test('speaker identification: emitted only with profiles + toggle + speaker diarization', () {
      const profile = SpeakerProfile(id: 'p1', name: 'Edgars A', identifiers: ['id1', 'id2']);
      Map<String, dynamic> tc({
        String model = 'enhanced',
        bool toggle = true,
        bool diarization = true,
        String type = 'speaker',
        List<SpeakerProfile> speakers = const [profile],
      }) =>
          ConfigMapper.build(JobConfig(
            model: model,
            speakerIdentification: toggle,
            diarization: diarization,
            diarizationType: type,
            speakers: speakers,
          ))['transcription_config'] as Map<String, dynamic>;

      expect(tc()['speaker_diarization_config'], {
        'speakers': [
          {'label': 'Edgars A', 'speaker_identifiers': ['id1', 'id2']},
        ],
        // The deployed param is speaker_sensitivity (the documented
        // speakers_sensitivity is rejected by the schema — probe-verified).
        'speaker_sensitivity': 0.5,
      });
      // Works on standard too (block accepted; matching is best on enhanced).
      expect(tc(model: 'standard').containsKey('speaker_diarization_config'), isTrue);
      // Custom sensitivity flows through.
      final custom = ConfigMapper.build(JobConfig(
        model: 'enhanced',
        speakers: const [profile],
        speakerSensitivity: 0.2,
      ))['transcription_config'] as Map<String, dynamic>;
      expect((custom['speaker_diarization_config'] as Map)['speaker_sensitivity'], 0.2);
      // Gated off in every other combination.
      expect(tc(toggle: false).containsKey('speaker_diarization_config'), isFalse);
      expect(tc(speakers: const []).containsKey('speaker_diarization_config'), isFalse);
      expect(tc(diarization: false).containsKey('speaker_diarization_config'), isFalse);
      expect(tc(type: 'channel').containsKey('speaker_diarization_config'), isFalse);
      // omni-v1 accepts the block but IGNORES it (probe-verified) — never sent.
      expect(tc(model: 'omni-v1').containsKey('speaker_diarization_config'), isFalse);
    });

    test('buildEnrollment emits the exact probe-verified shape', () {
      expect(ConfigMapper.buildEnrollment(), {
        'type': 'transcription',
        'transcription_config': {
          'model': 'enhanced',
          'language': 'en',
          'diarization': 'speaker',
          'speaker_diarization_config': {'get_speakers': true},
        },
      });
    });

    test('speech intelligence blocks emitted top-level when enabled (classic)', () {
      final body = ConfigMapper.build(JobConfig(
        model: 'enhanced',
        summaryEnabled: true,
        summaryType: 'paragraphs',
        summaryLength: 'detailed',
        topicsEnabled: true,
        topicsText: 'cooking, space travel, ',
        chaptersEnabled: true,
        subtitlesEnabled: true,
        subtitleMaxLineLength: 30,
        subtitleMaxLines: 1,
      ));
      expect(body['summarization_config'],
          {'content_type': 'auto', 'summary_length': 'detailed', 'summary_type': 'paragraphs'});
      expect(body['topic_detection_config'], {'topics': ['cooking', 'space travel']});
      expect(body['auto_chapters_config'], <String, dynamic>{});
      expect(body['output_config'],
          {'srt_overrides': {'max_line_length': 30, 'max_lines': 1}});
      // None of them leak into transcription_config.
      final tc = body['transcription_config'] as Map<String, dynamic>;
      for (final k in const [
        'summarization_config', 'topic_detection_config', 'auto_chapters_config', 'output_config'
      ]) {
        expect(tc.containsKey(k), isFalse);
      }
    });

    test('topics without seeds emits empty config; SI off emits nothing', () {
      final seeded = ConfigMapper.build(JobConfig(model: 'standard', topicsEnabled: true));
      expect(seeded['topic_detection_config'], <String, dynamic>{});

      final off = ConfigMapper.build(JobConfig(model: 'standard'));
      for (final k in const [
        'summarization_config', 'topic_detection_config', 'auto_chapters_config', 'output_config'
      ]) {
        expect(off.containsKey(k), isFalse, reason: '$k must be absent when disabled');
      }
    });

    test('omni-v1 never emits SI blocks even with all flags on', () {
      final body = ConfigMapper.build(JobConfig(
        model: 'omni-v1',
        summaryEnabled: true,
        topicsEnabled: true,
        chaptersEnabled: true,
        subtitlesEnabled: true,
      ));
      for (final k in const [
        'summarization_config', 'topic_detection_config', 'auto_chapters_config', 'output_config'
      ]) {
        expect(body.containsKey(k), isFalse, reason: '$k must never reach omni-v1');
      }
    });

    test('parseTopics handles commas, whitespace, empties', () {
      expect(ConfigMapper.parseTopics(''), isEmpty);
      expect(ConfigMapper.parseTopics('  ,  , '), isEmpty);
      expect(ConfigMapper.parseTopics('a, b , c,'), ['a', 'b', 'c']);
    });

    test('displayNameFor maps api ids to display names', () {
      expect(JobConfig.displayNameFor('omni-v1'), 'Melia-1');
      expect(JobConfig.displayNameFor('standard'), 'Standard');
      expect(JobConfig.displayNameFor('enhanced'), 'Enhanced');
      expect(JobConfig(model: 'enhanced').modelDisplayName, 'Enhanced');
      expect(const JobConfig().isClassic, isFalse);
      expect(JobConfig(model: 'standard').isClassic, isTrue);
    });
  });
}
