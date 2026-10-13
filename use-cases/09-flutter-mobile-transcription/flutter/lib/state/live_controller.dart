import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_config.dart';
import '../data/api_keys.dart';
import '../data/google_translate_client.dart';
import '../data/rt_client.dart';
import '../data/rt_protocol.dart';
import '../models/google_lang_catalog.dart';
import '../models/history_item.dart';
import 'history_store.dart';
import 'live_transcript_builder.dart';
import 'settings_store.dart';

enum LivePhase { idle, connecting, live, finishing }

enum LiveStopOutcome { saved, empty, cancelled }

/// One Google-translated finalized caption. Appears pending first, then fills
/// in when the translation response arrives.
class LiveGoogleLine {
  LiveGoogleLine({this.speaker, required this.atSeconds});
  final String? speaker; // 'S1', … when diarized
  final int atSeconds; // session clock when the source finalized
  String text = '';
  bool done = false;
}

class LiveStopResult {
  const LiveStopResult(this.outcome, {this.itemId, this.error});
  final LiveStopOutcome outcome;
  final String? itemId;
  final String? error;
}

/// Orchestrates one live session end-to-end: mic PCM stream → websocket →
/// builders → (on stop) a conversation-type HistoryItem.
///
/// One instance per screen per session — sessions are screen-modal (the
/// cancel bar replaces the nav while live), so a controller never outlives
/// its screen. Owns its own [AudioRecorder]; Home's file-recorder is separate.
class LiveController extends ChangeNotifier {
  LiveController({
    required this.mode,
    required this.settings,
    required this.apiKeys,
    required this.history,
    AudioRecorder? recorder,
  }) : _recorder = recorder ?? AudioRecorder();

  final LiveMode mode;
  final SettingsStore settings;
  final ApiKeys apiKeys;
  final HistoryStore history;
  final AudioRecorder _recorder;

  LivePhase phase = LivePhase.idle;
  int elapsedSeconds = 0;

  /// Set when the session dies mid-flight (server Error / socket drop). The
  /// screen salvage-saves whatever was assembled and shows the message.
  String? sessionError;

  final LiveTranscriptBuilder transcript = LiveTranscriptBuilder();

  /// Google-translated units in arrival order — one entry per finalized
  /// caption. The same pipeline
  /// Batch uses; native RT translation is never requested.
  final List<LiveGoogleLine> googleLines = [];

  /// Joined finalized translation text (History/display convenience).
  String get googleTranslation => googleLines
      .where((l) => l.done && l.text.isNotEmpty)
      .map((l) => l.text)
      .join(' ');

  bool get translationActive => _translator != null;
  String? get googleTargetCode => _googleTargetCode;

  RtSession? _session;
  StreamSubscription<RtEvent>? _eventSub;
  StreamSubscription? _micSub;
  Timer? _clock;
  String _recognitionId = '';
  late RtSessionConfig _config;
  bool _disposed = false;
  GoogleTranslateClient? _translator;
  String? _googleTargetCode;
  Future<void> _translateChain = Future.value();
  int _rtTxPointer = 0; // next CLOSED caption line awaiting translation

  String get langCode => settings.rtLanguage;
  bool get isLive => phase == LivePhase.live;
  bool get _hasContent => !transcript.isEmpty;

  /// Starts the session. Returns null on success, else a user-facing error
  /// (nothing was started). Wakelock is held for the duration on success.
  Future<String?> start() async {
    if (phase != LivePhase.idle) return null;
    phase = LivePhase.connecting;
    notifyListeners();

    try {
      final key = await apiKeys.speechmatics();
      if (key == null) {
        return _startFailed(
            'Add your Speechmatics API key in Settings to transcribe.');
      }
      if (settings.rtTranslation) {
        final gKey = await apiKeys.google();
        if (gKey == null) {
          return _startFailed(
              'Add your Google Translate API key in Settings to use live translation — or turn translation off.');
        }
        _translator = GoogleTranslateClient(apiKey: gKey);
        _googleTargetCode = settings.rtTargetLanguageCode;
      }
      if (!await _recorder.hasPermission()) {
        return _startFailed(
            'Microphone permission is required — enable it in system Settings.');
      }

      // Match the actual capture rate (iOS insurance mirrors the batch path:
      // its capture stack misbehaves below the native 48 kHz).
      final sampleRate =
          defaultTargetPlatform == TargetPlatform.iOS ? 48000 : 16000;
      _config = settings.rtSnapshot();

      final session = RtSession(
        apiKey: key,
        endpoint: Uri.parse(_config.endpoint),
        startRecognition:
            buildStartRecognition(_config, sampleRate: sampleRate),
      );
      _session = session;
      _eventSub = session.events.listen(_onEvent);
      await session.start();

      final mic = await _recorder.startStream(RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        streamBufferSize: AppConfig.rtChunkBytes,
        androidConfig: const AndroidRecordConfig(),
      ));
      _micSub = mic.listen(session.addAudio);

      unawaited(WakelockPlus.enable());
      elapsedSeconds = 0;
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        elapsedSeconds++;
        notifyListeners();
      });
      phase = LivePhase.live;
      notifyListeners();
      return null;
    } catch (e) {
      await _session?.abort();
      _session = null;
      return _startFailed(_describeStartError(e));
    }
  }

  String _startFailed(String message) {
    phase = LivePhase.idle;
    notifyListeners();
    return message;
  }

  static String _describeStartError(Object e) {
    final s = e.toString();
    if (s.contains('401') || s.contains('not_authorised')) {
      return 'Speechmatics rejected the API key — check it in Settings.';
    }
    if (s.contains('TimeoutException')) {
      return 'Could not reach the live transcription service — check your connection and try again.';
    }
    return 'Could not start the live session: $s';
  }

  void _onEvent(RtEvent e) {
    if (e is RecognitionStartedEvent) _recognitionId = e.id;
    transcript.add(e);
    // Translate per CLOSED caption line (utterance), preserving complete units.
    _scanRtTranslation(includeOpen: false);
    if (e is RtErrorEvent && phase == LivePhase.live) {
      // Mid-session failure: stop capture, keep everything assembled. The
      // screen decides between salvage-save and plain error UI.
      sessionError = e.reason;
      _stopCaptureOnly();
      notifyListeners();
      return;
    }
    if (e is SocketClosedEvent && phase == LivePhase.live) {
      sessionError ??= 'Connection lost';
      _stopCaptureOnly();
      notifyListeners();
      return;
    }
    notifyListeners();
  }

  void _stopCaptureOnly() {
    _clock?.cancel();
    unawaited(_micSub?.cancel());
    unawaited(_recorder.stop());
    unawaited(WakelockPlus.disable());
  }

  /// Queues translations for caption lines. During a session only CLOSED
  /// lines go out (utterance-sized units); at stop the tail line flushes too.
  void _scanRtTranslation({required bool includeOpen}) {
    if (_translator == null || mode != LiveMode.standard) return;
    final limit = includeOpen
        ? transcript.lines.length
        : transcript.lines.length - (transcript.lineOpen ? 1 : 0);
    while (_rtTxPointer < limit) {
      final l = transcript.lines[_rtTxPointer];
      if (l.text.trim().isNotEmpty) _queueTranslate(l.text, l.speaker);
      _rtTxPointer++;
    }
  }

  /// Translates one finalized unit via Google. A pending line appears
  /// immediately (TRANSLATING… in the UI) and fills in when the response
  /// lands; the chain keeps arrival order. Per-line failures never kill a
  /// session — the pending line is simply withdrawn.
  void _queueTranslate(String text, String? speaker) {
    final translator = _translator;
    final target = _googleTargetCode;
    final t = text.trim();
    if (translator == null || target == null || t.isEmpty) return;
    final line = LiveGoogleLine(speaker: speaker, atSeconds: elapsedSeconds);
    googleLines.add(line);
    if (!_disposed) notifyListeners();
    _translateChain = _translateChain.then((_) async {
      try {
        final out = await translator.translate(q: [t], target: target);
        if (out.isEmpty || out.first.trim().isEmpty) {
          googleLines.remove(line);
        } else {
          line.text = out.first.trim();
          line.done = true;
        }
      } catch (_) {
        googleLines.remove(line);
      }
      if (!_disposed) notifyListeners();
    });
  }

  /// Ends the session and saves to History when there is content.
  Future<LiveStopResult> stop() async {
    if (phase != LivePhase.live) {
      // Salvage path after a mid-session error: capture already stopped.
      if (sessionError != null && _hasContent) {
        final id = _save();
        return LiveStopResult(LiveStopOutcome.saved,
            itemId: id, error: sessionError);
      }
      return LiveStopResult(
          sessionError == null ? LiveStopOutcome.cancelled : LiveStopOutcome.empty,
          error: sessionError);
    }
    phase = LivePhase.finishing;
    notifyListeners();

    _clock?.cancel();
    await _micSub?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    unawaited(WakelockPlus.disable());
    await _session?.finish(); // drains trailing finals into the builder
    if (_translator != null) {
      // The tail caption line never closed — flush it, then a bounded wait
      // for trailing Google translations.
      _scanRtTranslation(includeOpen: true);
      try {
        await _translateChain.timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    if (!_hasContent) {
      phase = LivePhase.idle;
      notifyListeners();
      return const LiveStopResult(LiveStopOutcome.empty);
    }
    final id = _save();
    phase = LivePhase.idle;
    notifyListeners();
    return LiveStopResult(LiveStopOutcome.saved, itemId: id);
  }

  String _save() {
    final gCode = _googleTargetCode;
    final hasGoogle = gCode != null && googleTranslation.trim().isNotEmpty;
    final item = buildLiveHistoryItem(
      mode: mode,
      lines: transcript.lines,
      langCode: langCode,
      recognitionId: _recognitionId,
      elapsedSeconds: elapsedSeconds,
      translations: hasGoogle
          ? {gCode.toLowerCase(): googleTranslation}
          : transcript.translations,
      translationTargets: hasGoogle
          ? [gCode]
          : (_configOrNull?.translationTargets ?? const []),
      eventMarks: transcript.events,
      now: DateTime.now(),
    );
    history.add(item);
    return item.id;
  }

  RtSessionConfig? get _configOrNull {
    try {
      return _config;
    } catch (_) {
      return null;
    }
  }

  /// Discards the session entirely — nothing is saved.
  Future<void> cancel() async {
    _clock?.cancel();
    await _micSub?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    unawaited(WakelockPlus.disable());
    await _session?.abort();
    phase = LivePhase.idle;
    if (!_disposed) notifyListeners();
  }

  /// Resume-check hook: false when the OS killed the capture session.
  Future<bool> recorderAlive() async {
    try {
      return await _recorder.isRecording();
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _clock?.cancel();
    _eventSub?.cancel();
    _micSub?.cancel();
    _session?.abort();
    _recorder.dispose();
    _translator?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }
}

/// Builds the saved HistoryItem for a live session. Pure — unit-testable.
HistoryItem buildLiveHistoryItem({
  required LiveMode mode,
  required List<LiveLine> lines,
  required String langCode,
  required String recognitionId,
  required int elapsedSeconds,
  Map<String, String> translations = const {},
  List<String> translationTargets = const [],
  List<LiveEventMark> eventMarks = const [],
  required DateTime now,
}) {
  final lang = langCode.toUpperCase();
  final conversation = <ConversationTurn>[];

  String role(String? speaker) {
    if (speaker == null || speaker.isEmpty) return 'You';
    final m = RegExp(r'^S(\d+)$').firstMatch(speaker);
    if (m != null) return 'Speaker ${m.group(1)}';
    return speaker;
  }

  for (final l in lines) {
    if (l.text.trim().isEmpty) continue;
    conversation.add(ConversationTurn(
        role: role(l.speaker), lang: lang, text: l.text.trim()));
  }

  final speakerRoles = conversation
      .map((t) => t.role)
      .where((r) => r != 'You')
      .toSet();

  // Primary translation target only (display parity with batch items).
  String? translationText;
  String? targetLanguage;
  if (translationTargets.isNotEmpty) {
    final primary = translationTargets.first;
    final text = translations[primary.toLowerCase()];
    if (text != null && text.trim().isNotEmpty) {
      translationText = text.trim();
      targetLanguage = GoogleLangCatalog.byCode(primary)?.name ?? primary;
    }
  }

  Map<String, int>? eventCounts;
  if (eventMarks.isNotEmpty) {
    eventCounts = <String, int>{};
    for (final e in eventMarks) {
      eventCounts[e.type] = (eventCounts[e.type] ?? 0) + 1;
    }
  }

  final m = elapsedSeconds ~/ 60;
  final s = (elapsedSeconds % 60).toString().padLeft(2, '0');

  return HistoryItem(
    id: 'live-${now.microsecondsSinceEpoch}',
    type: HistoryType.conversation,
    title: 'Live session',
    // Live sessions have no retrievable job — the RecognitionStarted id is a
    // transient session id, not a job id, so surfacing it only misleads.
    jobId: '',
    languages: [
      lang,
      if (targetLanguage != null && translationTargets.isNotEmpty)
        translationTargets.first.toUpperCase(),
    ],
    arrow: translationText != null ? '→' : '',
    relativeLabel: 'Just now',
    bucket: 'today',
    duration: '$m:$s',
    model: 'RT',
    translation: translationText != null,
    speakers: speakerRoles.isEmpty ? null : speakerRoles.length,
    conversation: conversation,
    translationText: translationText,
    createdAt: now,
    targetLanguage: targetLanguage,
    audioEventCounts: eventCounts,
  );
}
