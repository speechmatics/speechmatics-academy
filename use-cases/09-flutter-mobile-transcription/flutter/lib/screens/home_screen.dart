import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/api_keys.dart';
import '../data/audio_file.dart';
import '../data/rt_protocol.dart';
import '../models/history_item.dart';
import '../routes.dart';
import '../state/history_store.dart';
import '../state/job_controller.dart';
import '../state/live_controller.dart';
import '../state/live_transcript_builder.dart';
import '../state/settings_store.dart';
import '../state/speaker_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_top_bar.dart';
import '../widgets/lang_chip.dart';
import '../widgets/segmented_toggle.dart';
import '../widgets/session_cancel_bar.dart';
import '../widgets/speech_bottom_nav.dart';
import 'transcription_screen.dart';

/// Recorder lifecycle on the one-tap Home. `starting` and `stopping` are
/// dead zones for the mic button — they close the race where a second tap
/// during an async transition started a fresh recording mid-submit.
enum _RecPhase { idle, starting, recording, stopping }

/// Home IS the recorder: one tap on the thumb-zone mic starts capturing,
/// a second tap stops and submits to the existing Synthesizing flow.
/// While recording, the bottom nav is replaced by a CANCEL bar so a stray
/// tab tap can't destroy the take.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _barCount = 15;
  final _rand = Random();
  final _recorder = AudioRecorder();

  _RecPhase _phase = _RecPhase.idle;
  List<double> _levels = List.filled(_barCount, 0.08);
  int _seconds = 0;
  String _mode = 'single';
  String? _path;

  // LIVE mode (standard Speechmatics RT). One controller per session; null
  // while idle. The same mic button starts/stops it when _mode is
  // 'conversation'.
  LiveController? _live;
  bool _liveAutoStopping = false;
  int _liveSig = -1;
  final _liveScroll = ScrollController();
  final _transScroll = ScrollController();
  // ORIGINAL | TRANSLATION | SPLIT — only meaningful while translation is on;
  // sessions open in split (design default).
  String _liveView = 'split';
  bool _resumeHandled = false;

  Timer? _viz;
  Timer? _clock;

  late final AnimationController _ripple =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat(reverse: true);

  bool get _isRecording => _phase == _RecPhase.recording;
  bool get _looksIdle =>
      _phase == _RecPhase.idle || _phase == _RecPhase.starting;
  bool get _liveActive => _live != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // History's "Resume Conversation" reopens Home straight into a live
    // session with today's settings.
    if (_resumeHandled) return;
    _resumeHandled = true;
    if (ModalRoute.of(context)?.settings.arguments == 'resume-live') {
      _mode = 'conversation';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _live == null) _startLive();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viz?.cancel();
    _clock?.cancel();
    _ripple.dispose();
    _pulse.dispose();
    _liveScroll.dispose();
    _transScroll.dispose();
    // Best-effort teardown (tab switches replace this route). While a session
    // runs the nav is a CANCEL bar, so this is insurance, not a path.
    _live?.removeListener(_onLive);
    _live?.dispose();
    final path = _path;
    _recorder.dispose();
    if (path != null) unawaited(deleteAudioFile(path));
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_isRecording) _checkCaptureSurvived();
    final live = _live;
    if (live != null && live.isLive) {
      // Save what already streamed instead of capturing silence forever.
      live.recorderAlive().then((alive) {
        if (!alive && mounted && _live == live && live.isLive) _stopLive();
      });
    }
  }

  /// The OS can kill the capture session while backgrounded (iOS without a
  /// background-audio entitlement). A dead session leaves a header-only file;
  /// submitting runs it into the minValidBytes guard, which surfaces the
  /// honest "captured almost no audio" message instead of a server 400.
  Future<void> _checkCaptureSurvived() async {
    bool alive = false;
    try {
      alive = await _recorder.isRecording();
    } catch (_) {}
    if (!alive && mounted && _isRecording) _stopAndSubmit();
  }

  void _toggle() {
    if (_mode == 'conversation') {
      final live = _live;
      if (live == null) {
        _startLive();
      } else if (live.phase == LivePhase.live) {
        _stopLive();
      }
      // connecting/finishing: dead zone — ignore taps.
      return;
    }
    if (_phase == _RecPhase.idle) {
      _startRecording();
    } else if (_phase == _RecPhase.recording) {
      _stopAndSubmit();
    }
    // starting/stopping: dead zone — ignore taps.
  }

  // ---- LIVE session lifecycle ----

  void _onLive() {
    final live = _live;
    if (live == null || !mounted) return;
    // Mid-session death (server error / socket drop): end + salvage once.
    if (live.sessionError != null && !_liveAutoStopping) {
      _liveAutoStopping = true;
      _stopLive();
    }
    var sig = live.transcript.lines.length * 100000 +
        live.transcript.events.length * 1000 +
        live.transcript.partial.length +
        live.googleLines.length * 31;
    for (final l in live.transcript.lines) {
      sig += l.text.length;
    }
    for (final g in live.googleLines) {
      sig += g.text.length;
    }
    if (sig != _liveSig) {
      _liveSig = sig;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final c in [_liveScroll, _transScroll]) {
          if (c.hasClients) {
            c.animateTo(c.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut);
          }
        }
      });
    }
    setState(() {});
  }

  Future<void> _startLive() async {
    if (_live != null || !_looksIdle) return;
    final live = LiveController(
      mode: LiveMode.standard,
      settings: context.read<SettingsStore>(),
      apiKeys: ApiKeys(),
      history: context.read<HistoryStore>(),
    );
    _liveAutoStopping = false;
    _liveSig = -1;
    _liveView = 'split'; // sessions open in split when translation is on
    setState(() => _live = live);
    live.addListener(_onLive);
    final error = await live.start();
    if (error != null) {
      live.removeListener(_onLive);
      live.dispose();
      if (mounted) {
        setState(() => _live = null);
        _snack(error);
      }
    }
  }

  Future<void> _stopLive() async {
    final live = _live;
    if (live == null || live.phase == LivePhase.connecting) return;
    if (live.phase == LivePhase.finishing) return; // dead zone
    final res = await live.stop();
    live.removeListener(_onLive);
    live.dispose();
    if (!mounted) {
      _live = null;
      return;
    }
    setState(() => _live = null);
    switch (res.outcome) {
      case LiveStopOutcome.saved:
        _snack(res.error == null
            ? 'Live session saved to History.'
            : '${res.error} — partial transcript saved to History.');
      case LiveStopOutcome.empty:
        _snack(res.error == null
            ? 'No speech captured — nothing was saved.'
            : '${res.error} — no speech captured.');
      case LiveStopOutcome.cancelled:
        break;
    }
  }

  Future<void> _cancelLive() async {
    final live = _live;
    if (live == null) return;
    await live.cancel();
    live.removeListener(_onLive);
    live.dispose();
    if (!mounted) {
      _live = null;
      return;
    }
    setState(() => _live = null);
    _snack('Live session discarded.');
  }

  Future<void> _startRecording() async {
    if (_phase != _RecPhase.idle) return;
    // Reachable: synthesizing → CANCEL → back here → immediate mic tap while
    // the previous pipeline is still winding down.
    if (context.read<JobController>().busy) {
      _snack('The previous transcription is still finishing — try again in a moment.');
      return;
    }
    setState(() => _phase = _RecPhase.starting);
    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        if (mounted) {
          _snack('Microphone permission is required — enable it in system Settings.');
          setState(() => _phase = _RecPhase.idle);
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/sm_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
      // Screen-timeout locks suspend our capture the same way they suspend
      // synthesizing's polling — hold the screen awake for the take.
      unawaited(WakelockPlus.enable());
      _path = path;
      _seconds = 0;
      _viz = Timer.periodic(const Duration(milliseconds: 120), (_) {
        if (!mounted || !_isRecording) return;
        setState(() {
          _levels = List.generate(
              _barCount, (_) => 0.15 + _rand.nextDouble() * 0.85);
        });
      });
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
      if (mounted) setState(() => _phase = _RecPhase.recording);
    } catch (e) {
      if (mounted) {
        _snack('Could not start recording: $e');
        setState(() => _phase = _RecPhase.idle);
      }
    }
  }

  Future<void> _stopAndSubmit() async {
    if (_phase != _RecPhase.recording) return;
    setState(() {
      _phase = _RecPhase.stopping;
      _levels = List.filled(_barCount, 0.08);
    });
    _clock?.cancel();
    _viz?.cancel();
    unawaited(WakelockPlus.disable());

    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    path ??= _path;
    _path = null;
    if (path == null) {
      if (mounted) {
        _snack('Recording failed.');
        setState(() => _phase = _RecPhase.idle);
      }
      return;
    }

    List<int> bytes;
    try {
      bytes = await readAudioBytes(path);
    } catch (e) {
      if (mounted) {
        _snack('Could not read recording: $e');
        setState(() => _phase = _RecPhase.idle);
      }
      return;
    }
    // JobController persists the durable copy before submitting; the temp file is done.
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
        setState(() => _phase = _RecPhase.idle);
      }
      return;
    }
    if (!mounted) return;

    final job = context.read<JobController>();
    if (job.busy) {
      // Don't show a synthesizing screen bound to someone else's job.
      _snack('The previous transcription is still finishing — try again in a moment.');
      setState(() => _phase = _RecPhase.idle);
      return;
    }
    final settings = context.read<SettingsStore>();
    final stamp = TimeOfDay.fromDateTime(DateTime.now()).format(context);
    unawaited(job.startJob(
      audioBytes: bytes,
      filename: 'recording.m4a',
      config: settings.snapshot(speakers: context.read<SpeakerStore>().profiles),
      title: 'Recording $stamp',
      conversation: _mode == 'conversation',
    ));
    // Reset BEFORE navigating so any pop-back reveals a clean idle home.
    setState(() {
      _phase = _RecPhase.idle;
      _seconds = 0;
    });
    Navigator.pushNamed(context, Routes.synthesizing);
  }

  /// CANCEL bar + back gesture: discard the take entirely.
  Future<void> _cancelRecording() async {
    if (_phase != _RecPhase.recording) return;
    setState(() {
      _phase = _RecPhase.stopping;
      _levels = List.filled(_barCount, 0.08);
    });
    _clock?.cancel();
    _viz?.cancel();
    unawaited(WakelockPlus.disable());
    final path = _path;
    _path = null;
    try {
      await _recorder.cancel(); // stops AND deletes the output file
    } catch (_) {
      if (path != null) unawaited(deleteAudioFile(path));
    }
    if (mounted) {
      setState(() {
        _phase = _RecPhase.idle;
        _seconds = 0;
      });
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

  String get _time {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _statusText {
    if (_liveActive) {
      return switch (_live!.phase) {
        LivePhase.connecting => 'CONNECTING…',
        LivePhase.finishing => 'SAVING…',
        _ => 'LIVE · RT STREAMING',
      };
    }
    if (!_looksIdle) return 'RECORDING';
    return _mode == 'conversation' ? 'READY FOR LIVE SESSION' : 'READY TO CAPTURE';
  }

  @override
  Widget build(BuildContext context) {
    final calm = _looksIdle && !_liveActive; // no session of either kind
    return PopScope(
      // Back while a session runs cancels it (mirrors the CANCEL bar);
      // back while idle keeps today's behavior (leaves the app).
      canPop: _phase == _RecPhase.idle && !_liveActive,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_liveActive) {
          _cancelLive();
        } else {
          _cancelRecording();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: const BrandTopBar(),
        bottomNavigationBar: _liveActive
            ? SessionCancelBar(
                label: 'CANCEL LIVE SESSION', onCancel: _cancelLive)
            : _looksIdle
                ? const SpeechBottomNav(current: SpeechTab.home)
                : SessionCancelBar(
                    label: 'CANCEL RECORDING', onCancel: _cancelRecording),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // The headline yields its space to the caption stream while
                // live (the design hides it entirely).
                if (!_liveActive) ...[
                  const SizedBox(height: 20),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: AppType.display(size: 32),
                      children: const [
                        TextSpan(text: 'Understand every '),
                        TextSpan(
                            text: 'voice.',
                            style: TextStyle(color: AppColors.primary)),
                      ],
                    ),
                  ),
                ] else
                  const SizedBox(height: 12),
                const SizedBox(height: 8),
                Text(
                  _statusText,
                  style: AppType.mono(
                      size: 12,
                      weight: calm ? FontWeight.w500 : FontWeight.w700,
                      color: calm
                          ? AppColors.onSurfaceVariant
                          : AppColors.recordActive,
                      spacing: 1.5),
                ),
                if (!_liveActive) ...[
                  const SizedBox(height: 10),
                  // Hidden (not removed) while recording so the layout doesn't jump.
                  Visibility(
                    visible: calm,
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true,
                    child: _modeSwitcher(),
                  ),
                ],
                // Live owns all the slack (the caption card matches the
                // Agent screen's full-height card, mic pinned below);
                // idle/recording keep the twin-spacer mic centring.
                if (_liveActive)
                  Expanded(child: _liveZone())
                else ...[
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _looksIdle
                        ? KeyedSubtree(
                            key: const ValueKey('idle'), child: _idleZone())
                        : KeyedSubtree(
                            key: const ValueKey('recording'),
                            child: _recordingZone()),
                  ),
                  const Spacer(),
                ],
                _captureCluster(),
                if (!_liveActive) const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- idle zone: recent transcriptions ----

  Widget _idleZone() {
    final recent = context.watch<HistoryStore>().recent.take(3).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text('RECENT TRANSCRIPTIONS',
                  style: AppType.headline(
                          size: 12, color: AppColors.onSurfaceVariant)
                      .copyWith(letterSpacing: 2)),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, Routes.history),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text('VIEW ALL',
                  style: AppType.body(
                          size: 11,
                          weight: FontWeight.w700,
                          color: AppColors.primary)
                      .copyWith(letterSpacing: 1.5)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          _emptyRecents()
        else
          for (var i = 0; i < recent.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _recentCard(recent[i]),
          ],
      ],
    );
  }

  Widget _emptyRecents() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Text('No transcriptions yet. Tap the mic below to record your first.',
          style: AppType.body(size: 14, color: AppColors.onSurfaceVariant)),
    );
  }

  Widget _recentCard(HistoryItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // Failed items have no transcript — History carries the Retry action.
        onTap: () => item.failed
            ? Navigator.pushReplacementNamed(context, Routes.history)
            : Navigator.pushNamed(context, Routes.transcription,
                arguments: TranscriptionArgs(item.id)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _datePill(item),
                        const SizedBox(width: 6),
                        // Expanded (not Flexible+Spacer): the pill ellipsizes
                        // inside its slot instead of painting over the chips.
                        Expanded(
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: _jobPill(item.jobId))),
                        const SizedBox(width: 6),
                        if (item.failed) _failedChip() else _langPair(item),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Flexible(
                          child: Text(item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.body(
                                  size: 16, weight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Rename',
                          child: InkWell(
                            onTap: () => _renameDialog(item),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(Symbols.edit,
                                  size: 15, color: AppColors.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(_snippet(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body(
                            size: 12, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Symbols.arrow_forward,
                  size: 20, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datePill(HistoryItem item) {
    final label = item.createdAt != null
        ? DateFormat('MMM d • HH:mm').format(item.createdAt!).toUpperCase()
        : item.displayLabel.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: AppType.mono(
              size: 9,
              weight: FontWeight.w500,
              color: AppColors.onSurfaceVariant)),
    );
  }

  /// Compact `JOB <id>` pill (the full JobIdPill is too wide for this row —
  /// on narrow phones it overflowed into the language/FAILED chips).
  Widget _jobPill(String jobId) {
    if (jobId.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: jobId));
        _snack('Job ID copied: $jobId');
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text('JOB $jobId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.mono(
                      size: 9,
                      weight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant)),
            ),
            const SizedBox(width: 4),
            Icon(Symbols.content_copy,
                size: 11, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _failedChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        color: AppColors.error.withValues(alpha: 0.08),
      ),
      child: Text('FAILED',
          style: AppType.body(
                  size: 9, weight: FontWeight.w700, color: AppColors.error)
              .copyWith(letterSpacing: 0.8)),
    );
  }

  Widget _langPair(HistoryItem item) {
    if (item.languages.isEmpty) return const SizedBox.shrink();
    if (item.languages.length == 1) return LangCodeChip(item.languages.first);
    final icon = item.arrow == '↔' ? Symbols.sync_alt : Symbols.arrow_forward;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      LangCodeChip(item.languages.first),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Icon(icon, size: 12, color: AppColors.onSurfaceVariant),
      ),
      LangCodeChip(item.languages.last),
    ]);
  }

  String _snippet(HistoryItem item) {
    if (item.failed) return 'Transcription failed — open History to retry.';
    String text = '';
    final segs = item.segments;
    final conv = item.conversation;
    if (segs != null && segs.isNotEmpty) {
      text = segs.expand((s) => s.parts).map((p) => p.text).join(' ');
    } else if (conv != null && conv.isNotEmpty) {
      text = conv.map((t) => t.text).join(' ');
    } else if (item.translationText != null) {
      text = item.translationText!;
    }
    text = text.trim();
    if (text.isEmpty) return '—';
    if (text.length > 90) text = '${text.substring(0, 90)}…';
    return '"$text"';
  }

  Future<void> _renameDialog(HistoryItem item) async {
    final controller = TextEditingController(text: item.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename transcript'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      if (!mounted) return;
      context.read<HistoryStore>().rename(item.id, result);
      _snack('Title updated');
    }
  }

  // ---- live zone: in-place RT captions (precision.html live state) ----

  static const _navy = Color(0xFF0D3C48);
  static const _speakerPalette = [
    AppColors.primary, // S1 — jade
    _navy, // S2
    Color(0xFF0891B2), // S3 — cyan
    Color(0xFF7C3AED), // S4 — violet
  ];

  Color _speakerColor(String id) {
    final m = RegExp(r'^S(\d+)$').firstMatch(id);
    if (m == null) return AppColors.primary;
    return _speakerPalette[(int.parse(m.group(1)!) - 1) % _speakerPalette.length];
  }

  String _liveStamp(double? t) {
    if (t == null) return '';
    final secs = t.round();
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _liveZone() {
    final live = _live!;
    final s = context.watch<SettingsStore>();
    final target = s.rtTranslation ? s.rtTargetLanguageCode : null;
    final secs = live.elapsedSeconds;
    final timer =
        '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Row(children: [
            _liveIndicator(),
            const SizedBox(width: 8),
            Expanded(
              child: Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('RT · ${s.rtOperatingPoint.toUpperCase()}',
                      style: AppType.mono(
                          size: 9,
                          weight: FontWeight.w500,
                          color: AppColors.onSurfaceVariant)),
                ),
                const SizedBox(width: 5),
                LangCodeChip(s.rtLanguage.toUpperCase()),
                if (target != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Icon(Symbols.sync_alt,
                        size: 11, color: AppColors.onSurfaceVariant),
                  ),
                  LangCodeChip(target.toUpperCase()),
                ],
              ]),
            ),
            Text(timer,
                style: AppType.mono(size: 16, weight: FontWeight.w700)
                    .copyWith(letterSpacing: -0.4)),
          ]),
          if (target != null) ...[
            const SizedBox(height: 12),
            _viewSeg(),
          ],
          const SizedBox(height: 12),
          // Panes fill everything between the header and the mic. SPLIT =
          // two equal boxes (original top, translation below), both
          // auto-scrolling independently (design: precision.html live state).
          Expanded(
            child: Column(
              children: [
                if (target == null || _liveView != 'translation')
                  Expanded(child: _paneCard(child: _capStream(live))),
                if (target != null && _liveView == 'split')
                  const SizedBox(height: 10),
                if (target != null && _liveView != 'original')
                  Expanded(
                    child: _paneCard(
                      label:
                          'LIVE TRANSLATION · GOOGLE · ${target.toUpperCase()}',
                      child: _transStream(live),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ORIGINAL | TRANSLATION | SPLIT — same segmented family as the
  /// transcription result card.
  Widget _viewSeg() {
    return SegmentedToggle<String>(
      value: _liveView,
      onChanged: (v) => setState(() => _liveView = v),
      expand: true,
      radius: 999,
      segVPad: 6,
      fontSize: 10,
      items: const [
        SegItem('original', 'ORIGINAL'),
        SegItem('translation', 'TRANSLATION'),
        SegItem('split', 'SPLIT'),
      ],
    );
  }

  /// Shared pane chrome; [label] adds the jade in-card header row.
  Widget _paneCard({String? label, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: label == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 9, 14, 0),
                  child: Row(children: [
                    const Icon(Symbols.translate,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.labelCaps(
                              size: 9, color: AppColors.primary)),
                    ),
                  ]),
                ),
                Expanded(child: child),
              ],
            ),
    );
  }

  /// Google-translated captions — one line per finalized caption; pending
  /// entries render as TRANSLATING… with the jade accent.
  Widget _transStream(LiveController live) {
    final lines = live.googleLines;
    if (lines.isEmpty) {
      return Center(
        child: Text('WAITING FOR AUDIO…',
            style: AppType.labelCaps(size: 9.5, color: AppColors.tertiary)),
      );
    }
    return ListView.separated(
      controller: _transScroll,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      itemCount: lines.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _transLine(lines[i]),
    );
  }

  Widget _transLine(LiveGoogleLine g) {
    final target = context.read<SettingsStore>().rtTargetLanguageCode;
    final stampTxt =
        '${_liveStamp(g.atSeconds.toDouble())} · ${target.toUpperCase()}';
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (g.speaker != null) ...[
            _speakerTag(g.speaker!),
            const SizedBox(width: 5),
          ],
          Text(g.done ? '$stampTxt · FINAL' : '$stampTxt · TRANSLATING…',
              style: AppType.mono(size: 9, color: AppColors.tertiary)),
        ]),
        const SizedBox(height: 3),
        g.done
            ? Text(g.text, style: AppType.body(size: 14, height: 1.5))
            : Text('···',
                style: AppType.body(
                        size: 14,
                        color: AppColors.onSurfaceVariant,
                        height: 1.5)
                    .copyWith(fontStyle: FontStyle.italic)),
      ],
    );
    if (g.done) return body;
    return Container(
      padding: const EdgeInsets.only(left: 9),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.5), width: 2),
        ),
      ),
      child: body,
    );
  }

  Widget _liveIndicator() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.recordActive.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: AppColors.recordActive.withValues(alpha: 0.28)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Transform.scale(
              scale: 1 - 0.28 * t,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.recordActive.withValues(alpha: 1 - 0.65 * t),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text('LIVE',
                style: AppType.labelCaps(
                    size: 9, color: AppColors.recordActive)),
          ]),
        );
      },
    );
  }

  Widget _capStream(LiveController live) {
    final b = live.transcript;
    // Caption lines and audio-event chips merge chronologically (both carry
    // audio-time stamps); ties keep insertion order.
    final entries = <(double, int, Widget)>[];
    var seq = 0;
    for (final l in b.lines) {
      if (l.text.trim().isEmpty) continue;
      entries.add((l.start ?? double.maxFinite, seq++, _capLine(l)));
    }
    for (final e in b.events) {
      entries.add((e.time ?? double.maxFinite, seq++, _eventChip(e.type)));
    }
    entries.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    final children = entries.map((e) => e.$3).toList();
    if (b.partial.trim().isNotEmpty) children.add(_partialLine(b.partial));

    if (children.isEmpty) {
      return Center(
        child: Text(
            live.phase == LivePhase.connecting
                ? 'Connecting…'
                : 'Listening — captions appear as you speak…',
            style: AppType.body(size: 13, color: AppColors.tertiary)),
      );
    }
    return ListView.separated(
      controller: _liveScroll,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      itemCount: children.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => children[i],
    );
  }

  Widget _speakerTag(String speaker) {
    final c = _speakerColor(speaker);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(speaker.toUpperCase(),
          style: AppType.mono(size: 9, weight: FontWeight.w700, color: c)),
    );
  }

  Widget _capLine(LiveLine l) {
    final stamp = _liveStamp(l.start);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (l.speaker != null) ...[
            _speakerTag(l.speaker!),
            const SizedBox(width: 5),
          ],
          Text(stamp.isEmpty ? 'FINAL' : '$stamp · FINAL',
              style: AppType.mono(size: 9, color: AppColors.tertiary)),
        ]),
        const SizedBox(height: 3),
        Text(l.text.trim(), style: AppType.body(size: 14, height: 1.5)),
      ],
    );
  }

  Widget _partialLine(String text) {
    return Container(
      padding: const EdgeInsets.only(left: 9),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
              color: AppColors.recordActive.withValues(alpha: 0.5), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INTERIM',
              style: AppType.mono(size: 9, color: AppColors.tertiary)),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(text.trim(),
                    style: AppType.body(
                            size: 14,
                            color: AppColors.onSurfaceVariant,
                            height: 1.5)
                        .copyWith(fontStyle: FontStyle.italic)),
              ),
              const SizedBox(width: 3),
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Opacity(
                  opacity: _pulse.value < 0.5 ? 1 : 0,
                  child: Container(
                    width: 7,
                    height: 14,
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: AppColors.recordActive,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eventChip(String type) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Symbols.graphic_eq, size: 13, color: AppColors.amber),
          const SizedBox(width: 6),
          Text(type.toUpperCase(),
              style: AppType.labelCaps(size: 9, color: AppColors.amber)),
        ]),
      ),
    );
  }

  // ---- recording zone: waveform + tip + timer ----

  Widget _recordingZone() {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 140,
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
                      height: 16 + lvl * 118,
                      decoration: BoxDecoration(
                        color: AppColors.recordActive,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Short clips give the omnilingual model too little signal
          // for reliable language detection — nudge toward 14s+.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Symbols.tips_and_updates,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Tip: record at least 14 seconds for best results',
                  style: AppType.body(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.primary)),
            ]),
          ),
          const SizedBox(height: 8),
          Text(_time,
              style: AppType.mono(
                      size: 60,
                      weight: FontWeight.w700,
                      color: AppColors.onSurface)
                  .copyWith(letterSpacing: -2)),
        ],
      ),
    );
  }

  // ---- mode toggle (RECORD | LIVE) ----

  Widget _modeSwitcher() {
    Widget btn(String value, String label) {
      final active = _mode == value;
      // LIVE wears the session accent (the stop button's orange) instead of
      // jade — the word itself turns record-orange when selected.
      final live = value == 'conversation';
      final seg = AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: !active
              ? Colors.transparent
              : live
                  ? AppColors.recordActive.withValues(alpha: 0.12)
                  : AppColors.primary,
          borderRadius: BorderRadius.circular(12),
          border: active && live
              ? Border.all(
                  color: AppColors.recordActive.withValues(alpha: 0.4))
              : null,
        ),
        child: Text(label,
            style: AppType.labelCaps(
                size: 10,
                color: !active
                    ? AppColors.onSurfaceVariant
                    : live
                        ? AppColors.recordActive
                        : Colors.white)),
      );
      return GestureDetector(
        onTap: _isRecording || _liveActive
            ? null
            : () => setState(() => _mode = value),
        child: seg,
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn('single', 'RECORD'),
        btn('conversation', 'LIVE'),
      ]),
    );
  }

  // ---- capture cluster: ripple rings + glow pulse mic + status chip ----

  static const _micSize = 82.0;

  Widget _captureCluster() {
    return Padding(
      // Minimum clearance so the glow never kisses the neighbours even when
      // the spacers collapse on very short screens.
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        width: _micSize,
        height: _micSize,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // The START button's ripple rings — idle only, hidden while
            // recording or live (matches the classic record screen's plain
            // button).
            if (_looksIdle && !_liveActive)
              AnimatedBuilder(
                animation: _ripple,
                builder: (_, __) => Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    _ring(162, 0.0),
                    _ring(123, 0.33),
                    _ring(85, 0.66),
                  ],
                ),
              ),
            _micButton(),
          ],
        ),
      ),
    );
  }

  Widget _ring(double size, double phase) {
    final p = (_ripple.value + phase) % 1.0;
    final scale = 0.8 + p * 0.8; // 0.8 -> 1.6
    final opacity = (p < 0.5 ? p * 0.3 : (1 - p) * 0.3).clamp(0.0, 1.0);
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _micButton() {
    final inSession = !_looksIdle || _liveActive;
    final accent = inSession ? AppColors.recordActive : AppColors.primary;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        // Green glow pulse only while idle — sessions get a steady red halo.
        final t = inSession ? 0.0 : Curves.easeInOut.transform(_pulse.value);
        return GestureDetector(
          onTap: _toggle,
          child: Transform.scale(
            scale: 1 + 0.09 * t,
            child: Container(
              width: _micSize,
              height: _micSize,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22 + 0.3 * t),
                    blurRadius: 16 + 26 * t,
                    spreadRadius: 1 + 6 * t,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: !inSession
                    ? const Icon(Symbols.mic,
                        color: Colors.white, size: 36, fill: 1)
                    : Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

}
