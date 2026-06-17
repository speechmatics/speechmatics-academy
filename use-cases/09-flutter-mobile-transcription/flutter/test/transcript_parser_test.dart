import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:speechmatics_translate/data/transcript_parser.dart';

Map<String, dynamic> _word(String c, double t, String lang, String? spk) => {
      'type': 'word',
      'start_time': t,
      'end_time': t + 0.3,
      'alternatives': [
        {'content': c, 'language': lang, if (spk != null) 'speaker': spk}
      ],
    };

Map<String, dynamic> _punct(String c, String lang) => {
      'type': 'punctuation',
      'alternatives': [
        {'content': c, 'language': lang}
      ],
    };

void main() {
  final Map<String, dynamic> golden = {
    'job': {'duration': 12},
    'metadata': {
      'language_pack_info': {
        'per_language_writing_direction': {'ar': 'right-to-left', 'en': 'left-to-right'},
        'per_language_word_delimiters': {'en': ' ', 'es': ' ', 'ar': ' '},
      }
    },
    'results': [
      _word('I', 0.0, 'en', 'S1'),
      _word('need', 0.4, 'en', 'S1'),
      _word('estación', 0.8, 'es', 'S1'),
      _punct('.', 'es'),
      _word('مرحبا', 1.2, 'ar', 'S1'),
      _word('Hello', 2.0, 'en', 'S2'),
      _word('there', 2.4, 'en', 'S2'),
    ],
  };

  group('parseJsonV2 (diarized)', () {
    test('groups code-switching parts, speakers, RTL and duration', () {
      final p = parseJsonV2(golden, diarized: true);

      expect(p.durationSeconds, 12);
      expect(p.speakerCount, 2);
      expect(p.languages, containsAll(<String>['EN', 'ES', 'AR']));
      expect(p.rtlLanguages, contains('AR'));

      // Segment 1 = Speaker 1, code-switching EN -> ES -> AR.
      final s1 = p.segments.first;
      expect(s1.speaker, 'Speaker 1');
      expect(s1.parts.map((e) => e.lang).toList(), ['EN', 'ES', 'AR']);
      expect(s1.parts.first.text, 'I need');

      // Arabic part renders RTL.
      final ar = s1.parts.firstWhere((e) => e.lang == 'AR');
      expect(ar.isRtl, isTrue);

      // Segment 2 = Speaker 2.
      expect(p.segments[1].speaker, 'Speaker 2');
      expect(p.segments[1].parts.single.text, 'Hello there');
    });

    test('fullText concatenates all words for translation', () {
      final p = parseJsonV2(golden, diarized: true);
      expect(p.fullText.contains('I need'), isTrue);
      expect(p.fullText.contains('Hello there'), isTrue);
    });

    test('without diarization everything is a single speaker block', () {
      final p = parseJsonV2(golden, diarized: false);
      expect(p.segments.length, 1);
      expect(p.segments.first.parts.map((e) => e.lang), containsAll(<String>['EN', 'ES', 'AR']));
    });
  });

  group('parseJsonV2 word timings (playback highlight)', () {
    test('per-word start/end preserved; delimiters folded into word text', () {
      final p = parseJsonV2(golden, diarized: true);
      final en = p.segments.first.parts.first;
      expect(en.words.map((w) => w.text).toList(), ['I', ' need']);
      expect(en.words.map((w) => w.start).toList(), [0.0, 0.4]);
      expect(en.words.map((w) => w.end).toList(), [0.3, 0.7]);
    });

    test('punctuation attaches to the previous word (no timing extension when absent)', () {
      final p = parseJsonV2(golden, diarized: true);
      final es = p.segments.first.parts.firstWhere((e) => e.lang == 'ES');
      expect(es.words.single.text, 'estación.');
      expect(es.words.single.start, 0.8);
      expect(es.words.single.end, closeTo(1.1, 1e-9)); // fixture punct has no end_time
    });

    test('join-invariant: words concatenated == part text, every part', () {
      for (final diarized in [true, false]) {
        final p = parseJsonV2(golden, diarized: diarized);
        for (final seg in p.segments) {
          for (final part in seg.parts) {
            expect(part.words, isNotEmpty);
            expect(part.words.map((w) => w.text).join(''), part.text,
                reason: 'invariant broken for ${part.lang} (diarized=$diarized)');
          }
        }
      }
    });

    test('audio_event entries never enter the word stream', () {
      final withEvents = <String, dynamic>{
        'metadata': {
          'language_pack_info': {
            'per_language_word_delimiters': {'en': ' '},
          }
        },
        'results': [
          _word('Hello', 0.0, 'en', 'S1'),
          // with alternatives-like payload
          {
            'type': 'audio_event',
            'event_type': 'laughter',
            'start_time': 0.5,
            'end_time': 1.0,
            'alternatives': [{'content': 'XXX'}],
          },
          _word('there', 1.2, 'en', 'S1'),
          // without alternatives
          {'type': 'audio_event', 'event_type': 'music', 'start_time': 2.0, 'end_time': 3.0},
          _word('friend', 3.2, 'en', 'S1'),
        ],
      };
      final p = parseJsonV2(withEvents, diarized: true);
      final part = p.segments.single.parts.single;
      expect(part.text, 'Hello there friend'); // no XXX leakage
      expect(part.words.map((w) => w.text).join(''), part.text);
      expect(p.audioEvents.length, 2);
      expect(p.audioEvents.first.type, 'laughter');
      expect(p.audioEvents.first.start, 0.5);
      expect(p.audioEvents.last.type, 'music');
    });

    test('parseInsights extracts SI blocks from the live fixture', () {
      final j = jsonDecode(File('test/fixtures/si_transcript.json').readAsStringSync())
          as Map<String, dynamic>;
      final ins = parseInsights(j);
      expect(ins.summaryText, isNotNull);
      expect(ins.summaryText, contains('pasta'));
      expect(ins.topicCounts, {'cooking': 1, 'space': 1});
      expect(ins.chapters, isNotNull);
      expect(ins.chapters!.length, 2);
      expect(ins.chapters!.first.title, contains('Pasta'));
      expect(ins.chapters!.first.startSeconds, 0.0);
      expect(ins.chapters!.last.startSeconds, greaterThan(0));
      // 'speech' baseline is excluded; no other events fired in the fixture.
      expect(ins.audioEventCounts, isNull);
    });

    test('parseInsights returns nulls for absent/malformed blocks', () {
      expect(parseInsights(const {}).summaryText, isNull);
      expect(parseInsights(const {}).topicCounts, isNull);
      expect(parseInsights(const {}).chapters, isNull);
      expect(parseInsights(const {}).audioEventCounts, isNull);

      final malformed = <String, dynamic>{
        'summary': 'not-a-map',
        'topics': {'summary': 'nope'},
        'chapters': 'nope',
        'audio_event_summary': 42,
      };
      final ins = parseInsights(malformed);
      expect(ins.summaryText, isNull);
      expect(ins.topicCounts, isNull);
      expect(ins.chapters, isNull);
      expect(ins.audioEventCounts, isNull);
    });

    test('empty-string delimiter (CJK) keeps invariant', () {
      final ja = <String, dynamic>{
        'metadata': {
          'language_pack_info': {
            'per_language_word_delimiters': {'ja': ''},
          }
        },
        'results': [
          _word('こんにちは', 0.0, 'ja', 'S1'),
          _word('世界', 0.5, 'ja', 'S1'),
          _punct('。', 'ja'),
        ],
      };
      final p = parseJsonV2(ja, diarized: true);
      final part = p.segments.single.parts.single;
      expect(part.text, 'こんにちは世界。');
      expect(part.words.map((w) => w.text).toList(), ['こんにちは', '世界。']);
      expect(part.words.map((w) => w.text).join(''), part.text);
    });
  });

  group('speaker identification', () {
    test('identified (custom) labels pass through verbatim; S-labels still map', () {
      final json = <String, dynamic>{
        'results': [
          _word('Hello', 0.0, 'en', 'Edgars A'),
          _word('there', 0.4, 'en', 'Edgars A'),
          // A NAME containing digits must never be rewritten to "Speaker 2".
          _word('Hi', 1.0, 'en', 'Alice 2'),
          _word('again', 2.0, 'en', 'S2'),
        ],
      };
      final p = parseJsonV2(json, diarized: true);
      expect(p.segments.map((s) => s.speaker).toList(),
          ['Edgars A', 'Alice 2', 'Speaker 2']);
    });

    test('parseEnrolledSpeakers extracts identifiers from the live fixture', () {
      final json = jsonDecode(
              File('test/fixtures/enrollment_transcript.json').readAsStringSync())
          as Map<String, dynamic>;
      final found = parseEnrolledSpeakers(json);
      expect(found, hasLength(1));
      expect(found.single.label, 'S1');
      expect(found.single.identifiers, isNotEmpty);
      expect(found.single.identifiers.first.length, greaterThan(100));
    });

    test('parseEnrolledSpeakers sorts by spoken words and tolerates garbage', () {
      final json = <String, dynamic>{
        'speakers': [
          {'label': 'S2', 'speaker_identifiers': ['id-s2']},
          {'label': 'S1', 'speaker_identifiers': ['id-s1']},
          {'label': 'S9'}, // missing identifiers → skipped
          'not-a-map',
        ],
        'results': [
          _word('one', 0.0, 'en', 'S1'),
          _word('two', 0.4, 'en', 'S1'),
          _word('noise', 1.0, 'en', 'S2'),
        ],
      };
      final found = parseEnrolledSpeakers(json);
      expect(found.map((e) => e.label).toList(), ['S1', 'S2']); // dominant first
      expect(parseEnrolledSpeakers(const {}), isEmpty);
      expect(parseEnrolledSpeakers(const {'speakers': 42}), isEmpty);
    });
  });
}
