import 'dart:async';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../data/audio_store.dart';
import '../models/history_item.dart';
import '../theme/app_colors.dart';
import '../widgets/word_highlight.dart';

class _WordRef {
  const _WordRef(this.start, this.end, this.ref);
  final double start;
  final double end;
  final ActiveWord ref;
}

/// Owns one [PlayerController] for a history item's persisted audio and maps
/// the playback position onto transcript words for highlight rendering.
///
/// Create via [TranscriptPlayer.create] (returns null when the item has no
/// playable audio). Always [dispose] when done.
class TranscriptPlayer {
  TranscriptPlayer._(this.controller, this._wordIndex, this._path, this._audioFile);

  final PlayerController controller;
  final List<_WordRef> _wordIndex;
  final String _path;
  final String _audioFile; // stored name — keys the waveform sidecar cache

  final ValueNotifier<bool> isPlaying = ValueNotifier(false);
  final ValueNotifier<bool> waveformFailed = ValueNotifier(false);
  final ValueNotifier<int> positionMs = ValueNotifier(0);
  final ValueNotifier<ActiveWord?> activeWord = ValueNotifier(null);

  StreamSubscription? _stateSub;
  StreamSubscription? _durSub;
  StreamSubscription? _compSub;
  bool _disposed = false;
  bool _begun = false; // playback initiated at least once
  bool _extractRequested = false;
  bool _prepared = false; // native player setup happens lazily, on first play
  Future<void>? _preparing;

  /// Waveform samples — from the persisted sidecar (instant) or extraction.
  /// A notifier so the WaveformBar repaints the moment samples arrive, and so
  /// the wave survives widget unmount/remount (view toggles).
  final ValueNotifier<List<double>?> waveData = ValueNotifier(null);

  int get maxDurationMs => controller.maxDuration;

  /// Cheap: NO native media-player work happens here — the waveform renders
  /// from cached samples and the player is prepared lazily on first play.
  /// This is what keeps expanding History cards lag-free.
  static Future<TranscriptPlayer?> create(HistoryItem item) async {
    final path = await AudioStore.resolve(item.audioFile);
    if (path == null) return null;

    final c = PlayerController()..updateFrequency = UpdateFrequency.high;
    final p = TranscriptPlayer._(c, _buildWordIndex(item), path, item.audioFile!);
    p._subscribe();
    return p;
  }

  /// Native player setup, deferred until the user actually presses play.
  Future<void> _ensurePrepared() {
    return _preparing ??= () async {
      try {
        await controller.preparePlayer(path: _path, shouldExtractWaveform: false);
        await controller.setFinishMode(finishMode: FinishMode.pause);
        _prepared = true;
      } catch (_) {
        // Unplayable codec — play stays a no-op; waveform still renders.
      }
    }();
  }

  /// Provides waveform samples sized for the rendered width (idempotent).
  /// The persisted sidecar (saved at ANY width) is resampled in Dart — audio
  /// is decoded at most ONCE per clip, ever, across both screens.
  Future<void> ensureWaveform(int noOfSamples) async {
    if (_extractRequested || _disposed) return;
    _extractRequested = true;

    final cached = await AudioStore.loadWaveform(_audioFile);
    if (_disposed) return;
    if (cached != null && cached.isNotEmpty) {
      waveData.value = _resample(cached, noOfSamples);
      return;
    }

    try {
      // The AudioFileWaveforms widget listens to the extraction stream on this
      // controller, so it renders progressively while this runs. Extraction
      // works on an unprepared controller (it has its own decoder).
      final data = await controller.waveformExtraction
          .extractWaveformData(path: _path, noOfSamples: noOfSamples);
      if (_disposed) return;
      waveData.value = data;
      await AudioStore.saveWaveform(_audioFile, noOfSamples, data);
    } catch (_) {
      if (!_disposed) waveformFailed.value = true; // → Slider fallback
    }
  }

  /// Bucket-averages [src] onto [n] samples (sidecar width ≠ widget width).
  static List<double> _resample(List<double> src, int n) {
    if (src.length == n || src.isEmpty || n <= 0) return src;
    return List<double>.generate(n, (i) {
      final start = (i * src.length / n).floor();
      var end = ((i + 1) * src.length / n).ceil();
      if (end <= start) end = start + 1;
      if (end > src.length) end = src.length;
      var sum = 0.0;
      for (var j = start; j < end; j++) {
        sum += src[j];
      }
      return sum / (end - start);
    });
  }

  static List<_WordRef> _buildWordIndex(HistoryItem item) {
    final index = <_WordRef>[];
    final segments = item.segments ?? const <TranscriptSegment>[];
    for (var s = 0; s < segments.length; s++) {
      final parts = segments[s].parts;
      for (var pIdx = 0; pIdx < parts.length; pIdx++) {
        final words = parts[pIdx].words;
        for (var w = 0; w < words.length; w++) {
          index.add(_WordRef(words[w].start, words[w].end, (seg: s, part: pIdx, word: w)));
        }
      }
    }
    index.sort((a, b) => a.start.compareTo(b.start));
    return index;
  }

  void _subscribe() {
    _stateSub = controller.onPlayerStateChanged.listen((state) {
      if (_disposed) return;
      isPlaying.value = state.isPlaying;
      // Pausing keeps the highlight frozen on the current word; it only ever
      // clears on completion (and is absent until playback first starts).
    });
    _durSub = controller.onCurrentDurationChanged.listen((ms) {
      if (_disposed) return;
      positionMs.value = ms;
      if (_begun) activeWord.value = _lookup(ms / 1000.0);
    });
    _compSub = controller.onCompletion.listen((_) async {
      if (_disposed) return;
      activeWord.value = null;
      isPlaying.value = false;
      positionMs.value = 0;
      await controller.seekTo(0);
    });
  }

  /// Binary search for the word containing [sec] (null in gaps/silence).
  ActiveWord? _lookup(double sec) {
    var lo = 0, hi = _wordIndex.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final w = _wordIndex[mid];
      if (sec < w.start) {
        hi = mid - 1;
      } else if (sec >= w.end) {
        lo = mid + 1;
      } else {
        return w.ref;
      }
    }
    return null;
  }

  Future<void> toggle() async {
    if (isPlaying.value) {
      await controller.pausePlayer();
      return;
    }
    // First play pays the (one-off) native prepare cost — off the expand path.
    await _ensurePrepared();
    if (_disposed || !_prepared) return;
    _begun = true;
    await controller.startPlayer();
  }

  /// Seeks to an absolute position (used by chapter taps). Prepares the
  /// player first if needed so the seek lands even before first play.
  Future<void> seekToMs(int ms) async {
    await _ensurePrepared();
    if (_disposed || !_prepared) return;
    await controller.seekTo(ms);
  }

  /// Starts playback at an absolute position — handles the cold-start case
  /// where the player was prepared but never started (seeks are ignored in
  /// the never-started state, so start FIRST, then seek).
  Future<void> playFrom(double seconds) async {
    await _ensurePrepared();
    if (_disposed || !_prepared) return;
    final ms = (seconds * 1000).round();
    _begun = true; // word highlight must track from here
    if (!isPlaying.value) {
      await controller.startPlayer();
    }
    await controller.seekTo(ms);
    // Cold-start race: if the first position tick still reports ~0 while we
    // asked for a mid-clip position, the seek landed before the native player
    // was truly rolling — retry it once.
    if (ms > 1500) {
      try {
        final tick = await controller.onCurrentDurationChanged.first
            .timeout(const Duration(milliseconds: 900));
        if (!_disposed && tick < 500) {
          await controller.seekTo(ms);
        }
      } catch (_) {
        // No tick arrived in time — playback state will correct itself.
      }
    }
  }

  /// Stops playback and parks the position at [seconds] (chapter-stop reset:
  /// the next play starts the chapter from its beginning).
  Future<void> stopAndSeek(double seconds) async {
    if (_disposed || !_prepared) return;
    try {
      await controller.pausePlayer();
      final ms = (seconds * 1000).round();
      await controller.seekTo(ms);
      positionMs.value = ms; // paused seeks may not tick — reflect it now
      activeWord.value = null; // a reset is a stop, not a freeze-frame
    } catch (_) {}
  }

  Future<void> stop() async {
    if (!_prepared) return;
    try {
      await controller.pausePlayer();
    } catch (_) {}
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stateSub?.cancel();
    _durSub?.cancel();
    _compSub?.cancel();
    controller.dispose();
    isPlaying.dispose();
    waveformFailed.dispose();
    positionMs.dispose();
    activeWord.dispose();
    waveData.dispose();
  }
}

/// Seekable waveform for a [TranscriptPlayer]; falls back to a plain seek
/// slider when waveform extraction fails (rare codecs).
class WaveformBar extends StatelessWidget {
  const WaveformBar({super.key, required this.player, this.height = 48});

  final TranscriptPlayer player;
  final double height;

  // Shared so the extraction sample count (getSamplesForWidth) and the painted
  // spacing agree — that keeps tap-to-seek (tapX / width) aligned with the
  // drawn waveform, which spans spacing × sampleCount pixels.
  static final PlayerWaveStyle _style = PlayerWaveStyle(
    fixedWaveColor: AppColors.surfaceContainerHighest,
    liveWaveColor: AppColors.primary,
    spacing: 5,
    waveThickness: 2.5,
    showSeekLine: true,
    seekLineColor: AppColors.primary,
    seekLineThickness: 2,
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: player.waveformFailed,
      builder: (context, failed, _) {
        if (failed) return _seekSlider();
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            // Sidecar-or-extract, sized exactly for this width (idempotent).
            player.ensureWaveform(_style.getSamplesForWidth(w));
            return ValueListenableBuilder<List<double>?>(
              valueListenable: player.waveData,
              builder: (context, data, _) => AudioFileWaveforms(
                // AudioFileWaveforms reads `waveformData` ONLY in initState (no
                // didUpdateWidget), so samples arriving after mount — the
                // sidecar cache hit — would be ignored and the bar stays blank.
                // Flipping the key when data lands forces a fresh State that
                // consumes it; while null, the 'live' instance stays mounted
                // and renders the extraction stream progressively.
                key: ValueKey(data == null ? 'wf-live' : 'wf-data-${data.length}'),
                size: Size(w, height),
                playerController: player.controller,
                waveformType: WaveformType.fitWidth,
                enableSeekGesture: true,
                waveformData: data ?? const [],
                playerWaveStyle: _style,
              ),
            );
          },
        );
      },
    );
  }

  Widget _seekSlider() {
    return SizedBox(
      height: height,
      child: ValueListenableBuilder<int>(
        valueListenable: player.positionMs,
        builder: (context, pos, _) {
          final max = player.maxDurationMs;
          return Slider(
            value: max > 0 ? pos.clamp(0, max).toDouble() : 0,
            max: max > 0 ? max.toDouble() : 1,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.surfaceContainerHighest,
            onChanged: max > 0 ? (v) => player.controller.seekTo(v.round()) : null,
          );
        },
      ),
    );
  }
}

/// The full playback strip: play/pause button ON the clip + seekable waveform.
/// Used identically on the transcription result screen and in expanded
/// History cards.
class PlaybackBar extends StatelessWidget {
  const PlaybackBar({super.key, required this.player, this.height = 40});

  final TranscriptPlayer player;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: player.isPlaying,
            builder: (context, playing, _) => IconButton(
              onPressed: () => player.toggle(),
              tooltip: playing ? 'Pause' : 'Play',
              icon: Icon(playing ? Symbols.pause : Symbols.play_arrow,
                  size: 22, color: AppColors.primary, fill: 1),
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.all(6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: WaveformBar(player: player, height: height)),
          const SizedBox(width: 8),
          Builder(
            builder: (context) => IconButton(
              onPressed: () {
                // iPad requires an anchor rect or the share sheet won't present.
                final box = context.findRenderObject() as RenderBox?;
                SharePlus.instance.share(ShareParams(
                  files: [XFile(player._path)],
                  sharePositionOrigin:
                      box != null ? box.localToGlobal(Offset.zero) & box.size : null,
                ));
              },
              tooltip: 'Share audio',
              icon: Icon(Symbols.share, size: 20, color: AppColors.primary),
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.all(6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
