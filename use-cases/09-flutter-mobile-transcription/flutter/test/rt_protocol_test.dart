import 'package:flutter_test/flutter_test.dart';
import 'package:speechmatics_translate/app_config.dart';
import 'package:speechmatics_translate/data/rt_protocol.dart';

void main() {
  group('parseRtMessage — standard RT vocabulary', () {
    test('RecognitionStarted carries id + language description', () {
      final e = parseRtMessage({
        'message': 'RecognitionStarted',
        'id': 'abc-123',
        'language_pack_info': {'language_description': 'English'},
      });
      expect(e, isA<RecognitionStartedEvent>());
      final r = e as RecognitionStartedEvent;
      expect(r.id, 'abc-123');
      expect(r.languageDescription, 'English');
    });

    test('AddPartialTranscript uses metadata.transcript', () {
      final e = parseRtMessage({
        'message': 'AddPartialTranscript',
        'metadata': {'transcript': 'hello wor'},
      });
      expect((e as PartialTranscriptEvent).transcript, 'hello wor');
    });

    test('AddTranscript extracts words with speaker + times', () {
      final e = parseRtMessage({
        'message': 'AddTranscript',
        'metadata': {'transcript': 'Hello world. ', 'end_time': 2.4},
        'results': [
          {
            'type': 'word',
            'start_time': 0.2,
            'end_time': 0.6,
            'alternatives': [
              {'content': 'Hello', 'speaker': 'S1'}
            ],
          },
          {
            'type': 'punctuation',
            'alternatives': [
              {'content': '.'}
            ],
          },
          {
            'type': 'word',
            'start_time': 0.7,
            'end_time': 1.1,
            'alternatives': [
              {'content': 'world', 'speaker': 'S1'}
            ],
          },
        ],
      });
      final t = e as FinalTranscriptEvent;
      expect(t.transcript, 'Hello world. ');
      expect(t.endTime, 2.4);
      expect(t.words, hasLength(2)); // punctuation results are not words
      expect(t.words.first.content, 'Hello');
      expect(t.words.first.speaker, 'S1');
      expect(t.words.first.start, 0.2);
    });

    test('EndOfUtterance carries times', () {
      final e = parseRtMessage({
        'message': 'EndOfUtterance',
        'metadata': {'start_time': 1.0, 'end_time': 1.5},
      });
      final u = e as EndOfUtteranceEvent;
      expect(u.startTime, 1.0);
      expect(u.endTime, 1.5);
    });

    test('translation events: metadata.transcript primary, results fallback',
        () {
      final f = parseRtMessage({
        'message': 'AddTranslation',
        'language': 'es',
        'metadata': {'transcript': 'Hola mundo. '},
      }) as FinalTranslationEvent;
      expect(f.language, 'es');
      expect(f.transcript, 'Hola mundo. ');

      final p = parseRtMessage({
        'message': 'AddPartialTranslation',
        'language': 'de',
        'results': [
          {'content': 'Hallo'},
          {'content': 'Welt'},
        ],
      }) as PartialTranslationEvent;
      expect(p.language, 'de');
      expect(p.transcript, 'Hallo Welt');
    });

    test('audio events carry type + time', () {
      final s = parseRtMessage({
        'message': 'AudioEventStarted',
        'event': {'type': 'music', 'start_time': 12.5, 'confidence': 0.9},
      }) as AudioEventStartedEvent;
      expect(s.type, 'music');
      expect(s.time, 12.5);

      final e = parseRtMessage({
        'message': 'AudioEventEnded',
        'event': {'type': 'music', 'end_time': 19.0},
      }) as AudioEventEndedEvent;
      expect(e.type, 'music');
      expect(e.time, 19.0);
    });

    test('lifecycle + admin messages', () {
      expect(parseRtMessage({'message': 'AudioAdded', 'seq_no': 17}),
          isA<AudioAddedEvent>());
      expect(
          (parseRtMessage({'message': 'AudioAdded', 'seq_no': 17})
                  as AudioAddedEvent)
              .seqNo,
          17);
      expect(
          parseRtMessage({'message': 'Info', 'type': 'recognition_quality', 'reason': 'ok'}),
          isA<InfoEvent>());
      expect(parseRtMessage({'message': 'Warning', 'type': 'duration_limit_exceeded', 'reason': 'w'}),
          isA<WarningEvent>());
      final err = parseRtMessage(
          {'message': 'Error', 'type': 'not_authorised', 'reason': 'bad key'});
      expect((err as RtErrorEvent).type, 'not_authorised');
      expect(parseRtMessage({'message': 'EndOfTranscript'}),
          isA<EndOfTranscriptEvent>());
    });
  });

  group('parseRtMessage — robustness', () {
    test('unknown message type → null', () {
      expect(parseRtMessage({'message': 'SomethingNew'}), isNull);
      expect(parseRtMessage({'no_message_key': true}), isNull);
    });

    test('malformed payloads never throw', () {
      expect(parseRtMessage({'message': 'AddTranscript', 'results': 'oops'}),
          isA<FinalTranscriptEvent>());
      expect(parseRtMessage({'message': 'AddPartialTranscript'}),
          isA<PartialTranscriptEvent>());
      expect(parseRtMessage({'message': 'AudioEventStarted'}),
          isA<AudioEventStartedEvent>());
    });
  });

  group('buildStartRecognition — standard RT', () {
    RtSessionConfig full() => const RtSessionConfig(
          engine: LiveEngine.standard,
          language: 'en',
          operatingPoint: 'enhanced',
          partials: true,
          diarization: true,
          maxSpeakers: 6,
          maxDelay: 1.5,
          maxDelayMode: 'fixed',
          outputLocale: 'en-GB',
          disfluencyRemoval: true,
          customDictWords: ['Speechmatics', 'EveryVoice'],
          punctuationEnabled: true,
          punctuationSensitivity: 0.7,
          punctuationMarks: ['comma', 'period'],
          audioFiltering: true,
          volumeThreshold: 4,
          translationTargets: ['es', 'de', 'fr', 'it', 'pt', 'nl'],
          audioEventTypes: ['laughter', 'music'],
          rtEndpointMode: 'auto',
          eouTrigger: 0.8,
        );

    test('full portal config maps completely', () {
      final msg = buildStartRecognition(full(), sampleRate: 16000);
      expect(msg['message'], 'StartRecognition');
      expect(msg['audio_format'],
          {'type': 'raw', 'encoding': 'pcm_s16le', 'sample_rate': 16000});

      final tc = msg['transcription_config'] as Map<String, dynamic>;
      expect(tc['language'], 'en');
      expect(tc.containsKey('model'), isFalse); // standard = server default
      expect(tc['operating_point'], 'enhanced');
      expect(tc['enable_partials'], isTrue);
      expect(tc['output_locale'], 'en-GB');
      expect(tc['diarization'], 'speaker');
      expect(tc['speaker_diarization_config'], {'max_speakers': 6});
      expect(tc['max_delay'], 1.5);
      expect(tc['max_delay_mode'], 'fixed');
      expect(tc['additional_vocab'], [
        {'content': 'Speechmatics'},
        {'content': 'EveryVoice'},
      ]);
      // Mark ids are translated to the single-character schema form
      // (permitted_marks pattern ^(.|all)$ — the id form is rejected live).
      expect(tc['punctuation_overrides'],
          {'permitted_marks': [',', '.'], 'sensitivity': 0.7});
      expect(tc['transcript_filtering_config'], {'remove_disfluencies': true});
      expect(tc['audio_filtering_config'], {'volume_threshold': 4});
      // End-of-utterance detection is always on for standard RT — captions
      // break at pauses and translation gets sentence-sized units.
      expect(tc['conversation_config'],
          {'end_of_utterance_silence_trigger': 0.8});

      // Translation capped at 5 targets.
      expect(msg['translation_config'], {
        'target_languages': ['es', 'de', 'fr', 'it', 'pt'],
        'enable_partials': true,
      });
      expect(msg['audio_events_config'], {
        'types': ['laughter', 'music']
      });
    });

    test('domain emits only when set (Enhanced feature)', () {
      final withDomain = buildStartRecognition(
        const RtSessionConfig(
            engine: LiveEngine.standard,
            language: 'en',
            operatingPoint: 'enhanced',
            domain: 'medical'),
        sampleRate: 16000,
      );
      expect((withDomain['transcription_config'] as Map)['domain'], 'medical');

      final without = buildStartRecognition(
        const RtSessionConfig(engine: LiveEngine.standard, language: 'en'),
        sampleRate: 16000,
      );
      expect((without['transcription_config'] as Map).containsKey('domain'),
          isFalse);
    });

    test('punctuation off sends empty permitted_marks', () {
      final msg = buildStartRecognition(
        const RtSessionConfig(
            engine: LiveEngine.standard,
            language: 'en',
            punctuationEnabled: false),
        sampleRate: 16000,
      );
      final tc = msg['transcription_config'] as Map<String, dynamic>;
      expect(tc['punctuation_overrides'], {'permitted_marks': <String>[]});
    });

    test('all four default marks map to schema-valid symbols', () {
      final msg = buildStartRecognition(
        const RtSessionConfig(
          engine: LiveEngine.standard,
          language: 'en',
          punctuationMarks: [
            'comma', 'period', 'question_mark', 'exclamation_mark', 'all',
          ],
        ),
        sampleRate: 16000,
      );
      final tc = msg['transcription_config'] as Map<String, dynamic>;
      final marks =
          (tc['punctuation_overrides'] as Map)['permitted_marks'] as List;
      expect(marks, [',', '.', '?', '!', 'all']);
      final valid = RegExp(r'^(.|all)$');
      for (final m in marks) {
        expect(valid.hasMatch(m as String), isTrue,
            reason: '$m must satisfy the schema pattern');
      }
    });

    test('disabled features are omitted, not sent as false', () {
      final msg = buildStartRecognition(
        const RtSessionConfig(engine: LiveEngine.standard, language: 'lv'),
        sampleRate: 16000,
      );
      final tc = msg['transcription_config'] as Map<String, dynamic>;
      expect(tc.containsKey('output_locale'), isFalse);
      expect(tc.containsKey('diarization'), isFalse);
      expect(tc.containsKey('additional_vocab'), isFalse);
      expect(tc.containsKey('transcript_filtering_config'), isFalse);
      expect(tc.containsKey('audio_filtering_config'), isFalse);
      expect(msg.containsKey('translation_config'), isFalse);
      expect(msg.containsKey('audio_events_config'), isFalse);
    });

    test('endpoint mapping: auto → global, eu/us regional', () {
      const c = RtSessionConfig(engine: LiveEngine.standard, language: 'en');
      expect(c.endpoint, AppConfig.rtBase('auto'));
      expect(AppConfig.rtBase('auto'), contains('global.rt.speechmatics.com'));
      expect(AppConfig.rtBase('eu'), contains('eu.rt.speechmatics.com'));
      expect(AppConfig.rtBase('us'), contains('us.rt.speechmatics.com'));
    });
  });
}
