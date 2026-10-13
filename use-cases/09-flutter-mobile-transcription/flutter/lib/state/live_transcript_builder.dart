/// Pure-Dart assembly of live sessions from RtEvents — no sockets, no
/// Flutter, fully unit-testable. Used by Home LIVE.
library;

import '../data/rt_protocol.dart';

/// One finalized caption line of a standard-RT session.
class LiveLine {
  LiveLine({this.speaker, this.text = '', this.start});
  String? speaker; // 'S1', 'S2', … or null when diarization is off
  String text;
  double? start; // audio time of the line's first word, for display stamps
}

/// An inline non-speech event marker ('music', 'laughter', 'applause').
class LiveEventMark {
  const LiveEventMark(this.type, {this.time});
  final String type;
  final double? time;
}

/// Standard RT: partials replace, finals accumulate into the open line,
/// EndOfUtterance (or a speaker change at a final boundary) splits lines.
class LiveTranscriptBuilder {
  final List<LiveLine> lines = [];
  String partial = '';

  /// lang code (lower) → accumulated translation text.
  final Map<String, String> translations = {};
  final Map<String, String> translationPartials = {};

  final List<LiveEventMark> events = [];

  bool _lineOpen = false;

  /// Whether the newest line is still growing (utterance not yet closed).
  bool get lineOpen => _lineOpen && lines.isNotEmpty;

  bool get isEmpty =>
      lines.every((l) => l.text.trim().isEmpty) && partial.trim().isEmpty;

  void add(RtEvent e) {
    switch (e) {
      case PartialTranscriptEvent():
        partial = e.transcript;
      case FinalTranscriptEvent():
        final speaker = e.words.isNotEmpty ? e.words.first.speaker : null;
        if (_lineOpen &&
            lines.isNotEmpty &&
            speaker != null &&
            lines.last.speaker != null &&
            lines.last.speaker != speaker) {
          _lineOpen = false; // diarized speaker change → new line
        }
        if (!_lineOpen || lines.isEmpty) {
          lines.add(LiveLine(
              speaker: speaker,
              start: e.words.isNotEmpty ? e.words.first.start : null));
          _lineOpen = true;
        }
        final line = lines.last;
        line.speaker ??= speaker;
        // metadata.transcript arrives correctly delimited — plain append.
        line.text += e.transcript;
        partial = '';
      case EndOfUtteranceEvent():
        _lineOpen = false;
      case PartialTranslationEvent():
        translationPartials[e.language.toLowerCase()] = e.transcript;
      case FinalTranslationEvent():
        final k = e.language.toLowerCase();
        translations[k] = '${translations[k] ?? ''}${e.transcript}';
        translationPartials.remove(k);
      case AudioEventStartedEvent():
        events.add(LiveEventMark(e.type, time: e.time));
      default:
        break;
    }
  }

  /// Display text for a target: finals plus the in-flight partial.
  String translationFor(String lang) {
    final k = lang.toLowerCase();
    final done = translations[k] ?? '';
    final part = translationPartials[k] ?? '';
    return part.isEmpty ? done : '$done $part'.trim();
  }
}
