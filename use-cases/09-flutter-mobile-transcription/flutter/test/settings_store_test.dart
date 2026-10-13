import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:speechmatics_translate/data/rt_protocol.dart';
import 'package:speechmatics_translate/models/agent_personality_templates.dart';
import 'package:speechmatics_translate/state/settings_store.dart';

void main() {
  late Directory tmp;
  var boxSeq = 0;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('settings_store_test');
    Hive.init(tmp.path);
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<Box> freshBox() async => Hive.openBox('settings_test_${boxSeq++}');

  group('defaults (v4)', () {
    test('RT fields start at their documented defaults', () async {
      final s = SettingsStore(await freshBox());
      expect(s.mode, 'batch');
      expect(s.rtEndpointMode, 'auto');
      expect(s.rtLanguage, 'en');
      expect(s.rtOperatingPoint, 'enhanced');
      expect(s.rtPartials, isTrue);
      expect(s.rtDiarization, isFalse);
      expect(s.rtMaxSpeakers, 50);
      expect(s.rtMaxDelay, 2.0);
      expect(s.rtMaxDelayMode, 'flexible');
      expect(s.rtOutputLocale, '');
      expect(s.rtTranslation, isFalse);
      expect(s.rtTargetLanguageCode, 'en');
    });
  });

  group('persistence roundtrip', () {
    test('legacy Agent migration preserves Batch, Home LIVE and personality',
        () async {
      final box = await freshBox();
      await box.put(
          'config',
          jsonEncode({
            'v': 4,
            'mode': 'agent',
            'region': 'us1',
            'model': 'enhanced',
            'classicLanguage': 'lv',
            'diarization': false,
            'speakerSensitivity': 0.3,
            'translation': true,
            'targetLanguageCode': 'es',
            'targetLanguageName': 'Spanish',
            'rtEndpointMode': 'eu',
            'rtLanguage': 'de',
            'rtOperatingPoint': 'standard',
            'rtDiarization': true,
            'rtMaxSpeakers': 7,
            'rtMaxDelay': 1.5,
            'rtTranslation': true,
            'rtTargetLanguageCode': 'lv',
            'rtTargetLanguageName': 'Latvian',
            'agentPersonalityTemplate': 'custom',
            'agentPersonalityText': '# Role\nPreserve my instructions.',
            'agentEouMode': 'adaptive',
            'agentEouTrigger': 0.2,
            'agentVoiceId': 'theo',
            'agentFocusSpeakers': ['S1'],
            'agentTranslation': true,
            'agentPersonalityApplyLive': true,
          }));

      final s = SettingsStore(box);
      // An ordinary settings write migrates the old payload without a reset.
      s.setMode('realtime');
      final reloaded = SettingsStore(box);
      expect(reloaded.region, 'us1');
      expect(reloaded.model, 'enhanced');
      expect(reloaded.classicLanguage, 'lv');
      expect(reloaded.diarization, isFalse);
      expect(reloaded.speakerSensitivity, 0.3);
      expect(reloaded.translation, isTrue);
      expect(reloaded.targetLanguageCode, 'es');
      expect(reloaded.targetLanguageName, 'Spanish');
      expect(reloaded.rtTranslation, isTrue);
      expect(reloaded.rtTargetLanguageCode, 'lv');
      expect(reloaded.rtTargetLanguageName, 'Latvian');
      expect(reloaded.agentPersonalityTemplate, 'custom');
      expect(
          reloaded.agentPersonalityText, '# Role\nPreserve my instructions.');

      final wire =
          buildStartRecognition(reloaded.rtSnapshot(), sampleRate: 16000);
      final config = wire['transcription_config'] as Map;
      expect(reloaded.rtSnapshot().endpoint, 'wss://eu.rt.speechmatics.com/v2');
      expect(config['language'], 'de');
      expect(config['operating_point'], 'standard');
      expect(config['diarization'], 'speaker');
      expect(config['speaker_diarization_config'], {'max_speakers': 7});
      expect(config['max_delay'], 1.5);
      expect(config['conversation_config'],
          {'end_of_utterance_silence_trigger': 0.8});
      expect(wire.containsKey('translation_config'), isFalse);

      final persisted = jsonDecode(box.get('config') as String) as Map;
      expect(
          persisted.keys.where((key) => key.toString().startsWith('agent')),
          unorderedEquals(
              ['agentPersonalityTemplate', 'agentPersonalityText']));
    });

    test('v4 fields survive a store reload from the same box', () async {
      final box = await freshBox();
      final s = SettingsStore(box);
      s.setMode('agent'); // three-way toggle persists
      s.setRtEndpointMode('us');
      s.setRtLanguage('lv');
      s.setRtOperatingPoint('standard');
      s.setRtDiarization(true);
      s.setRtMaxSpeakers(7);
      s.setRtMaxDelay(0.9);
      s.setRtMaxDelayMode('fixed');
      s.setRtCustomDict(true);
      s.setRtCustomDictText('Speechmatics, EveryVoice');
      s.setRtPunctuation(false);
      s.setRtTranslation(true);
      s.setRtTarget('es', 'Spanish');
      s.setRtAudioEvents(true);

      final reloaded = SettingsStore(box);
      expect(reloaded.mode, 'agent');
      expect(reloaded.rtEndpointMode, 'us');
      expect(reloaded.rtLanguage, 'lv');
      expect(reloaded.rtOperatingPoint, 'standard');
      expect(reloaded.rtDiarization, isTrue);
      expect(reloaded.rtMaxSpeakers, 7);
      expect(reloaded.rtMaxDelay, 0.9);
      expect(reloaded.rtMaxDelayMode, 'fixed');
      expect(reloaded.rtCustomDict, isTrue);
      expect(reloaded.rtCustomDictText, 'Speechmatics, EveryVoice');
      expect(reloaded.rtPunctuation, isFalse);
      expect(reloaded.rtTranslation, isTrue);
      expect(reloaded.rtTargetLanguageCode, 'es');
      expect(reloaded.rtTargetLanguageName, 'Spanish');
    });

    test('old pre-RT blobs load with v4 defaults intact', () async {
      final box = await freshBox();
      // A v2-era blob: no rt*/agent* keys at all.
      await box.put(
          'config',
          jsonEncode({
            'v': 2,
            'mode': 'batch',
            'region': 'us1',
            'model': 'enhanced',
          }));
      final s = SettingsStore(box);
      expect(s.region, 'us1');
      expect(s.model, 'enhanced');
      expect(s.rtEndpointMode, 'auto');
      expect(s.rtLanguage, 'en');
    });

    test('agent personality persists (agent.md)', () async {
      final box = await freshBox();
      final s = SettingsStore(box);
      expect(s.agentPersonalityTemplate, 'assistant');
      expect(s.agentPersonalityText, AgentPersonalityTemplates.assistant);

      s.setAgentPersonality('custom', '# Role\nYou are a pirate concierge.');

      final r = SettingsStore(box);
      expect(r.agentPersonalityTemplate, 'custom');
      expect(r.agentPersonalityText, contains('pirate'));
    });

    test('unknown mode and endpoint values sanitize to safe defaults',
        () async {
      final box = await freshBox();
      await box.put(
          'config',
          jsonEncode({
            'v': 4,
            'mode': 'wat',
            'rtEndpointMode': 'mars',
          }));
      final s = SettingsStore(box);
      expect(s.mode, 'batch');
      expect(s.rtEndpointMode, 'auto');
    });
  });

  group('snapshots', () {
    test('rtSnapshot maps independent RT settings only', () async {
      final s = SettingsStore(await freshBox());
      s.setRtLanguage('en');
      s.setRtOutputLocale('en-GB');
      s.setRtDiarization(true);
      s.setRtMaxSpeakers(4);
      s.setRtCustomDict(true);
      s.setRtCustomDictText(' Speechmatics,EveryVoice \n Latvia , ');
      s.setRtTranslation(true);
      s.setRtTarget('es', 'Spanish');
      s.setRtAudioEvents(true);
      s.setRtEndpointMode('eu');

      final c = s.rtSnapshot();
      expect(c.engine.mode, LiveMode.standard);
      expect(c.language, 'en');
      expect(c.outputLocale, 'en-GB');
      expect(c.maxSpeakers, 4);
      expect(c.customDictWords, ['Speechmatics', 'EveryVoice', 'Latvia']);
      // RT translation is Google-powered app-side — the wire config never
      // carries native translation ("Feature Validation Failed" class of
      // rejections can't happen).
      expect(c.translationTargets, isEmpty);
      expect(c.audioEventTypes, isNotEmpty);
      expect(c.rtEndpointMode, 'eu');
      expect(c.endpoint, contains('eu.rt.speechmatics.com'));
    });

    test('rtSnapshot gates domain on Enhanced accuracy', () async {
      final s = SettingsStore(await freshBox());
      s.setRtDomain('medical');
      s.setRtOperatingPoint('enhanced');
      expect(s.rtSnapshot().domain, 'medical');
      // Standard rejects domain packs (probe-verified on batch) — dropped.
      s.setRtOperatingPoint('standard');
      expect(s.rtSnapshot().domain, 'none');
    });

    test('rtSnapshot drops locale for non-English sources', () async {
      final s = SettingsStore(await freshBox());
      s.setRtLanguage('lv');
      s.setRtOutputLocale('en-GB'); // stale value from an earlier en session
      s.setRtCustomDict(false);
      s.setRtCustomDictText('Ignored words');

      final c = s.rtSnapshot();
      expect(c.outputLocale, '');
      expect(c.customDictWords, isEmpty);
    });
  });
}
