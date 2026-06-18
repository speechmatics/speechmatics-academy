import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../data/audio_file.dart';
import '../routes.dart';
import '../state/job_controller.dart';
import '../state/settings_store.dart';
import '../state/speaker_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_top_bar.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with SingleTickerProviderStateMixin {
  static const _barCount = 15;
  final _rand = Random();
  final _recorder = AudioRecorder();

  List<double> _levels = List.filled(_barCount, 0.08);
  int _seconds = 0;
  bool _recording = false;
  bool _starting = false;
  String _mode = 'single';
  String? _path;

  Timer? _viz;
  Timer? _clock;
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _viz = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      setState(() {
        _levels = List.generate(
          _barCount,
          (_) => _recording ? 0.15 + _rand.nextDouble() * 0.85 : 0.08,
        );
      });
    });
  }

  @override
  void dispose() {
    _viz?.cancel();
    _clock?.cancel();
    _pulse.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_starting) return;
    if (!_recording) {
      await _startRecording();
    } else {
      await _stopAndSubmit();
    }
  }

  Future<void> _startRecording() async {
    setState(() => _starting = true);
    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        if (mounted) _snack('Microphone permission is required to record.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/sm_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          // iOS 26's AVAudioRecorder can't resample the 48 kHz built-in mic down to
          // a lower requested rate — it silently writes an empty, zero-sample file.
          // Capture at the native 48 kHz on iOS; Android resamples fine, so keep its
          // smaller 16 kHz output. Speechmatics accepts either rate.
          sampleRate: defaultTargetPlatform == TargetPlatform.iOS ? 48000 : 16000,
          numChannels: 1,
        ),
        path: path,
      );
      _path = path;
      _seconds = 0;
      setState(() => _recording = true);
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    } catch (e) {
      if (mounted) _snack('Could not start recording: $e');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stopAndSubmit() async {
    _clock?.cancel();
    setState(() => _recording = false);
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    path ??= _path;
    if (path == null) {
      if (mounted) _snack('Recording failed.');
      return;
    }

    List<int> bytes;
    try {
      bytes = await readAudioBytes(path);
    } catch (e) {
      if (mounted) _snack('Could not read recording: $e');
      return;
    }
    // AudioStore keeps the durable copy on job success; the temp file is done.
    unawaited(deleteAudioFile(path));
    // A silent/failed capture writes only an AAC container header (a few hundred
    // bytes) — non-empty, but far too small for valid audio, so the server
    // rejects submission with a cryptic "data_file is too small". Surface the
    // real numbers (duration + bytes) so a mic/audio-session problem is obvious
    // here instead of as a 400 after upload.
    const minValidBytes = 8000; // header-only files are only a few hundred bytes
    if (bytes.length < minValidBytes) {
      if (mounted) {
        _snack('Recording captured almost no audio — ${_seconds}s but only '
            '${bytes.length} bytes. The mic isn\'t picking up sound; '
            'check input/Silent switch and try again.');
      }
      return;
    }
    if (!mounted) return;

    final settings = context.read<SettingsStore>();
    final stamp = TimeOfDay.fromDateTime(DateTime.now()).format(context);
    context.read<JobController>().startJob(
          audioBytes: bytes,
          filename: 'recording.m4a',
          config: settings.snapshot(speakers: context.read<SpeakerStore>().profiles),
          title: 'Recording $stamp',
          conversation: _mode == 'conversation',
        );
    Navigator.pushReplacementNamed(context, Routes.synthesizing);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

  String get _time {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _recording ? AppColors.recordActive : AppColors.primary;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: BrandTopBar(
        leading: TopBarLeading.back,
        onLeading: () => Navigator.pushReplacementNamed(context, Routes.home),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 160,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (final lvl in _levels)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              width: 8,
                              height: 16 + lvl * 130,
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Short clips give the omnilingual model too little signal
                  // for reliable language detection — nudge toward 14s+.
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Symbols.tips_and_updates, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Tip: record at least 14 seconds for best results',
                          style: AppType.body(
                              size: 12, weight: FontWeight.w600, color: AppColors.primary)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Text(_time,
                      style: AppType.mono(size: 64, weight: FontWeight.w700, color: AppColors.onSurface)
                          .copyWith(letterSpacing: -2)),
                  const SizedBox(height: 8),
                  Text(_recording ? 'RECORDING' : 'READY TO RECORD',
                      style: AppType.labelCaps(size: 10, color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 48),
                  _modeSwitcher(),
                  const SizedBox(height: 48),
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) {
                      final t = _recording ? 0.0 : Curves.easeInOut.transform(_pulse.value);
                      return GestureDetector(
                        onTap: _toggle,
                        child: Transform.scale(
                          scale: 1 + 0.08 * t,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.4 + 0.3 * t),
                                  blurRadius: 24 + 26 * t,
                                  spreadRadius: -2 + 8 * t,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _recording
                                  // Stop indicator while recording.
                                  ? Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    )
                                  // Mic to start recording.
                                  : const Icon(Symbols.mic, color: Colors.white, size: 42, fill: 1),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _statusChip(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Container(
                    width: 1,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.outline.withValues(alpha: 0.4)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: 0.4,
                    // letterSpacing adds trailing space after the LAST glyph
                    // too, nudging centred text left — balance it with an equal
                    // left inset so the label sits dead-centre.
                    child: Padding(
                      padding: const EdgeInsets.only(left: 3),
                      // Keep V… in sync with pubspec.yaml `version:` for releases.
                      child: Text('EVERYVOICE · LINGUISTIC PRECISION ENGINE\nV1.0.0 (4)',
                          textAlign: TextAlign.center,
                          style: AppType.labelCaps(size: 9, color: AppColors.onSurface)
                              .copyWith(letterSpacing: 3, height: 1.8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeSwitcher() {
    Widget btn(String value, String label, {bool enabled = true}) {
      final active = _mode == value;
      final seg = AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: AppType.labelCaps(
                size: 10, color: active ? Colors.white : AppColors.onSurfaceVariant)),
      );
      // Live = the upcoming real-time mode; visible but not selectable yet.
      if (!enabled) return Opacity(opacity: 0.4, child: seg);
      return GestureDetector(
        onTap: _recording ? null : () => setState(() => _mode = value),
        child: seg,
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn('single', 'RECORD'),
        btn('conversation', 'LIVE', enabled: false),
      ]),
    );
  }

  Widget _statusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Symbols.language, size: 16, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(_recording ? 'Recording — tap to transcribe' : 'Listening for any language...',
            style: AppType.body(
                size: 14, weight: FontWeight.w500, color: AppColors.onSurfaceVariant)),
      ]),
    );
  }
}
