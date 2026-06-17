// Data shapes for transcription history / recent items.
// Serializable for the Hive-backed HistoryStore.

import 'package:intl/intl.dart';

import 'lang_catalog.dart';

enum HistoryType { batch, conversation }

/// One transcribed word with its absolute audio timestamps (seconds).
///
/// `text` includes the leading delimiter for non-first words and any trailing
/// punctuation, so `part.words.map((w) => w.text).join('') == part.text`
/// exactly — playback highlight rendering relies on this invariant.
class TranscriptWord {
  const TranscriptWord(this.text, this.start, this.end);
  final String text;
  final double start;
  final double end;

  Map<String, dynamic> toJson() => {'t': text, 's': start, 'e': end};

  factory TranscriptWord.fromJson(Map<String, dynamic> j) => TranscriptWord(
        j['t'] as String,
        (j['s'] as num).toDouble(),
        (j['e'] as num).toDouble(),
      );
}

/// A run of text in a single language inside a diarized segment
/// (used to render code-switching).
class TranscriptPart {
  const TranscriptPart(this.lang, this.text, {this.rtl, this.words = const []});
  final String lang;
  final String text;

  /// Explicit RTL flag (from the API writing direction). When null, derived
  /// from the language catalog.
  final bool? rtl;

  /// Per-word timings for playback highlight. Empty for items created before
  /// word timings were captured (and for translations) — render plain text then.
  final List<TranscriptWord> words;

  bool get isRtl => rtl ?? LangCatalog.isRtl(lang);

  Map<String, dynamic> toJson() => {
        'lang': lang,
        'text': text,
        if (rtl != null) 'rtl': rtl,
        if (words.isNotEmpty) 'words': words.map((w) => w.toJson()).toList(),
      };

  factory TranscriptPart.fromJson(Map<String, dynamic> j) => TranscriptPart(
        j['lang'] as String,
        j['text'] as String,
        rtl: j['rtl'] as bool?,
        words: (j['words'] as List?)
                ?.map((e) => TranscriptWord.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}

/// An auto-detected chapter (classic-engine speech intelligence).
class ChapterInfo {
  const ChapterInfo({
    required this.title,
    this.summary,
    required this.startSeconds,
    required this.endSeconds,
  });
  final String title;
  final String? summary;
  final double startSeconds;
  final double endSeconds;

  String get timeLabel {
    final s = startSeconds.round();
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        if (summary != null) 'summary': summary,
        's': startSeconds,
        'e': endSeconds,
      };

  factory ChapterInfo.fromJson(Map<String, dynamic> j) => ChapterInfo(
        title: j['title'] as String? ?? '',
        summary: j['summary'] as String?,
        startSeconds: (j['s'] as num?)?.toDouble() ?? 0,
        endSeconds: (j['e'] as num?)?.toDouble() ?? 0,
      );
}

/// A detected audio event (laughter/music/applause) with its time span.
class AudioEventMark {
  const AudioEventMark(this.type, this.start, this.end);
  final String type;
  final double start;
  final double end;

  Map<String, dynamic> toJson() => {'t': type, 's': start, 'e': end};

  factory AudioEventMark.fromJson(Map<String, dynamic> j) => AudioEventMark(
        j['t'] as String? ?? '',
        (j['s'] as num?)?.toDouble() ?? 0,
        (j['e'] as num?)?.toDouble() ?? 0,
      );
}

class TranscriptSegment {
  const TranscriptSegment({
    required this.speaker,
    required this.time,
    required this.parts,
  });
  final String speaker;
  final String time;
  final List<TranscriptPart> parts;

  Map<String, dynamic> toJson() => {
        'speaker': speaker,
        'time': time,
        'parts': parts.map((p) => p.toJson()).toList(),
      };

  factory TranscriptSegment.fromJson(Map<String, dynamic> j) => TranscriptSegment(
        speaker: j['speaker'] as String,
        time: j['time'] as String,
        parts: (j['parts'] as List)
            .map((e) => TranscriptPart.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class ConversationTurn {
  const ConversationTurn({
    required this.role,
    required this.lang,
    required this.text,
    this.rtl,
  });
  final String role; // "User" or "A"
  final String lang;
  final String text;
  final bool? rtl;

  bool get isUser => role == 'User';
  bool get isRtl => rtl ?? LangCatalog.isRtl(lang);

  Map<String, dynamic> toJson() => {
        'role': role,
        'lang': lang,
        'text': text,
        if (rtl != null) 'rtl': rtl,
      };

  factory ConversationTurn.fromJson(Map<String, dynamic> j) => ConversationTurn(
        role: j['role'] as String,
        lang: j['lang'] as String,
        text: j['text'] as String,
        rtl: j['rtl'] as bool?,
      );
}

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.type,
    required this.title,
    required this.jobId,
    required this.languages,
    this.arrow = '',
    required this.relativeLabel,
    required this.bucket,
    this.duration,
    this.model = 'melia-1',
    this.translation = false,
    this.speakers,
    this.turns,
    this.segments,
    this.translationText,
    this.conversation,
    this.createdAt,
    this.targetLanguage,
    this.audioFile,
    this.summaryText,
    this.topicCounts,
    this.chapters,
    this.audioEventCounts,
    this.audioEventMarks,
    this.srtText,
    this.favorite = false,
  });

  final String id;
  final HistoryType type;
  final String title;
  final String jobId;
  final List<String> languages;
  final String arrow; // "→", "↔" or ""
  final String relativeLabel;
  final String bucket; // today | yesterday | week | month
  final String? duration;
  final String model;
  final bool translation;
  final int? speakers;
  final int? turns;
  final List<TranscriptSegment>? segments;
  final String? translationText;
  final List<ConversationTurn>? conversation;
  final DateTime? createdAt;
  final String? targetLanguage; // display name of the translation target

  /// Persisted audio file NAME (not a path — the documents dir is resolved at
  /// runtime; iOS container paths change between launches). Null = no audio.
  final String? audioFile;

  // ---- speech intelligence (classic engine only; null = not requested) ----
  final String? summaryText;
  final Map<String, int>? topicCounts;
  final List<ChapterInfo>? chapters;
  final Map<String, int>? audioEventCounts;
  final List<AudioEventMark>? audioEventMarks;
  final String? srtText;

  /// Starred by the user (the History "Favourites" filter).
  final bool favorite;

  /// True when any speech-intelligence result exists → the Insights view shows.
  bool get hasInsights =>
      summaryText != null ||
      topicCounts != null ||
      chapters != null ||
      audioEventCounts != null ||
      srtText != null;

  bool get isConversation => type == HistoryType.conversation;

  /// Time bucket computed from [createdAt] at READ time — the persisted
  /// `bucket` string is only a fallback (it's written once at creation, so an
  /// item recorded "today" would otherwise stay in Today forever).
  String get effectiveBucket {
    final c = createdAt;
    if (c == null) return bucket;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(c.year, c.month, c.day);
    final days = today.difference(day).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 7) return 'week';
    return 'month';
  }

  /// Human relative label computed from [createdAt] at READ time (the
  /// persisted `relativeLabel` — "Just now" — is only a fallback).
  String get displayLabel {
    final c = createdAt;
    if (c == null) return relativeLabel;
    final diff = DateTime.now().difference(c);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return switch (effectiveBucket) {
      'today' => '${diff.inHours}h ago',
      'yesterday' => 'Yesterday',
      'week' => '${diff.inDays}d ago',
      _ => DateFormat('MMM d').format(c),
    };
  }

  List<String> get metaParts => [
        displayLabel,
        if (duration != null) duration!,
        // Old items persisted the lowercase display name — normalize.
        model == 'melia-1' ? 'Melia-1' : model,
        if (isConversation && turns != null) '$turns turns',
        if (speakers != null) '$speakers ${speakers == 1 ? 'spk' : 'spks'}',
      ];

  HistoryItem copyWith({String? title, bool? favorite}) => HistoryItem(
        id: id,
        type: type,
        title: title ?? this.title,
        jobId: jobId,
        languages: languages,
        arrow: arrow,
        relativeLabel: relativeLabel,
        bucket: bucket,
        duration: duration,
        model: model,
        translation: translation,
        speakers: speakers,
        turns: turns,
        segments: segments,
        translationText: translationText,
        conversation: conversation,
        createdAt: createdAt,
        targetLanguage: targetLanguage,
        audioFile: audioFile,
        summaryText: summaryText,
        topicCounts: topicCounts,
        chapters: chapters,
        audioEventCounts: audioEventCounts,
        audioEventMarks: audioEventMarks,
        srtText: srtText,
        favorite: favorite ?? this.favorite,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'jobId': jobId,
        'languages': languages,
        'arrow': arrow,
        'relativeLabel': relativeLabel,
        'bucket': bucket,
        'duration': duration,
        'model': model,
        'translation': translation,
        'speakers': speakers,
        'turns': turns,
        'segments': segments?.map((s) => s.toJson()).toList(),
        'translationText': translationText,
        'conversation': conversation?.map((c) => c.toJson()).toList(),
        'createdAt': createdAt?.millisecondsSinceEpoch,
        'targetLanguage': targetLanguage,
        if (audioFile != null) 'audioFile': audioFile,
        if (summaryText != null) 'summaryText': summaryText,
        if (topicCounts != null) 'topicCounts': topicCounts,
        if (chapters != null) 'chapters': chapters!.map((c) => c.toJson()).toList(),
        if (audioEventCounts != null) 'audioEventCounts': audioEventCounts,
        if (audioEventMarks != null)
          'audioEventMarks': audioEventMarks!.map((m) => m.toJson()).toList(),
        if (srtText != null) 'srtText': srtText,
        if (favorite) 'favorite': true,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        id: j['id'] as String,
        type: HistoryType.values.byName(j['type'] as String),
        title: j['title'] as String,
        jobId: (j['jobId'] ?? j['batchId']) as String? ?? '',
        languages: (j['languages'] as List).cast<String>(),
        arrow: j['arrow'] as String? ?? '',
        relativeLabel: j['relativeLabel'] as String? ?? '',
        bucket: j['bucket'] as String? ?? 'today',
        duration: j['duration'] as String?,
        model: j['model'] as String? ?? 'melia-1',
        translation: j['translation'] as bool? ?? false,
        speakers: j['speakers'] as int?,
        turns: j['turns'] as int?,
        segments: (j['segments'] as List?)
            ?.map((e) => TranscriptSegment.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        translationText: j['translationText'] as String?,
        conversation: (j['conversation'] as List?)
            ?.map((e) => ConversationTurn.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        createdAt: j['createdAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
        targetLanguage: j['targetLanguage'] as String?,
        audioFile: j['audioFile'] as String?,
        summaryText: j['summaryText'] as String?,
        topicCounts: (j['topicCounts'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        chapters: (j['chapters'] as List?)
            ?.map((e) => ChapterInfo.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        audioEventCounts: (j['audioEventCounts'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        audioEventMarks: (j['audioEventMarks'] as List?)
            ?.map((e) => AudioEventMark.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        srtText: j['srtText'] as String?,
        favorite: j['favorite'] as bool? ?? false,
      );
}
