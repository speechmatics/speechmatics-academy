import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persists submitted audio so transcripts can be played back later.
///
/// Files live in `<app documents>/audio/<historyItemId>.<ext>`. Only the file
/// NAME is stored on `HistoryItem.audioFile` — the documents directory is
/// resolved at runtime (iOS app-container paths change between launches).
class AudioStore {
  AudioStore._();

  static const _allowedExts = {'m4a', 'wav', 'mp3', 'flac', 'ogg', 'aac', 'opus'};

  static Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}${Platform.pathSeparator}audio').create(recursive: true);
  }

  static String _ext(String sourceFilename) {
    final dot = sourceFilename.lastIndexOf('.');
    if (dot < 0) return 'm4a';
    final ext = sourceFilename.substring(dot + 1).toLowerCase();
    return _allowedExts.contains(ext) ? ext : 'm4a';
  }

  /// Writes the audio and returns the stored file NAME (e.g. `t-123.m4a`).
  static Future<String> save({
    required String itemId,
    required List<int> bytes,
    required String sourceFilename,
  }) async {
    final dir = await _dir();
    final name = '$itemId.${_ext(sourceFilename)}';
    await File('${dir.path}${Platform.pathSeparator}$name').writeAsBytes(bytes, flush: true);
    return name;
  }

  /// Resolves a stored name to an absolute path, or null when absent/missing.
  static Future<String?> resolve(String? audioFile) async {
    if (audioFile == null || audioFile.isEmpty) return null;
    final dir = await _dir();
    final f = File('${dir.path}${Platform.pathSeparator}$audioFile');
    return await f.exists() ? f.path : null;
  }

  /// Best-effort removal of the clip AND its waveform sidecar (item deleted).
  static Future<void> delete(String? audioFile) async {
    if (audioFile == null || audioFile.isEmpty) return;
    try {
      final dir = await _dir();
      for (final name in [audioFile, _sidecarName(audioFile)]) {
        final f = File('${dir.path}${Platform.pathSeparator}$name');
        if (await f.exists()) await f.delete();
      }
    } catch (_) {
      // Non-fatal: orphaned audio is preferable to a failed delete.
    }
  }

  // ---- waveform sidecar (<itemId>.wave.json) ----
  // Extracted waveform samples persist next to the clip so reopening a
  // transcript shows the waveform instantly instead of re-decoding the audio.

  static String _sidecarName(String audioFile) {
    final dot = audioFile.lastIndexOf('.');
    final base = dot < 0 ? audioFile : audioFile.substring(0, dot);
    return '$base.wave.json';
  }

  /// Cached samples for [audioFile] at whatever count they were extracted —
  /// callers resample to their display width. Null on miss/corrupt.
  static Future<List<double>?> loadWaveform(String audioFile) async {
    try {
      final dir = await _dir();
      final f = File('${dir.path}${Platform.pathSeparator}${_sidecarName(audioFile)}');
      if (!await f.exists()) return null;
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return (m['data'] as List).map((e) => (e as num).toDouble()).toList();
    } catch (_) {
      return null;
    }
  }

  /// Persists extracted samples (best-effort; overwrites any previous sidecar).
  static Future<void> saveWaveform(String audioFile, int sampleCount, List<double> data) async {
    try {
      final dir = await _dir();
      final f = File('${dir.path}${Platform.pathSeparator}${_sidecarName(audioFile)}');
      await f.writeAsString(jsonEncode({'n': sampleCount, 'data': data}), flush: true);
    } catch (_) {
      // Non-fatal: next open just re-extracts.
    }
  }
}
