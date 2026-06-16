import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:speechmatics_translate/models/history_item.dart';

void main() {
  group('HistoryItem serialization', () {
    test('round-trips audioFile and per-word timings', () {
      final item = HistoryItem(
        id: 't-1',
        type: HistoryType.batch,
        title: 'Test',
        jobId: 'abc123',
        languages: const ['EN'],
        relativeLabel: 'Just now',
        bucket: 'today',
        audioFile: 't-1.m4a',
        segments: const [
          TranscriptSegment(speaker: 'Speaker 1', time: '00:00', parts: [
            TranscriptPart('EN', 'Hello there.', words: [
              TranscriptWord('Hello', 0.0, 0.3),
              TranscriptWord(' there.', 0.4, 0.8),
            ]),
          ]),
        ],
      );

      final back = HistoryItem.fromJson(
          (jsonDecode(jsonEncode(item.toJson())) as Map).cast<String, dynamic>());

      expect(back.audioFile, 't-1.m4a');
      final part = back.segments!.single.parts.single;
      expect(part.text, 'Hello there.');
      expect(part.words.length, 2);
      expect(part.words[1].text, ' there.');
      expect(part.words[1].start, 0.4);
      expect(part.words[1].end, 0.8);
      expect(part.words.map((w) => w.text).join(''), part.text);
    });

    test('back-compat: old JSON without words/audioFile parses cleanly', () {
      final old = <String, dynamic>{
        'id': 't-0',
        'type': 'batch',
        'title': 'Old',
        'jobId': 'xyz',
        'languages': ['EN'],
        'relativeLabel': '2d ago',
        'bucket': 'week',
        'segments': [
          {
            'speaker': 'Speaker 1',
            'time': '00:00',
            'parts': [
              {'lang': 'EN', 'text': 'Legacy text'}
            ],
          }
        ],
      };
      final item = HistoryItem.fromJson(old);
      expect(item.audioFile, isNull);
      final part = item.segments!.single.parts.single;
      expect(part.text, 'Legacy text');
      expect(part.words, isEmpty);
    });

    test('effectiveBucket/displayLabel derive from createdAt, not persisted strings', () {
      HistoryItem at(DateTime when) => HistoryItem(
            id: 'x',
            type: HistoryType.batch,
            title: 't',
            jobId: 'j',
            languages: const ['EN'],
            relativeLabel: 'Just now', // stale persisted value
            bucket: 'today', // stale persisted value
            createdAt: when,
          );
      final now = DateTime.now();

      expect(at(now).effectiveBucket, 'today');
      expect(at(now).displayLabel, 'Just now');
      expect(at(now.subtract(const Duration(minutes: 5))).displayLabel, '5m ago');
      expect(at(now.subtract(const Duration(days: 1))).effectiveBucket, 'yesterday');
      expect(at(now.subtract(const Duration(days: 1))).displayLabel, 'Yesterday');
      expect(at(now.subtract(const Duration(days: 3))).effectiveBucket, 'week');
      expect(at(now.subtract(const Duration(days: 30))).effectiveBucket, 'month');

      // No createdAt (old seeds) → persisted fallbacks.
      final legacy = HistoryItem(
        id: 'y',
        type: HistoryType.batch,
        title: 't',
        jobId: 'j',
        languages: const ['EN'],
        relativeLabel: '2d ago',
        bucket: 'week',
      );
      expect(legacy.effectiveBucket, 'week');
      expect(legacy.displayLabel, '2d ago');
    });

    test('copyWith (rename) preserves audioFile', () {
      final item = HistoryItem(
        id: 't-2',
        type: HistoryType.batch,
        title: 'Before',
        jobId: 'j',
        languages: const ['EN'],
        relativeLabel: 'now',
        bucket: 'today',
        audioFile: 't-2.wav',
      );
      expect(item.copyWith(title: 'After').audioFile, 't-2.wav');
    });

    test('speech intelligence + favorite round-trip', () {
      final item = HistoryItem(
        id: 't-3',
        type: HistoryType.batch,
        title: 'SI',
        jobId: 'j3',
        languages: const ['EN'],
        relativeLabel: 'now',
        bucket: 'today',
        summaryText: '- point one\n- point two',
        topicCounts: const {'cooking': 2, 'space': 1},
        chapters: const [
          ChapterInfo(title: 'Intro', summary: 'About things', startSeconds: 0, endSeconds: 60),
          ChapterInfo(title: 'Outro', startSeconds: 60, endSeconds: 120),
        ],
        audioEventCounts: const {'laughter': 3},
        audioEventMarks: const [AudioEventMark('laughter', 1.5, 2.0)],
        srtText: '1\n00:00:00,000 --> 00:00:01,000\nHello\n',
        favorite: true,
      );
      expect(item.hasInsights, isTrue);

      final back = HistoryItem.fromJson(
          (jsonDecode(jsonEncode(item.toJson())) as Map).cast<String, dynamic>());
      expect(back.summaryText, item.summaryText);
      expect(back.topicCounts, {'cooking': 2, 'space': 1});
      expect(back.chapters!.length, 2);
      expect(back.chapters!.first.title, 'Intro');
      expect(back.chapters!.first.summary, 'About things');
      expect(back.chapters!.last.summary, isNull);
      expect(back.chapters!.first.timeLabel, '00:00');
      expect(back.chapters!.last.timeLabel, '01:00');
      expect(back.audioEventCounts, {'laughter': 3});
      expect(back.audioEventMarks!.single.type, 'laughter');
      expect(back.srtText, item.srtText);
      expect(back.favorite, isTrue);
      expect(back.hasInsights, isTrue);

      // copyWith must carry SI + favorite (rename path).
      final renamed = back.copyWith(title: 'Renamed');
      expect(renamed.summaryText, item.summaryText);
      expect(renamed.chapters!.length, 2);
      expect(renamed.srtText, item.srtText);
      expect(renamed.favorite, isTrue);
      // and the favorite toggle path:
      expect(renamed.copyWith(favorite: false).favorite, isFalse);
      expect(renamed.copyWith(favorite: false).summaryText, item.summaryText);
    });

    test('old JSON without SI/favorite → nulls, false, no insights', () {
      final item = HistoryItem.fromJson(const {
        'id': 'o',
        'type': 'batch',
        'title': 'Old',
        'jobId': 'x',
        'languages': ['EN'],
        'relativeLabel': '1d ago',
        'bucket': 'week',
      });
      expect(item.summaryText, isNull);
      expect(item.topicCounts, isNull);
      expect(item.chapters, isNull);
      expect(item.audioEventCounts, isNull);
      expect(item.srtText, isNull);
      expect(item.favorite, isFalse);
      expect(item.hasInsights, isFalse);
    });
  });
}
