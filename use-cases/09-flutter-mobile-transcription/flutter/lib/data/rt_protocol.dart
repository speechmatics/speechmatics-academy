/// Speechmatics real-time wire protocol: typed events, message parsing and
/// StartRecognition construction. Pure Dart (no dart:io, no Flutter) so every
/// piece is unit-testable without sockets.
///
/// Standard RT (AddTranscript/AddPartialTranscript) for Home LIVE.
library;

import '../app_config.dart';

/// Which live engine a session runs on. Table-driven so the upcoming Melia
/// multilingual RT model is one more descriptor, not a refactor.
enum LiveMode { standard }

/// Capability/endpoint descriptor for a live engine.
class LiveEngine {
  const LiveEngine({
    required this.mode,
    required this.model,
    required this.supportsTranslation,
    required this.supportsAudioEvents,
    required this.supportsMaxDelay,
    required this.supportsDisfluencyRemoval,
  });

  final LiveMode mode;

  /// transcription_config.model value; null = server default (standard RT).
  final String? model;
  final bool supportsTranslation; // native RT translation
  final bool supportsAudioEvents;
  final bool supportsMaxDelay;
  final bool supportsDisfluencyRemoval;

  String endpoint(String rtEndpointMode) => switch (mode) {
        LiveMode.standard => AppConfig.rtBase(rtEndpointMode),
      };

  static const standard = LiveEngine(
    mode: LiveMode.standard,
    model: null,
    supportsTranslation: true,
    supportsAudioEvents: true,
    supportsMaxDelay: true,
    supportsDisfluencyRemoval: true,
  );
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

sealed class RtEvent {
  const RtEvent();
}

class RecognitionStartedEvent extends RtEvent {
  const RecognitionStartedEvent(this.id, this.languageDescription);
  final String id;
  final String? languageDescription;
}

/// One word of a standard-RT final, with optional diarization speaker.
class RtWord {
  const RtWord(this.content, {this.speaker, this.start, this.end});
  final String content;
  final String? speaker; // 'S1', 'S2', … when diarization is on
  final double? start;
  final double? end;
}

class PartialTranscriptEvent extends RtEvent {
  const PartialTranscriptEvent(this.transcript);
  final String transcript;
}

class FinalTranscriptEvent extends RtEvent {
  const FinalTranscriptEvent(this.transcript, this.words, {this.endTime});
  final String transcript;
  final List<RtWord> words;
  final double? endTime;
}

class EndOfUtteranceEvent extends RtEvent {
  const EndOfUtteranceEvent({this.startTime, this.endTime});
  final double? startTime;
  final double? endTime;
}

class PartialTranslationEvent extends RtEvent {
  const PartialTranslationEvent(this.language, this.transcript);
  final String language;
  final String transcript;
}

class FinalTranslationEvent extends RtEvent {
  const FinalTranslationEvent(this.language, this.transcript);
  final String language;
  final String transcript;
}

class AudioEventStartedEvent extends RtEvent {
  const AudioEventStartedEvent(this.type, {this.time});
  final String type; // 'laughter' | 'music' | 'applause'
  final double? time;
}

class AudioEventEndedEvent extends RtEvent {
  const AudioEventEndedEvent(this.type, {this.time});
  final String type;
  final double? time;
}

class AudioAddedEvent extends RtEvent {
  const AudioAddedEvent(this.seqNo);
  final int seqNo;
}

class InfoEvent extends RtEvent {
  const InfoEvent(this.type, this.reason);
  final String type;
  final String reason;
}

class WarningEvent extends RtEvent {
  const WarningEvent(this.type, this.reason);
  final String type;
  final String reason;
}

class RtErrorEvent extends RtEvent {
  const RtErrorEvent(this.type, this.reason);
  final String type;
  final String reason;
}

class EndOfTranscriptEvent extends RtEvent {
  const EndOfTranscriptEvent();
}

/// Synthesized locally by RtSession when the socket closes.
class SocketClosedEvent extends RtEvent {
  const SocketClosedEvent({this.code, this.reason});
  final int? code;
  final String? reason;
}

// ---------------------------------------------------------------------------
// Parsing
// ---------------------------------------------------------------------------

double? _dbl(Object? v) => v is num ? v.toDouble() : null;

Map<String, dynamic>? _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : null;

/// Parses one server JSON message into a typed event. Unknown or ignorable
/// message types return null. Never throws on malformed input.
RtEvent? parseRtMessage(Map<String, dynamic> json) {
  try {
    final meta = _map(json['metadata']);
    switch (json['message']) {
      case 'RecognitionStarted':
        return RecognitionStartedEvent(
          json['id'] as String? ?? '',
          _map(json['language_pack_info'])?['language_description'] as String?,
        );
      case 'AddPartialTranscript':
        return PartialTranscriptEvent(meta?['transcript'] as String? ?? '');
      case 'AddTranscript':
        final words = <RtWord>[];
        final results = json['results'];
        if (results is List) {
          for (final r in results) {
            final m = _map(r);
            if (m == null || m['type'] != 'word') continue;
            final alts = m['alternatives'];
            final alt = (alts is List && alts.isNotEmpty) ? _map(alts.first) : null;
            if (alt == null) continue;
            words.add(RtWord(
              alt['content'] as String? ?? '',
              speaker: alt['speaker'] as String?,
              start: _dbl(m['start_time']),
              end: _dbl(m['end_time']),
            ));
          }
        }
        return FinalTranscriptEvent(
          meta?['transcript'] as String? ?? '',
          words,
          endTime: _dbl(meta?['end_time']),
        );
      case 'EndOfUtterance':
        return EndOfUtteranceEvent(
            startTime: _dbl(meta?['start_time']),
            endTime: _dbl(meta?['end_time']));
      case 'AddPartialTranslation':
        return PartialTranslationEvent(
            json['language'] as String? ?? '', _translationText(json));
      case 'AddTranslation':
        return FinalTranslationEvent(
            json['language'] as String? ?? '', _translationText(json));
      case 'AudioEventStarted':
        final ev = _map(json['event']);
        return AudioEventStartedEvent(ev?['type'] as String? ?? 'event',
            time: _dbl(ev?['start_time']) ?? _dbl(meta?['start_time']));
      case 'AudioEventEnded':
        final ev = _map(json['event']);
        return AudioEventEndedEvent(ev?['type'] as String? ?? 'event',
            time: _dbl(ev?['end_time']) ?? _dbl(meta?['end_time']));
      case 'AudioAdded':
        return AudioAddedEvent((json['seq_no'] as num?)?.toInt() ?? 0);
      case 'Info':
        return InfoEvent(json['type'] as String? ?? 'info',
            json['reason'] as String? ?? '');
      case 'Warning':
        return WarningEvent(json['type'] as String? ?? 'warning',
            json['reason'] as String? ?? '');
      case 'Error':
        return RtErrorEvent(json['type'] as String? ?? 'error',
            json['reason'] as String? ?? 'Unknown error');
      case 'EndOfTranscript':
        return const EndOfTranscriptEvent();
      default:
        return null;
    }
  } catch (_) {
    return null;
  }
}

/// UI mark ids → the single-character form the RT schema accepts (its
/// permitted_marks pattern is `^(.|all)$` — live-verified rejection of the
/// id form; same symbols the batch API takes). Single characters and 'all'
/// pass through so callers may also supply symbols directly.
String? _markSymbol(String id) => switch (id) {
      'comma' => ',',
      'period' => '.',
      'question_mark' => '?',
      'exclamation_mark' => '!',
      _ => (id.length == 1 || id == 'all') ? id : null,
    };

String _translationText(Map<String, dynamic> json) {
  final meta = _map(json['metadata']);
  final t = meta?['transcript'] as String?;
  if (t != null && t.isNotEmpty) return t;
  final results = json['results'];
  if (results is List) {
    return results
        .map((r) => _map(r)?['content'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .join(' ');
  }
  return '';
}

// ---------------------------------------------------------------------------
// StartRecognition
// ---------------------------------------------------------------------------

/// An enrolled speaker sent to live diarization so it labels them by name
/// (speaker_diarization_config.speakers — the SDK's known_speakers).
class KnownSpeaker {
  const KnownSpeaker(this.label, this.identifiers);
  final String label;
  final List<String> identifiers;
}

/// Value object carrying everything a live session needs from settings.
/// Built by SettingsStore.rtSnapshot(); consumed here.
class RtSessionConfig {
  const RtSessionConfig({
    required this.engine,
    required this.language,
    this.operatingPoint,
    this.domain = 'none',
    this.partials = true,
    this.diarization = false,
    this.maxSpeakers,
    this.speakerSensitivity,
    this.preferCurrentSpeaker = false,
    this.knownSpeakers = const [],
    this.eouTrigger,
    this.maxDelay,
    this.maxDelayMode,
    this.outputLocale = '',
    this.disfluencyRemoval = false,
    this.customDictWords = const [],
    this.punctuationEnabled = true,
    this.punctuationSensitivity,
    this.punctuationMarks = const [],
    this.audioFiltering = false,
    this.volumeThreshold,
    this.translationTargets = const [],
    this.audioEventTypes = const [],
    this.rtEndpointMode = 'auto',
  });

  final LiveEngine engine;
  final String language;
  final String? operatingPoint; // 'enhanced' | 'standard' (standard RT only)
  final String domain; // 'none' | 'medical' | 'finance' (Enhanced only)
  final bool partials;
  final bool diarization;
  final int? maxSpeakers;
  final double? speakerSensitivity;
  final bool preferCurrentSpeaker;
  final List<KnownSpeaker> knownSpeakers;

  /// Fixed end-of-utterance silence trigger (conversation_config); null =
  /// no server EoU events (external/adaptive turn handling is client-side).
  final double? eouTrigger;
  final double? maxDelay;
  final String? maxDelayMode; // 'flexible' | 'fixed'
  final String outputLocale;
  final bool disfluencyRemoval;
  final List<String> customDictWords;
  final bool punctuationEnabled;
  final double? punctuationSensitivity;
  final List<String> punctuationMarks;
  final bool audioFiltering;
  final double? volumeThreshold;
  final List<String> translationTargets; // ≤5 (standard RT only)
  final List<String> audioEventTypes; // standard RT only
  final String rtEndpointMode; // 'auto' | 'eu' | 'us'

  String get endpoint => engine.endpoint(rtEndpointMode);
}

/// Builds the standard RT StartRecognition message body. Fields unsupported
/// by the engine's capability flags are omitted.
Map<String, dynamic> buildStartRecognition(
  RtSessionConfig c, {
  required int sampleRate,
}) {
  final tc = <String, dynamic>{
    'language': c.language,
    'enable_partials': c.partials,
  };

  if (c.engine.model != null) tc['model'] = c.engine.model;
  if (c.engine.mode == LiveMode.standard && c.operatingPoint != null) {
    tc['operating_point'] = c.operatingPoint;
  }
  if (c.engine.mode == LiveMode.standard &&
      c.domain.isNotEmpty &&
      c.domain != 'none') {
    tc['domain'] = c.domain;
  }
  if (c.outputLocale.isNotEmpty) tc['output_locale'] = c.outputLocale;
  if (c.diarization) {
    tc['diarization'] = 'speaker';
    final dz = <String, dynamic>{
      if (c.maxSpeakers != null) 'max_speakers': c.maxSpeakers,
      if (c.speakerSensitivity != null)
        'speaker_sensitivity': c.speakerSensitivity,
      if (c.preferCurrentSpeaker) 'prefer_current_speaker': true,
      if (c.knownSpeakers.isNotEmpty)
        'speakers': [
          for (final s in c.knownSpeakers)
            {'label': s.label, 'speaker_identifiers': s.identifiers},
        ],
    };
    if (dz.isNotEmpty) tc['speaker_diarization_config'] = dz;
  }
  if (c.engine.supportsMaxDelay && c.maxDelay != null) {
    tc['max_delay'] = c.maxDelay;
    if (c.maxDelayMode != null) tc['max_delay_mode'] = c.maxDelayMode;
  }
  if (c.engine.mode == LiveMode.standard && c.eouTrigger != null) {
    // End-of-utterance detection breaks captions at pauses and gives
    // translation sentence-sized units.
    tc['conversation_config'] = {
      'end_of_utterance_silence_trigger': c.eouTrigger,
    };
  }
  if (c.customDictWords.isNotEmpty) {
    tc['additional_vocab'] =
        c.customDictWords.map((w) => {'content': w}).toList();
  }
  if (c.punctuationEnabled) {
    final marks =
        c.punctuationMarks.map(_markSymbol).whereType<String>().toList();
    tc['punctuation_overrides'] = {
      if (marks.isNotEmpty) 'permitted_marks': marks,
      if (c.punctuationSensitivity != null)
        'sensitivity': c.punctuationSensitivity,
    };
  } else {
    tc['punctuation_overrides'] = {
      'permitted_marks': <String>[],
    };
  }
  if (c.engine.supportsDisfluencyRemoval && c.disfluencyRemoval) {
    tc['transcript_filtering_config'] = {'remove_disfluencies': true};
  }
  if (c.engine.mode == LiveMode.standard && c.audioFiltering) {
    tc['audio_filtering_config'] = {'volume_threshold': c.volumeThreshold ?? 0};
  }

  final msg = <String, dynamic>{
    'message': 'StartRecognition',
    'audio_format': {
      'type': 'raw',
      'encoding': 'pcm_s16le',
      'sample_rate': sampleRate,
    },
    'transcription_config': tc,
  };

  if (c.engine.supportsTranslation && c.translationTargets.isNotEmpty) {
    msg['translation_config'] = {
      'target_languages': c.translationTargets.take(5).toList(),
      'enable_partials': c.partials,
    };
  }
  if (c.engine.supportsAudioEvents && c.audioEventTypes.isNotEmpty) {
    msg['audio_events_config'] = {'types': c.audioEventTypes};
  }

  return msg;
}
