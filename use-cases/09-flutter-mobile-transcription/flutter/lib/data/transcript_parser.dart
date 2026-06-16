import '../models/history_item.dart';
import '../models/lang_catalog.dart';

class ParsedTranscript {
  ParsedTranscript({
    required this.segments,
    required this.languages,
    required this.fullText,
    required this.rtlLanguages,
    this.durationSeconds,
    this.audioEvents = const [],
  });

  final List<TranscriptSegment> segments;
  final Set<String> languages; // UPPER-case display codes
  final String fullText;
  final Set<String> rtlLanguages; // UPPER-case
  final int? durationSeconds;

  /// Detected audio events (laughter/music/applause) from `audio_event`
  /// result entries — classic engine only.
  final List<AudioEventMark> audioEvents;

  int get speakerCount =>
      segments.map((s) => s.speaker).toSet().length;

  /// Plain text per segment (parts joined) — used as the translation input.
  List<String> get segmentTexts =>
      segments.map((s) => s.parts.map((p) => p.text).join(' ').trim()).toList();
}

/// Parses a Speechmatics json-v2 transcript into code-switching, optionally
/// diarized [TranscriptSegment]s.
///
/// Algorithm: iterate `results` in order; group consecutive words by language
/// into [TranscriptPart]s; punctuation appends to the current run without
/// switching language; on speaker change (when diarized) start a new segment;
/// join words using the per-language delimiter. RTL comes from
/// `metadata.language_pack_info.per_language_writing_direction`.
ParsedTranscript parseJsonV2(Map<String, dynamic> json, {required bool diarized}) {
  final results = (json['results'] as List?) ?? const [];

  final metadata = (json['metadata'] as Map?) ?? const {};
  final packInfo = (metadata['language_pack_info'] as Map?) ?? const {};
  final directions = (packInfo['per_language_writing_direction'] as Map?) ?? const {};
  final delimiters = (packInfo['per_language_word_delimiters'] as Map?) ?? const {};
  final durationSeconds = ((json['job'] as Map?)?['duration'] as num?)?.round();

  final rtl = <String>{};
  directions.forEach((k, v) {
    if (v.toString().toLowerCase().startsWith('right')) rtl.add(k.toString().toUpperCase());
  });

  String delimiterFor(String langLower) => (delimiters[langLower] as String?) ?? ' ';
  bool isRtl(String upper) => rtl.contains(upper) || LangCatalog.isRtl(upper);

  final segments = <TranscriptSegment>[];
  final languages = <String>{};

  String? curSpeaker;
  String curTime = '00:00';
  var curParts = <TranscriptPart>[];

  String? curLangLower;
  // Words accumulate with their absolute timings; each word's text carries its
  // own leading delimiter / trailing punctuation so join('') == part text.
  var curWords = <TranscriptWord>[];
  // Punctuation that arrives before any word in the current part.
  var pendingPrefix = '';

  void flushPart() {
    if (curLangLower != null) {
      final upper = curLangLower!.toUpperCase();
      final text = curWords.map((w) => w.text).join('');
      if (text.isNotEmpty) {
        curParts.add(TranscriptPart(upper, text,
            rtl: isRtl(upper) ? true : null, words: curWords));
        languages.add(upper);
      } else if (pendingPrefix.trim().isNotEmpty) {
        // Degenerate punctuation-only run — keep the text, no word timings.
        curParts.add(TranscriptPart(upper, pendingPrefix.trim(),
            rtl: isRtl(upper) ? true : null));
        languages.add(upper);
      }
    }
    curWords = <TranscriptWord>[];
    pendingPrefix = '';
  }

  void flushSegment() {
    flushPart();
    if (curParts.isNotEmpty) {
      segments.add(TranscriptSegment(
        speaker: _speakerLabel(curSpeaker),
        time: curTime,
        parts: curParts,
      ));
    }
    curParts = <TranscriptPart>[];
    curLangLower = null;
  }

  final audioEvents = <AudioEventMark>[];

  var started = false;
  for (final r in results) {
    if (r is! Map) continue;
    final type = r['type']?.toString();

    // Audio events never enter the word stream — collect them separately.
    if (type == 'audio_event') {
      final evType = (r['event_type'] ?? r['event'] ?? '').toString();
      if (evType.isNotEmpty) {
        audioEvents.add(AudioEventMark(
          evType,
          (r['start_time'] as num?)?.toDouble() ?? 0,
          (r['end_time'] as num?)?.toDouble() ?? 0,
        ));
      }
      continue;
    }

    final alts = r['alternatives'];
    if (alts is! List || alts.isEmpty) continue;
    final alt = alts.first as Map;
    final content = (alt['content'] ?? '').toString();
    if (content.isEmpty) continue;

    if (type == 'punctuation') {
      // Attach to the current run without delimiter or language switch.
      if (curWords.isNotEmpty) {
        final last = curWords.removeLast();
        final pEnd = ((r['end_time'] as num?))?.toDouble();
        curWords.add(TranscriptWord(last.text + content, last.start,
            (pEnd != null && pEnd > last.end) ? pEnd : last.end));
      } else {
        pendingPrefix += content;
      }
      continue;
    }

    // word
    final langLower = (alt['language'] ?? curLangLower ?? 'en').toString().toLowerCase();
    final speaker = diarized ? alt['speaker']?.toString() : null;

    if (!started) {
      curSpeaker = speaker;
      curTime = _fmtTime(r['start_time']);
      curLangLower = langLower;
      started = true;
    } else if (diarized && speaker != null && speaker != curSpeaker) {
      flushSegment();
      curSpeaker = speaker;
      curTime = _fmtTime(r['start_time']);
      curLangLower = langLower;
    } else if (langLower != curLangLower) {
      flushPart();
      curLangLower = langLower;
    }

    // Delimiter precedes every word except the very first content of a part
    // (mirrors the old buffer rule: delimiter only when buffer is non-empty).
    final hasContent = curWords.isNotEmpty || pendingPrefix.isNotEmpty;
    final prefix = (curWords.isEmpty ? pendingPrefix : '') +
        (hasContent ? delimiterFor(langLower) : '');
    pendingPrefix = '';
    final start = (r['start_time'] as num?)?.toDouble() ??
        (curWords.isNotEmpty ? curWords.last.end : 0.0);
    final end = (r['end_time'] as num?)?.toDouble() ?? start;
    curWords.add(TranscriptWord('$prefix$content', start, end));
  }
  flushSegment();

  final fullText = segments
      .map((s) => s.parts.map((p) => p.text).join(' '))
      .join(' ')
      .trim();

  return ParsedTranscript(
    segments: segments,
    languages: languages,
    fullText: fullText,
    rtlLanguages: rtl,
    durationSeconds: durationSeconds,
    audioEvents: audioEvents,
  );
}

/// Speech-intelligence blocks from a classic json-v2 response — every field
/// null when absent/empty/malformed (omni-v1 responses simply have none).
/// Shapes verified live 2026-06-11.
class SpeechInsights {
  const SpeechInsights({this.summaryText, this.topicCounts, this.chapters, this.audioEventCounts});
  final String? summaryText;
  final Map<String, int>? topicCounts;
  final List<ChapterInfo>? chapters;
  final Map<String, int>? audioEventCounts;
}

/// One label + voice-identifiers pair from a `get_speakers` enrollment job.
class EnrolledSpeaker {
  const EnrolledSpeaker({required this.label, required this.identifiers});
  final String label;
  final List<String> identifiers;
}

/// Tolerant parse of the TOP-LEVEL `speakers` array of a json-v2 transcript
/// (present when the job ran with `speaker_diarization_config.get_speakers`,
/// probe-verified 2026-06-12). Sorted by how many words each label spoke
/// (most first) so callers can take the dominant voice when background noise
/// produced extra labels. Malformed input → empty list, never throws.
List<EnrolledSpeaker> parseEnrolledSpeakers(Map<String, dynamic> json) {
  final raw = json['speakers'];
  if (raw is! List) return const [];

  final counts = <String, int>{};
  final results = json['results'];
  if (results is List) {
    for (final r in results) {
      if (r is! Map || r['type'] != 'word') continue;
      final alts = r['alternatives'];
      if (alts is! List || alts.isEmpty || alts.first is! Map) continue;
      final spk = (alts.first as Map)['speaker']?.toString();
      if (spk != null) counts[spk] = (counts[spk] ?? 0) + 1;
    }
  }

  final out = <EnrolledSpeaker>[];
  for (final s in raw) {
    if (s is! Map) continue;
    final label = s['label']?.toString();
    final ids = (s['speaker_identifiers'] as List?)?.whereType<String>().toList();
    if (label == null || ids == null || ids.isEmpty) continue;
    out.add(EnrolledSpeaker(label: label, identifiers: ids));
  }
  out.sort((a, b) => (counts[b.label] ?? 0).compareTo(counts[a.label] ?? 0));
  return out;
}

SpeechInsights parseInsights(Map<String, dynamic> json) {
  String? summaryText;
  Map<String, int>? topicCounts;
  List<ChapterInfo>? chapters;
  Map<String, int>? audioEventCounts;

  try {
    final s = ((json['summary'] as Map?)?['content'] ?? '').toString().trim();
    if (s.isNotEmpty) summaryText = s;
  } catch (_) {}

  try {
    final overall = ((json['topics'] as Map?)?['summary'] as Map?)?['overall'] as Map?;
    if (overall != null && overall.isNotEmpty) {
      topicCounts = overall.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    }
  } catch (_) {}

  try {
    final raw = json['chapters'] as List?;
    if (raw != null && raw.isNotEmpty) {
      chapters = raw
          .whereType<Map>()
          .map((c) => ChapterInfo(
                title: (c['title'] ?? '').toString(),
                summary: (c['summary'] as String?)?.trim(),
                startSeconds: (c['start_time'] as num?)?.toDouble() ?? 0,
                endSeconds: (c['end_time'] as num?)?.toDouble() ?? 0,
              ))
          .where((c) => c.title.isNotEmpty)
          .toList();
      if (chapters.isEmpty) chapters = null;
    }
  } catch (_) {}

  try {
    final overall = (json['audio_event_summary'] as Map?)?['overall'] as Map?;
    if (overall != null) {
      final counts = <String, int>{};
      overall.forEach((k, v) {
        final type = k.toString();
        if (type == 'speech') return; // baseline, not an interesting event
        final count = ((v as Map?)?['count'] as num?)?.toInt() ?? 0;
        if (count > 0) counts[type] = count;
      });
      if (counts.isNotEmpty) audioEventCounts = counts;
    }
  } catch (_) {}

  return SpeechInsights(
    summaryText: summaryText,
    topicCounts: topicCounts,
    chapters: chapters,
    audioEventCounts: audioEventCounts,
  );
}

String _speakerLabel(String? raw) {
  if (raw == null || raw.isEmpty || raw == 'UU') return 'Speaker';
  // Generic Speechmatics labels are "S1"/"S2"; IDENTIFIED speakers come back
  // under their enrolled name verbatim. Only map full S<number> labels —
  // never names that merely contain digits ("Alice 2" stays "Alice 2").
  final m = RegExp(r'^S?(\d+)$').firstMatch(raw);
  return m != null ? 'Speaker ${m.group(1)}' : raw;
}

String _fmtTime(dynamic seconds) {
  final s = (seconds as num?)?.round() ?? 0;
  final mm = (s ~/ 60).toString().padLeft(2, '0');
  final ss = (s % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}
