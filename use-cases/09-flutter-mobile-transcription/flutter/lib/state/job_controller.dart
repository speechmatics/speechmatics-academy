import 'package:flutter/foundation.dart';

import '../data/api_keys.dart';
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
class JobController extends ChangeNotifier {
  JobController({required this.apiKeys, required this.history});

  final ApiKeys apiKeys;
  final HistoryStore history;

  JobPhase phase = JobPhase.idle;
  String? error;
  List<String> detectedLanguages = [];
  String? resultId;
  bool translationSkipped = false;

  bool _busy = false;
  bool _cancelled = false;

  void _set(JobPhase p) {
    phase = p;
    notifyListeners();
  }

  void cancel() {
    _cancelled = true;
    if (_busy) _set(JobPhase.idle);
  }

  Future<void> startJob({
    required List<int> audioBytes,
    required String filename,
    required JobConfig config,
    required String title,
    bool conversation = false,
  }) async {
    if (_busy) return;
    _busy = true;
    _cancelled = false;
    error = null;
    detectedLanguages = [];
    resultId = null;
    translationSkipped = false;
    _set(JobPhase.submitting);

    SpeechmaticsClient? sm;
    try {
      final smKey = await apiKeys.speechmatics();
      if (smKey == null) {
        throw 'Add your Speechmatics API key in Settings to transcribe.';
      }
      if (audioBytes.isEmpty) throw 'The selected audio file is empty.';

      sm = SpeechmaticsClient(apiKey: smKey, region: config.region);
      final body = ConfigMapper.build(config);
      final jobId = await sm.submitJob(
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

      // Persist the audio for playback (best-effort — a failed save just means
      // the item has no play button, as before this feature existed).
      final id = 't-${DateTime.now().microsecondsSinceEpoch}';
      String? audioFile;
      try {
        audioFile = await AudioStore.save(
            itemId: id, bytes: audioBytes, sourceFilename: filename);
      } catch (_) {}

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
      history.add(item);
      resultId = item.id;
      _set(JobPhase.done);
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      _set(JobPhase.error);
    } finally {
      sm?.dispose();
      _busy = false;
    }
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
