import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../data/config_mapper.dart';
import '../models/classic_lang_catalog.dart';
import '../models/job_config.dart';
import '../models/lang_catalog.dart';
import '../routes.dart';
import '../state/job_controller.dart';
import '../state/settings_store.dart';
import '../state/speaker_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_top_bar.dart';
import '../widgets/speech_bottom_nav.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  XFile? _file;
  Uint8List? _bytes;
  int _size = 0;

  Future<void> _pick() async {
    const group = XTypeGroup(
      label: 'Audio',
      extensions: ['wav', 'mp3', 'm4a', 'mp4', 'flac', 'ogg', 'oga', 'aac', 'opus'],
      mimeTypes: ['audio/*'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _file = file;
      _bytes = bytes;
      _size = bytes.length;
    });
  }

  void _submit() {
    final file = _file;
    final bytes = _bytes;
    if (file == null || bytes == null) return;
    final settings = context.read<SettingsStore>();
    context.read<JobController>().startJob(
          audioBytes: bytes,
          filename: file.name,
          config: settings.snapshot(speakers: context.read<SpeakerStore>().profiles),
          title: _titleFromName(file.name),
        );
    Navigator.pushNamed(context, Routes.synthesizing);
  }

  String _titleFromName(String name) {
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    return base.replaceAll(RegExp(r'[_-]+'), ' ').trim().isEmpty ? 'Upload' : base.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const BrandTopBar(),
      bottomNavigationBar: const SpeechBottomNav(current: SpeechTab.upload),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  GestureDetector(onTap: _pick, child: _dropZone()),
                  const SizedBox(height: 12),
                  _sourceChips(),
                  const SizedBox(height: 24),
                  if (_file != null) ...[
                    _sectionLabel('SELECTED'),
                    const SizedBox(height: 8),
                    _selectedFile(_file!.name, _size),
                    const SizedBox(height: 24),
                  ],
                  _configSummary(settings, context.watch<SpeakerStore>().profiles.length),
                ],
              ),
            ),
            _actionArea(context),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(t,
            style: AppType.body(
                    size: 14, weight: FontWeight.w700, color: AppColors.onSurfaceVariant)
                .copyWith(letterSpacing: 1.5)),
      );

  Widget _dropZone() {
    return DottedBorderBox(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Symbols.cloud_upload, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('Choose an audio file', style: AppType.headline(size: 22)),
            const SizedBox(height: 8),
            Text('Tap to browse', style: AppType.body(size: 16, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 12),
            Text('WAV · MP3 · M4A · FLAC · OGG',
                style: AppType.body(size: 13, color: AppColors.tertiary)),
          ],
        ),
      ),
    );
  }

  Widget _sourceChips() {
    // Single centered entry point. The system picker it opens already lists
    // Google Drive (and other providers) as browsable locations on Android —
    // a separate "Drive" chip was misleading since real Drive integration
    // would need the Drive SDK + Google sign-in.
    Widget chip(IconData icon, String label) => GestureDetector(
          onTap: _pick,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.outlineVariant),
              boxShadow: const [BoxShadow(color: Color(0x0A0D3C48), blurRadius: 20, offset: Offset(0, 4))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: AppColors.onSurface),
              const SizedBox(width: 8),
              Text(label, style: AppType.body(size: 14, weight: FontWeight.w700)),
            ]),
          ),
        );
    return Center(child: chip(Symbols.folder, 'Browse Files'));
  }

  Widget _selectedFile(String name, int size) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [BoxShadow(color: Color(0x0A0D3C48), blurRadius: 20, offset: Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Symbols.audio_file, color: AppColors.cyan, fill: 1),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body(size: 16, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(_fmtSize(size),
                      style: AppType.body(size: 14, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() {
                _file = null;
                _bytes = null;
                _size = 0;
              }),
              icon: Icon(Symbols.close, color: AppColors.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _configSummary(SettingsStore s, int enrolledSpeakers) {
    final modelName = JobConfig.displayNameFor(s.model);
    final String langLabel;
    final String caption;
    if (!s.isClassic) {
      if (s.languageMode == 'omnilingual') {
        langLabel = 'Omni Mode · Melia-1';
        caption = "We'll detect every language spoken — even mixed — and translate it.";
      } else {
        langLabel = 'Classic Mode · ${s.singleLanguage.toUpperCase()} · Melia-1';
        caption = 'Transcribed as ${LangCatalog.nameFor(s.singleLanguage)} with the Melia-1 model.';
      }
    } else {
      if (s.classicLanguageMode == 'auto') {
        langLabel = 'Auto-detect · $modelName';
        caption = 'The spoken language is identified automatically by the classic $modelName model.';
      } else {
        langLabel = 'Classic Mode · ${s.classicLanguage.toUpperCase()} · $modelName';
        caption =
            'Transcribed as ${ClassicLangCatalog.nameFor(s.classicLanguage)} with the classic $modelName model.';
      }
    }
    // One entry per active setting — mirrors what the job will actually send
    // (e.g. the domain entry only shows when the mapper would emit it).
    String cap(String v) => v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);
    final domainApplied = s.isClassic &&
        s.model == 'enhanced' &&
        s.classicLanguageMode == 'specific' &&
        s.domain != 'none' &&
        ClassicLangCatalog.byId(s.classicLanguage)?.domain == null;
    final vocabCount =
        s.customDict ? ConfigMapper.parseVocab(s.customDictText).length : 0;
    final topicSeeds = ConfigMapper.parseTopics(s.topicsText).length;

    final entries = <(IconData, String)>[
      (Symbols.language, langLabel),
      if (domainApplied) (Symbols.domain, 'Domain · ${cap(s.domain)}'),
      if (s.diarization)
        (Symbols.groups,
            s.diarizationType == 'speaker' ? 'Diarization · Speakers' : 'Diarization · Channels'),
      // Mirrors the mapper: identification rides on classic speaker diarization.
      if (s.isClassic &&
          s.speakerIdentification &&
          s.diarization &&
          s.diarizationType == 'speaker' &&
          enrolledSpeakers > 0)
        (Symbols.record_voice_over,
            'Identify · $enrolledSpeakers ${enrolledSpeakers == 1 ? 'speaker' : 'speakers'}'),
      if (s.translation) (Symbols.translate, 'Translate to · ${s.targetLanguageName}'),
      if (!s.isClassic && s.languageHints.isNotEmpty)
        (Symbols.tips_and_updates,
            'Hints · ${s.languageHints.length}${s.languageHintsStrict ? ' · Strict' : ''}'),
      if (s.isClassic) ...[
        if (vocabCount > 0) (Symbols.menu_book, 'Dictionary · $vocabCount'),
        if (s.punctuation) (Symbols.edit_note, 'Punctuation · ${s.marks.length} marks'),
        if (s.audioFiltering) (Symbols.filter_alt, 'Audio filter · ${s.volume.round()}'),
        if (s.audioEvents && s.events.isNotEmpty)
          (Symbols.graphic_eq, 'Audio events · ${s.events.length}'),
        if (s.subtitles)
          (Symbols.subtitles,
              'Subtitles · ${s.subtitleMaxLineLength.round()} × ${s.subtitleMaxLines}'),
        if (s.summary) (Symbols.summarize, 'Summary · ${cap(s.summaryLength)}'),
        if (s.topics)
          (Symbols.label, topicSeeds == 0 ? 'Topics · Auto' : 'Topics · $topicSeeds'),
        if (s.chapters) (Symbols.bookmark, 'Chapters'),
      ],
    ];

    // Group 2-3 settings per bubble so the panel stays compact.
    final groups = <List<(IconData, String)>>[];
    for (var i = 0; i < entries.length; i += 3) {
      groups.add(entries.sublist(i, i + 3 > entries.length ? entries.length : i + 3));
    }

    Widget bubble(List<(IconData, String)> items) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(items[i].$1, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(items[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body(size: 13, weight: FontWeight.w600)),
                  ),
                ]),
              ],
            ],
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 12, runSpacing: 12, children: groups.map(bubble).toList()),
          const SizedBox(height: 12),
          Text(caption, style: AppType.body(size: 14, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _actionArea(BuildContext context) {
    final enabled = _file != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xE6F8FAF9),
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.outlineVariant,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: enabled ? _submit : null,
              child: Text('Transcribe & translate',
                  style: AppType.body(size: 14, weight: FontWeight.w700, color: Colors.white)
                      .copyWith(letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(height: 12),
          Text(enabled ? 'Runs as a Speechmatics batch job' : 'Choose an audio file to begin',
              style: AppType.body(size: 14, color: AppColors.tertiary)),
        ],
      ),
    );
  }

  String _fmtSize(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// A rounded rectangle with a dashed jade border (the upload drop zone).
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
        color: AppColors.primary.withValues(alpha: 0.4),
        radius: 16,
        dash: 6,
        gap: 5,
        strokeWidth: 2,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({
    required this.color,
    required this.radius,
    required this.dash,
    required this.gap,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final next = dist + dash;
        canvas.drawPath(metric.extractPath(dist, next.clamp(0, metric.length)), paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) =>
      old.color != color || old.radius != radius;
}
