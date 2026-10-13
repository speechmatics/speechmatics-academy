import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/api_keys.dart';
import '../data/audio_file.dart';
import '../data/audio_store.dart';
import '../data/config_mapper.dart';
import '../data/dto/job_status.dart';
import '../data/google_translate_client.dart';
import '../data/speechmatics_client.dart';
import '../data/transcript_parser.dart';
import '../models/history_item.dart';
import '../models/job_config.dart';
import 'history_store.dart';

enum JobPhase { idle, submitting, polling, parsing, translating, done, error }

/// Orchestrates one transcription job end-to-end and drives the Synthesizing
/// screen. Produces a [HistoryItem], saves it to [HistoryStore], and exposes
/// the result id for navigation.
///
/// The audio is persisted to [AudioStore] BEFORE the job is submitted, so a
/// job that dies on the network (or is rejected) still lands in History as a
/// failed item that can be retried — a transient outage never loses a take.
class JobController extends ChangeNotifier {
  JobController({required this.apiKeys, required this.history});

  final ApiKeys apiKeys;
  final HistoryStore history;

  JobPhase phase = JobPhase.idle;
  String? error;
  List<String> detectedLanguages = [];
  String? resultId;
  bool translationSkipped = false;

  /// Id of the failed HistoryItem persisted for the current error (audio +
  /// original config saved) — non-null exactly when Retry is possible.
  String? failedItemId;

  bool _busy = false;
  bool _cancelled = false;

  /// True while a job is running end-to-end. `phase` is NOT a reliable proxy —
  /// cancel() flips it to idle while the pipeline is still winding down.
  bool get busy => _busy;

  void _set(JobPhase p) {
    phase = p;
    notifyListeners();
  }

  void cancel() {
    _cancelled = true;
    if (_busy) _set(JobPhase.idle);
  }

  /// Re-runs a failed History item with its persisted audio and the exact
  /// config it was originally submitted with. Returns false when the retry
  /// could not start (busy, item gone, or audio unreadable).
  Future<bool> retry(String itemId) async {
    if (_busy) return false;
    final item = history.byId(itemId);
    final audioFile = item?.audioFile;
    if (item == null || !item.failed || audioFile == null) return false;

    List<int> bytes;
    try {
      final path = await AudioStore.resolve(audioFile);
      if (path == null) throw StateError('audio missing');
      bytes = await readAudioBytes(path);
    } catch (_) {
      error = 'The saved audio for this recording could not be read.';
      failedItemId = null;
      _set(JobPhase.error);
      return false;
    }

    // Fire-and-forget: callers navigate to the Synthesizing screen, which
    // renders progress from the phase notifications.
    unawaited(startJob(
      audioBytes: bytes,
      filename: audioFile,
      config: JobConfig.fromJson(item.retryConfig ?? const {}),
      title: item.title,
      reuseItemId: item.id,
      presavedAudioFile: audioFile,
    ));
    return true;
  }

  Future<void> startJob({
    required List<int> audioBytes,
    required String filename,
    required JobConfig config,
    required String title,
    bool conversation = false,
    String? reuseItemId,
    String? presavedAudioFile,
  }) async {
    if (_busy) return;
    _busy = true;
    _cancelled = false;
    error = null;
    detectedLanguages = [];
    resultId = null;
    translationSkipped = false;
    failedItemId = null;
    _set(JobPhase.submitting);

    // Retries reuse the failed item's id so success REPLACES it in History.
    final id = reuseItemId ?? 't-${DateTime.now().microsecondsSinceEpoch}';
    String? audioFile = presavedAudioFile;
    var freshSave = false; // audio written by THIS run (cleaned up on cancel)
    var persisted = false; // a HistoryItem (result or failed) now owns the audio
    String jobId = '';

    SpeechmaticsClient? sm;
    try {
      final smKey = await apiKeys.speechmatics();
      if (smKey == null) {
        throw 'Add your Speechmatics API key in Settings to transcribe.';
      }
      if (audioBytes.isEmpty) throw 'The selected audio file is empty.';

      // Persist the take BEFORE submitting — from here on, no failure mode
      // short of storage loss can destroy the recording. Best-effort: on
      // platforms without persistence (web) the job simply runs as before.
      if (audioFile == null) {
        try {
          audioFile = await AudioStore.save(
              itemId: id, bytes: audioBytes, sourceFilename: filename);
          freshSave = true;
        } catch (_) {}
      }

      sm = SpeechmaticsClient(apiKey: smKey, region: config.region);
      final body = ConfigMapper.build(config);
      jobId = await sm.submitJob(
        audioBytes: audioBytes,
        filename: filename,
        config: body,
      );
      if (_cancelled) return;

      _set(JobPhase.polling);
      int? durationSeconds;
      await for (final status in sm.pollUntilDone(jobId)) {
        if (_cancelled) return;
        durationSeconds = status.durationSeconds ?? durationSeconds;
        if (status.state == JobState.rejected) {
          throw status.error ?? 'The job was rejected by Speechmatics.';
        }
        if (status.isDone) break;
      }
      if (_cancelled) return;

      _set(JobPhase.parsing);
      final tjson = await sm.getTranscript(jobId);
      final parsed = parseJsonV2(
        tjson,
        diarized: config.diarization && config.diarizationType == 'speaker',
      );
      // Speech-intelligence blocks (all null on omni-v1 responses).
      final insights = parseInsights(tjson);
      String? srtText;
      if (config.isClassic && config.subtitlesEnabled) {
        try {
          final srt = await sm.getTranscriptRaw(jobId, format: 'srt');
          if (srt.trim().isNotEmpty) srtText = srt;
        } catch (_) {
          // Tolerated: the item simply has no subtitles.
        }
      }
      if (_cancelled) return;
      detectedLanguages = parsed.languages.toList()..sort();
      durationSeconds = parsed.durationSeconds ?? durationSeconds;
      notifyListeners();

      if (parsed.segments.isEmpty) {
        throw 'No speech was detected in the audio.';
      }

      // ---- Translation (Google) ----
      String? translationText;
      if (config.translationEnabled) {
        final gKey = await apiKeys.google();
        if (gKey == null) {
          translationSkipped = true;
        } else {
          _set(JobPhase.translating);
          final translator = GoogleTranslateClient(apiKey: gKey);
          try {
            final translated = await translator.translate(
              q: parsed.segmentTexts,
              target: config.targetLanguageCode,
            );
            translationText = translated.join('\n').trim();
          } finally {
            translator.dispose();
          }
        }
      }
      if (_cancelled) return;

      final item = _buildItem(
        id: id,
        parsed: parsed,
        title: title,
        config: config,
        jobId: jobId,
        translationText: translationText,
        durationSeconds: durationSeconds,
        audioFile: audioFile,
        insights: insights,
        srtText: srtText,
      );
      history.add(item); // upsert — a retried failure is replaced by its result
      persisted = true;
      resultId = item.id;
      _set(JobPhase.done);
    } catch (e) {
      // A cancelled job that then errors is still just cancelled — no failed
      // item, no error screen; the finally block reclaims the audio.
      if (_cancelled) return;
      final raw = e.toString().replaceFirst('Exception: ', '');
      if (audioFile != null) {
        history.add(HistoryItem(
          id: id,
          type: HistoryType.batch,
          title: title,
          jobId: jobId,
          languages: const [],
          relativeLabel: 'Just now',
          bucket: 'today',
          model: config.modelDisplayName,
          createdAt: DateTime.now(),
          audioFile: audioFile,
          failed: true,
          errorText: raw,
          retryConfig: config.toJson(),
        ));
        persisted = true;
        failedItemId = id;
      }
      error = _friendlyError(raw, saved: failedItemId != null);
      _set(JobPhase.error);
    } finally {
      sm?.dispose();
      // A cancelled run persists nothing — don't strand its audio on disk.
      if (_cancelled && freshSave && !persisted) {
        unawaited(AudioStore.delete(audioFile));
      }
      _busy = false;
    }
  }

  /// Marks of a connection-level failure (the request never reached the API).
  static const _networkMarks = [
    'SocketException',
    'SocketConnection',
    'ClientException',
    'Network is unreachable',
    'Failed host lookup',
    'Connection refused',
    'Connection reset',
    'Connection closed',
    'connection abort',
    'Connection timed out',
    'Broken pipe',
    'HandshakeException',
  ];

  static String _friendlyError(String raw, {required bool saved}) {
    final isNetwork = _networkMarks.any(raw.contains);
    if (isNetwork) {
      final note = saved
          ? 'Your recording is safe — retry below, or later from History.'
          : 'Check Wi-Fi or mobile data and try again.';
      return 'Could not reach the transcription service — the phone had no '
          'working internet route. $note\n\n($raw)';
    }
    return saved ? '$raw\n\nYour recording is saved in History.' : raw;
  }

  HistoryItem _buildItem({
    required String id,
    required ParsedTranscript parsed,
    required String title,
    required JobConfig config,
    required String jobId,
    String? translationText,
    int? durationSeconds,
    String? audioFile,
    SpeechInsights insights = const SpeechInsights(),
    String? srtText,
  }) {
    final now = DateTime.now();
    final langs = parsed.languages.toList()..sort();
    // Counts fall back to tallying detected marks when the summary block is
    // absent; null when neither exists.
    Map<String, int>? eventCounts = insights.audioEventCounts;
    if (eventCounts == null && parsed.audioEvents.isNotEmpty) {
      eventCounts = <String, int>{};
      for (final m in parsed.audioEvents) {
        eventCounts[m.type] = (eventCounts[m.type] ?? 0) + 1;
      }
    }
    return HistoryItem(
      id: id,
      type: HistoryType.batch,
      title: title,
      jobId: jobId,
      languages: langs,
      arrow: translationText != null && langs.isNotEmpty ? '→' : '',
      relativeLabel: 'Just now',
      bucket: 'today',
      duration: durationSeconds != null ? _fmtDuration(durationSeconds) : null,
      model: config.modelDisplayName,
      translation: translationText != null,
      speakers: parsed.speakerCount > 0 ? parsed.speakerCount : null,
      segments: parsed.segments,
      translationText: translationText,
      createdAt: now,
      targetLanguage: translationText != null ? config.targetLanguageName : null,
      audioFile: audioFile,
      summaryText: insights.summaryText,
      topicCounts: insights.topicCounts,
      chapters: insights.chapters,
      audioEventCounts: eventCounts,
      audioEventMarks: parsed.audioEvents.isEmpty ? null : parsed.audioEvents,
      srtText: srtText,
    );
  }

  static String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
