import 'package:flutter_test/flutter_test.dart';
import 'package:speechmatics_translate/data/rt_protocol.dart';
import 'package:speechmatics_translate/state/live_transcript_builder.dart';

void main() {
  group('LiveTranscriptBuilder (standard RT)', () {
    test('partials replace; finals accumulate and clear the partial', () {
      final b = LiveTranscriptBuilder();
      b.add(const PartialTranscriptEvent('hel'));
      b.add(const PartialTranscriptEvent('hello wor'));
      expect(b.partial, 'hello wor');
      expect(b.isEmpty, isFalse); // a live partial counts as content

      b.add(const FinalTranscriptEvent('Hello world. ', []));
      expect(b.partial, isEmpty);
      expect(b.lines, hasLength(1));
      expect(b.lines.single.text, 'Hello world. ');

      b.add(const FinalTranscriptEvent('More words. ', []));
      expect(b.lines, hasLength(1)); // same open line keeps growing
      expect(b.lines.single.text, 'Hello world. More words. ');
    });

    test('EndOfUtterance splits lines; line start comes from the first word',
        () {
      final b = LiveTranscriptBuilder();
      b.add(const FinalTranscriptEvent(
          'First. ', [RtWord('First', start: 1.2, end: 1.6)]));
      b.add(const EndOfUtteranceEvent());
      b.add(const FinalTranscriptEvent(
          'Second. ', [RtWord('Second', start: 3.4, end: 3.9)]));
      expect(b.lines, hasLength(2));
      expect(b.lines.first.start, 1.2);
      expect(b.lines.last.start, 3.4);
    });

    test('diarized speaker change opens a new line', () {
      final b = LiveTranscriptBuilder();
      b.add(const FinalTranscriptEvent(
          'Hi. ', [RtWord('Hi', speaker: 'S1')]));
      b.add(const FinalTranscriptEvent(
          'Hey. ', [RtWord('Hey', speaker: 'S2')]));
      expect(b.lines, hasLength(2));
      expect(b.lines.first.speaker, 'S1');
      expect(b.lines.first.text, 'Hi. ');
      expect(b.lines.last.speaker, 'S2');
      expect(b.lines.last.text, 'Hey. ');
    });

    test('translations accumulate finals per language; partials replace', () {
      final b = LiveTranscriptBuilder();
      b.add(const PartialTranslationEvent('es', 'Hola'));
      expect(b.translationFor('es'), 'Hola');
      b.add(const FinalTranslationEvent('es', 'Hola mundo. '));
      b.add(const FinalTranslationEvent('ES', 'Segunda frase. '));
      // Finals concatenate as delivered (the API includes its own spacing);
      // rendering trims at the edges.
      expect(b.translationFor('es'), 'Hola mundo. Segunda frase. ');
      expect(b.translationPartials, isEmpty);
      b.add(const PartialTranslationEvent('es', 'Terce'));
      expect(b.translationFor('es'), 'Hola mundo. Segunda frase.  Terce');
    });

    test('audio events are recorded with times', () {
      final b = LiveTranscriptBuilder();
      b.add(const AudioEventStartedEvent('music', time: 4.2));
      b.add(const AudioEventStartedEvent('laughter', time: 9.1));
      expect(b.events, hasLength(2));
      expect(b.events.first.type, 'music');
      expect(b.events.first.time, 4.2);
    });
  });
}
