import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../data/api_keys.dart';
import '../data/audio_file.dart';
import '../data/config_mapper.dart';
import '../data/dto/job_status.dart';
import '../data/speechmatics_client.dart';
import '../data/transcript_parser.dart';
import '../models/speaker_profile.dart';
import '../state/settings_store.dart';
import '../state/speaker_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_top_bar.dart';

/// ~55-word passage (≈20 s read) introducing Speechmatics — doubles as the
/// phonetically varied enrollment text.
const _passage =
    'Speechmatics is a speech technology company based in Cambridge, England. '
    'Its mission is to understand every voice, whatever the language, accent, '
    'or dialect. The company builds some of the most accurate speech '
    'recognition in the world, turning conversations, meetings, and broadcasts '
    'into text that people and products can search, analyse, and act on.';

/// Speaker enrollment panel (Settings → SPEAKERS → Enrol speaker): records a
/// 20-second reading, runs a `get_speakers` enrollment job, and saves the
/// returned voice identifiers as a [SpeakerProfile].
class SpeakerEnrollmentScreen extends StatefulWidget {
  const SpeakerEnrollmentScreen({super.key});

  @override
  State<SpeakerEnrollmentScreen> createState() => _SpeakerEnrollmentScreenState();
}

class _SpeakerEnrollmentScreenState extends State<SpeakerEnrollmentScreen>
    with SingleTickerProviderStateMixin {
  static const _maxSeconds = 20;
  static const _minSeconds = 5;
  static const _barCount = 15;

  final _rand = Random();
  final _recorder = AudioRecorder();
  late final TextEditingController _name;

  String _stage = 'idle'; // idle | recording | processing | error
  String? _error;
  List<double> _levels = List.filled(_barCount, 0.08);
  int _elapsed = 0;
  String? _path;
  bool _starting = false;

  Timer? _viz;
  Timer? _clock;
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    final n = context.read<SpeakerStore>().profiles.length + 1;
    _name = TextEditingController(text: 'Speaker $n');
    _viz = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      setState(() {
        _levels = List.generate(
          _barCount,
          (_) => _stage == 'recording' ? 0.15 + _rand.nextDouble() * 0.85 : 0.08,
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
    _name.dispose();
    super.dispose();
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

  Future<void> _start() async {
    if (_starting) return;
    if (_name.text.trim().isEmpty) {
      _snack('Give this speaker a name first.');
      return;
    }
    setState(() => _starting = true);
    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        if (mounted) _snack('Microphone permission is required to enrol.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/sm_enroll_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1),
        path: path,
      );
      _path = path;
      _elapsed = 0;
      setState(() {
        _stage = 'recording';
        _error = null;
      });
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed++);
        if (_elapsed >= _maxSeconds) _finish(); // auto-stop at 0:20
      });
    } catch (e) {
      if (mounted) _snack('Could not start recording: $e');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Stop the recorder and run the enrollment job.
  Future<void> _finish() async {
    if (_stage != 'recording') return;
    _clock?.cancel();
    setState(() => _stage = 'processing');
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    path ??= _path;

    SpeechmaticsClient? sm;
    try {
      if (path == null) throw 'Recording failed.';
      final bytes = await readAudioBytes(path);
      unawaited(deleteAudioFile(path));
      if (bytes.isEmpty) throw 'The recording was empty.';

      final key = await ApiKeys().speechmatics();
      if (key == null) throw 'Add your Speechmatics API key in Settings first.';
      if (!mounted) return;
      sm = SpeechmaticsClient(apiKey: key, region: context.read<SettingsStore>().region);

      final jobId = await sm.submitJob(
        audioBytes: bytes,
        filename: 'enrollment.m4a',
        config: ConfigMapper.buildEnrollment(),
      );
      await for (final st in sm.pollUntilDone(jobId)) {
        if (!mounted) return;
        if (st.state == JobState.rejected) {
          throw st.error ?? 'The enrollment job was rejected.';
        }
        if (st.isDone) break;
      }
      final tjson = await sm.getTranscript(jobId);
      final found = parseEnrolledSpeakers(tjson);
      if (found.isEmpty) {
        throw 'No clear voice was detected — try again in a quieter spot.';
      }
      if (!mounted) return;

      final name = _name.text.trim();
      context.read<SpeakerStore>().add(SpeakerProfile(
            id: 'spk_${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            // Dominant voice (most words) when noise produced extra labels.
            identifiers: found.first.identifiers,
            enrolledAt: DateTime.now(),
          ));
      _snack('$name enrolled');
      Navigator.maybePop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = 'error';
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      sm?.dispose();
    }
  }

  String get _countdown {
    final r = (_maxSeconds - _elapsed).clamp(0, _maxSeconds);
    return '0:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final recording = _stage == 'recording';
    final accent = recording ? AppColors.recordActive : AppColors.primary;
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      extendBodyBehindAppBar: true,
      appBar: BrandTopBar(
        leading: TopBarLeading.back,
        onLeading: () => Navigator.maybePop(context),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text('Enrol a speaker',
                style: AppType.display(size: 24, weight: FontWeight.w600, color: const Color(0xFF0D3C48))),
            const SizedBox(height: 4),
            Text('Their voice will be recognized and labelled by name in future transcriptions.',
                style: AppType.body(size: 14, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 20),
            _label('SPEAKER NAME'),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              enabled: _stage == 'idle' || _stage == 'error',
              style: AppType.body(size: 15),
              decoration: InputDecoration(
                hintText: 'e.g. Edgars',
                hintStyle: AppType.body(size: 14, color: AppColors.tertiary),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(12),
                isDense: true,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _label('READ THIS ALOUD'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Text(_passage, style: AppType.body(size: 15, height: 1.6)),
            ),
            const SizedBox(height: 8),
            Text('Recording stops automatically after 20 seconds.',
                style: AppType.body(size: 12, color: AppColors.tertiary)),
            const SizedBox(height: 24),
            // Waveform + countdown
            SizedBox(
              height: 72,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (final lvl in _levels)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 7,
                        height: 10 + lvl * 56,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(_countdown,
                  style: AppType.mono(size: 40, weight: FontWeight.w700, color: AppColors.onSurface)
                      .copyWith(letterSpacing: -1)),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                switch (_stage) {
                  'recording' =>
                    _elapsed < _minSeconds ? 'KEEP READING…' : 'RECORDING — TAP TO FINISH',
                  'processing' => 'PROCESSING YOUR VOICE…',
                  'error' => 'ENROLLMENT FAILED',
                  _ => 'TAP TO START RECORDING',
                },
                style: AppType.labelCaps(size: 10, color: AppColors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 24),
            if (_stage == 'processing')
              const Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
                ),
              )
            else
              Center(child: _recordButton(recording, accent)),
            if (_stage == 'error' && _error != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Text(_error!,
                    style: AppType.body(size: 13, color: AppColors.error, height: 1.4)),
              ),
              const SizedBox(height: 12),
              Center(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () => setState(() {
                    _stage = 'idle';
                    _error = null;
                    _elapsed = 0;
                  }),
                  icon: const Icon(Symbols.refresh, size: 18, color: Colors.white),
                  label: Text('Try again',
                      style: AppType.body(size: 13, weight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recordButton(bool recording, Color accent) {
    // Manual stop unlocks after _minSeconds (more audio = better matching).
    final canStop = recording && _elapsed >= _minSeconds;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final t = recording ? 0.0 : Curves.easeInOut.transform(_pulse.value);
        return GestureDetector(
          onTap: _stage == 'idle' || _stage == 'error'
              ? _start
              : (canStop ? _finish : null),
          child: Transform.scale(
            scale: 1 + 0.08 * t,
            child: Opacity(
              opacity: recording && !canStop ? 0.6 : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.4 + 0.3 * t),
                      blurRadius: 20 + 22 * t,
                      spreadRadius: -2 + 7 * t,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: recording
                      ? Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        )
                      : const Icon(Symbols.mic, color: Colors.white, size: 36, fill: 1),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(t,
            style: AppType.headline(size: 14, weight: FontWeight.w500, color: AppColors.outline)
                .copyWith(letterSpacing: 1.0)),
      );
}
