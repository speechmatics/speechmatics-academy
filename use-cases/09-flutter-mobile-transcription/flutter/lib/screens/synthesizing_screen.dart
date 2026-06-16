import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../routes.dart';
import '../state/job_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_top_bar.dart';
import 'transcription_screen.dart';

enum _StepState { pending, active, complete }

class SynthesizingScreen extends StatefulWidget {
  const SynthesizingScreen({super.key});

  @override
  State<SynthesizingScreen> createState() => _SynthesizingScreenState();
}

class _SynthesizingScreenState extends State<SynthesizingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  late final AnimationController _breath = AnimationController(
      vsync: this, duration: const Duration(seconds: 3))
    ..repeat(reverse: true);

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Keep the screen awake while the job runs: a screen-timeout lock lets
    // Android suspend our network mid-poll, which can fail long jobs.
    // Released in dispose when we leave for the result.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _spin.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = context.watch<JobController>();

    if (job.phase == JobPhase.done && !_navigated && job.resultId != null) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            Routes.transcription,
            arguments: TranscriptionArgs(job.resultId!),
          );
        }
      });
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: BrandTopBar(
        trailing: [
          IconButton(
            onPressed: () => _cancel(context, job),
            icon: Icon(Symbols.close, size: 22, color: AppColors.onSurface),
            style: IconButton.styleFrom(shape: const CircleBorder()),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ring(),
              const SizedBox(height: 40),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(style: AppType.display(size: 30), children: const [
                  TextSpan(text: 'Synthesizing '),
                  TextSpan(text: 'every voice...', style: TextStyle(color: AppColors.primary)),
                ]),
              ),
              const SizedBox(height: 40),
              if (job.phase == JobPhase.error)
                _errorCard(context, job)
              else
                _statusCard(job),
              const SizedBox(height: 24),
              if (job.phase != JobPhase.error)
                TextButton(
                  onPressed: () => _cancel(context, job),
                  child: Text('CANCEL',
                      style: AppType.labelCaps(size: 11, color: AppColors.onSurfaceVariant)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _cancel(BuildContext context, JobController job) {
    job.cancel();
    Navigator.maybePop(context);
  }

  // ---- status pipeline ----
  Widget _statusCard(JobController job) {
    final phase = job.phase;
    final detecting = switch (phase) {
      JobPhase.submitting || JobPhase.polling => _StepState.active,
      _ => _StepState.complete,
    };
    final building = switch (phase) {
      JobPhase.submitting || JobPhase.polling => _StepState.pending,
      JobPhase.parsing => _StepState.active,
      _ => _StepState.complete,
    };
    final translating = switch (phase) {
      JobPhase.translating => _StepState.active,
      JobPhase.done => _StepState.complete,
      _ => _StepState.pending,
    };

    final detectedLabel = job.detectedLanguages.isNotEmpty
        ? '${job.detectedLanguages.join(', ')} DETECTED'
        : 'ANALYZING AUDIO';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Column(
        children: [
          _step(
            state: detecting,
            title: 'Detecting languages...',
            subtitle: detecting == _StepState.complete
                ? Text(detectedLabel,
                    style: AppType.mono(size: 10, color: AppColors.primary.withValues(alpha: 0.7)))
                : null,
            icon: Symbols.check,
          ),
          const SizedBox(height: 24),
          _step(
            state: building,
            title: 'Building transcript...',
            subtitle: building == _StepState.active
                ? const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                  )
                : null,
            icon: Symbols.check,
          ),
          const SizedBox(height: 24),
          _step(
            state: job.translationSkipped && translating != _StepState.active
                ? _StepState.complete
                : translating,
            title: job.translationSkipped ? 'Translation skipped' : 'Polishing translation...',
            icon: Symbols.check,
          ),
        ],
      ),
    );
  }

  Widget _step({
    required _StepState state,
    required String title,
    required IconData icon,
    Widget? subtitle,
  }) {
    Widget leading;
    switch (state) {
      case _StepState.complete:
        leading = Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary, weight: 700),
        );
      case _StepState.active:
        leading = Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
          ),
          child: Center(
            child: AnimatedBuilder(
              animation: _breath,
              builder: (_, __) => Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.primary
                      .withValues(alpha: 0.4 + 0.6 * Curves.easeInOut.transform(_breath.value)),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      case _StepState.pending:
        leading = Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Icon(Symbols.more_horiz, size: 18, color: AppColors.outline),
        );
    }

    return Opacity(
      opacity: state == _StepState.pending ? 0.4 : 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(title,
                      style: AppType.body(
                          size: 16,
                          weight: state == _StepState.active ? FontWeight.w700 : FontWeight.w500)),
                ),
                if (subtitle != null) subtitle,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(BuildContext context, JobController job) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Symbols.error, color: AppColors.error, size: 26),
          ),
          const SizedBox(height: 16),
          Text('Transcription failed',
              style: AppType.headline(size: 18), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(job.error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: AppType.body(size: 14, color: AppColors.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.maybePop(context),
              child: Text('Back',
                  style: AppType.body(size: 14, weight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, Routes.settings),
            child: Text('Open Settings',
                style: AppType.body(size: 13, weight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _ring() {
    return SizedBox(
      width: 192,
      height: 192,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _spin,
            child: CustomPaint(size: const Size(192, 192), painter: _RingPainter()),
          ),
          AnimatedBuilder(
            animation: _breath,
            builder: (_, child) {
              final t = Curves.easeInOut.transform(_breath.value);
              return Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1 + 0.2 * t),
                      blurRadius: 10 + 15 * t,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  'assets/images/speechmatics_loader.gif',
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.outlineVariant;
    canvas.drawCircle(center, r, track);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primary;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, math.pi * 0.6, false, arc);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
