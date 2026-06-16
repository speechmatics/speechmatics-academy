import 'package:flutter/material.dart';

import '../models/history_item.dart';
import '../widgets/word_highlight.dart';

/// Web stub — playback isn't supported (audio_waveforms needs dart:io and the
/// live pipeline doesn't run on web anyway). [create] always returns null, so
/// none of the members below are ever exercised at runtime.
class TranscriptPlayer {
  TranscriptPlayer._();

  final ValueNotifier<bool> isPlaying = ValueNotifier(false);
  final ValueNotifier<bool> waveformFailed = ValueNotifier(false);
  final ValueNotifier<int> positionMs = ValueNotifier(0);
  final ValueNotifier<ActiveWord?> activeWord = ValueNotifier(null);
  final ValueNotifier<List<double>?> waveData = ValueNotifier(null);

  int get maxDurationMs => 0;

  static Future<TranscriptPlayer?> create(HistoryItem item) async => null;

  Future<void> toggle() async {}
  Future<void> ensureWaveform(int noOfSamples) async {}
  Future<void> seekToMs(int ms) async {}
  Future<void> playFrom(double seconds) async {}
  Future<void> stopAndSeek(double seconds) async {}
  Future<void> stop() async {}
  void dispose() {}
}

class WaveformBar extends StatelessWidget {
  const WaveformBar({super.key, required this.player, this.height = 48});

  final TranscriptPlayer player;
  final double height;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class PlaybackBar extends StatelessWidget {
  const PlaybackBar({super.key, required this.player, this.height = 40});

  final TranscriptPlayer player;
  final double height;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
