import 'package:flutter_test/flutter_test.dart';
import 'package:speechmatics_translate/data/rt_protocol.dart';
import 'package:speechmatics_translate/models/history_item.dart';
import 'package:speechmatics_translate/state/live_controller.dart';
import 'package:speechmatics_translate/state/live_transcript_builder.dart';

void main() {
  final now = DateTime(2026, 7, 31, 12, 0);

  group('buildLiveHistoryItem — standard RT', () {
    test('maps lines to conversation turns with role names', () {
      final item = buildLiveHistoryItem(
        mode: LiveMode.standard,
        lines: [
          LiveLine(speaker: 'S1', text: 'Hello there. '),
          LiveLine(speaker: 'S2', text: 'Hi! '),
          LiveLine(speaker: null, text: 'Mono line. '),
          LiveLine(speaker: 'S1', text: '   '), // empty → dropped
        ],
        langCode: 'en',
        recognitionId: 'rec-1',
        elapsedSeconds: 65,
        now: now,
      );
      expect(item.type, HistoryType.conversation);
      expect(item.model, 'RT');
      expect(item.title, 'Live session');
      expect(item.jobId, isEmpty); // RT has no retrievable job id
      expect(item.id, startsWith('live-'));
      expect(item.duration, '1:05');
      expect(item.languages, ['EN']);
      expect(item.conversation, hasLength(3));
      expect(item.conversation![0].role, 'Speaker 1');
      expect(item.conversation![1].role, 'Speaker 2');
      expect(item.conversation![2].role, 'You');
      expect(item.conversation![0].text, 'Hello there.');
      expect(item.speakers, 2); // 'You' is not counted as a speaker
      expect(item.turns, isNull); // agent-only stat
      expect(item.translation, isFalse);
      expect(item.audioEventCounts, isNull);
    });

    test('primary translation target becomes translationText', () {
      final item = buildLiveHistoryItem(
        mode: LiveMode.standard,
        lines: [LiveLine(speaker: null, text: 'Hello world.')],
        langCode: 'en',
        recognitionId: 'rec-2',
        elapsedSeconds: 10,
        translations: const {'es': 'Hola mundo.', 'de': 'Hallo Welt.'},
        translationTargets: const ['es', 'de'],
        now: now,
      );
      expect(item.translation, isTrue);
      expect(item.translationText, 'Hola mundo.');
      expect(item.targetLanguage, 'Spanish');
      expect(item.languages, ['EN', 'ES']);
      expect(item.arrow, '→');
    });

    test('audio event marks aggregate into counts', () {
      final item = buildLiveHistoryItem(
        mode: LiveMode.standard,
        lines: [LiveLine(speaker: null, text: 'x')],
        langCode: 'en',
        recognitionId: '',
        elapsedSeconds: 5,
        eventMarks: const [
          LiveEventMark('music', time: 1),
          LiveEventMark('music', time: 8),
          LiveEventMark('laughter', time: 4),
        ],
        now: now,
      );
      expect(item.audioEventCounts, {'music': 2, 'laughter': 1});
    });
  });
}
