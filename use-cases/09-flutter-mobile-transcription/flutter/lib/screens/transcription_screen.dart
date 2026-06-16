import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../models/history_item.dart';
import '../models/lang_catalog.dart';
import '../state/history_store.dart';
import '../state/transcript_player.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_top_bar.dart';
import '../widgets/insights_view.dart';
import '../widgets/lang_chip.dart';
import '../widgets/segmented_toggle.dart';
import '../widgets/speech_bottom_nav.dart';
import '../widgets/word_highlight.dart';

/// Navigation argument: which history item to display.
class TranscriptionArgs {
  const TranscriptionArgs(this.id);
  final String id;
}

const _speakerColors = [
  AppColors.primary,
  AppColors.violet,
  AppColors.cyan,
  AppColors.amber,
];

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  String _view = 'original';

  TranscriptPlayer? _tp;
  String? _playerItemId; // guard: init the player once per item

  bool get _showOriginal => _view == 'original' || _view == 'split';
  bool get _showTranslation => _view == 'translation' || _view == 'split';
  bool _showInsights(HistoryItem item) => _view == 'insights' && item.hasInsights;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute args aren't available in initState; resolve the item here.
    final store = context.read<HistoryStore>();
    final args = ModalRoute.of(context)?.settings.arguments;
    final id = args is TranscriptionArgs ? args.id : null;
    final item = (id != null ? store.byId(id) : null) ??
        (store.items.isNotEmpty ? store.items.first : null);
    if (item == null || item.id == _playerItemId) return;
    _playerItemId = item.id;
    _initPlayer(item);
  }

  Future<void> _initPlayer(HistoryItem item) async {
    _tp?.dispose();
    _tp = null;
    // No artificial delay: create() does no native work (the player prepares
    // lazily on first play), so the playback bar can show immediately.
    final tp = await TranscriptPlayer.create(item);
    if (!mounted || _playerItemId != item.id) {
      tp?.dispose();
      return;
    }
    setState(() => _tp = tp);
  }

  @override
  void dispose() {
    _tp?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HistoryStore>();
    final args = ModalRoute.of(context)?.settings.arguments;
    final id = args is TranscriptionArgs ? args.id : null;
    final item = (id != null ? store.byId(id) : null) ??
        (store.items.isNotEmpty ? store.items.first : null);

    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      extendBodyBehindAppBar: true,
      appBar: BrandTopBar(
        trailing: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(Symbols.close, size: 22, color: AppColors.onSurface),
            style: IconButton.styleFrom(shape: const CircleBorder()),
          ),
        ],
      ),
      bottomNavigationBar: const SpeechBottomNav(current: SpeechTab.none),
      body: SafeArea(
        child: item == null ? _empty() : _content(context, item),
      ),
    );
  }

  Widget _empty() => Center(
        child: Text('No transcript to show.',
            style: AppType.body(size: 16, color: AppColors.onSurfaceVariant)),
      );

  Widget _content(BuildContext context, HistoryItem item) {
    final segments = item.segments ?? const <TranscriptSegment>[];
    final speakerColor = <String, Color>{};
    for (final s in segments) {
      speakerColor.putIfAbsent(
          s.speaker, () => _speakerColors[speakerColor.length % _speakerColors.length]);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // Title
        Row(
          children: [
            Flexible(
              child: Text(item.title,
                  style: AppType.display(size: 28, weight: FontWeight.w600)),
            ),
            IconButton(
              onPressed: () => _rename(item),
              icon: Icon(Symbols.edit, size: 18, color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Language chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: item.languages
              .map((c) => LangPill(LangCatalog.nameFor(c), code: c))
              .toList(),
        ),
        const SizedBox(height: 16),
        _metaRow(item),
        const SizedBox(height: 16),
        SegmentedToggle<String>(
          value: _view,
          onChanged: (v) => setState(() => _view = v),
          // expand keeps all 4 segments inside the pill's bounds (without it
          // the Insights segment overflowed the container) — same config as
          // the History card toggle.
          expand: true,
          segHPad: 8,
          segVPad: 6,
          fontSize: 12,
          items: [
            const SegItem('original', 'Original'),
            const SegItem('translation', 'Translation'),
            const SegItem('split', 'Split View'),
            // Only exists when the job produced speech-intelligence results.
            if (item.hasInsights) const SegItem('insights', 'Insights'),
          ],
        ),
        const SizedBox(height: 16),
        // Playback strip stays visible in every view — the audio belongs to
        // the whole transcript.
        if (_tp != null) ...[
          PlaybackBar(player: _tp!),
          const SizedBox(height: 16),
        ],
        if (_showInsights(item)) InsightsView(item: item, player: _tp),
        if (_showOriginal || (_view == 'insights' && !item.hasInsights)) ...[
          _sectionHeader('ORIGINAL TRANSCRIPT',
              onCopy: () => _copy(_plainOriginal(item)),
              onDelete: () => _confirmDelete(item)),
          const SizedBox(height: 12),
          for (var s = 0; s < segments.length; s++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SpeakerGroup(
                color: speakerColor[segments[s].speaker] ?? AppColors.primary,
                segment: segments[s],
                segIndex: s,
                activeWord: _tp?.activeWord,
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (_showTranslation) ...[
          _sectionHeader('${item.targetLanguage ?? 'Translation'} Translation'.toUpperCase(),
              onCopy: () => _copy(item.translationText ?? ''),
              onDelete: () => _confirmDelete(item)),
          const SizedBox(height: 12),
          _translationBubble(item, speakerColor),
          const SizedBox(height: 16),
        ],
        Opacity(
          opacity: 0.6,
          child: Row(children: [
            Icon(Symbols.verified_user, size: 16, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Melia auto-language detection and RTL support active.',
                  style: AppType.body(size: 12, weight: FontWeight.w500)),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _metaRow(HistoryItem item) {
    Widget item0(IconData icon, String label, {bool primary = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: primary ? AppColors.primary : AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label,
                style: AppType.body(size: 12, weight: FontWeight.w500, color: AppColors.onSurfaceVariant)),
          ],
        );
    Widget dot() => Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(color: AppColors.outline, shape: BoxShape.circle),
        );
    final chips = <Widget>[
      item0(Symbols.analytics, '${item.languages.length} ${item.languages.length == 1 ? 'LANGUAGE' : 'LANGUAGES'}', primary: true),
      if (item.duration != null) ...[dot(), item0(Symbols.schedule, '${item.duration} DURATION')],
      if (item.speakers != null) ...[
        dot(),
        item0(Symbols.groups, '${item.speakers} ${item.speakers == 1 ? 'SPEAKER' : 'SPEAKERS'}'),
      ],
    ];
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: chips);
  }

  Widget _sectionHeader(String label,
      {required VoidCallback onCopy, VoidCallback? onDelete}) {
    Widget btn(IconData icon, String tooltip, Color color, VoidCallback onTap) => IconButton(
          onPressed: onTap,
          tooltip: tooltip,
          icon: Icon(icon, size: 20, color: color),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.all(8),
          ),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.body(size: 12, weight: FontWeight.w700, color: AppColors.onSurfaceVariant)
                  .copyWith(letterSpacing: 1.2)),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          btn(Symbols.content_copy, 'Copy', AppColors.primary, onCopy),
          if (onDelete != null) btn(Symbols.delete, 'Delete', AppColors.error, onDelete),
        ]),
      ],
    );
  }

  Widget _translationBubble(HistoryItem item, Map<String, Color> speakerColor) {
    final segments = item.segments ?? const <TranscriptSegment>[];
    final lines = (item.translationText ?? '').split('\n');
    final hasTranslation = (item.translationText ?? '').trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasTranslation)
            Text('Translation not available. Enable Google translation in Settings.',
                style: AppType.body(size: 14, color: AppColors.onSurfaceVariant))
          else if (lines.length == segments.length)
            for (var i = 0; i < segments.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == segments.length - 1 ? 0 : 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: speakerColor[segments[i].speaker] ?? AppColors.primary,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(segments[i].speaker,
                              style: AppType.body(size: 12, weight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(lines[i], style: AppType.body(size: 16, height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              )
          else
            Text(item.translationText!, style: AppType.body(size: 16, height: 1.6)),
        ],
      ),
    );
  }

  String _plainOriginal(HistoryItem item) => (item.segments ?? [])
      .map((s) => '${s.speaker}: ${s.parts.map((p) => p.text).join(' ')}')
      .join('\n');

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _confirmDelete(HistoryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transcript?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _tp?.stop(); // don't delete the audio file mid-playback
    if (!mounted) return;
    context.read<HistoryStore>().delete(item.id);
    Navigator.maybePop(context);
  }

  Future<void> _rename(HistoryItem item) async {
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    if (!mounted) return;
    context.read<HistoryStore>().rename(item.id, result);
  }
}

/// Expandable speaker block with code-switching segment cards.
class _SpeakerGroup extends StatefulWidget {
  const _SpeakerGroup({
    required this.color,
    required this.segment,
    required this.segIndex,
    this.activeWord,
  });

  final Color color;
  final TranscriptSegment segment;
  final int segIndex;

  /// Playback position mapped to a word (null = no audio for this item).
  final ValueListenable<ActiveWord?>? activeWord;

  @override
  State<_SpeakerGroup> createState() => _SpeakerGroupState();
}

class _SpeakerGroupState extends State<_SpeakerGroup> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final seg = widget.segment;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Text(seg.speaker, style: AppType.body(size: 14, weight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Text(seg.time, style: AppType.mono(size: 11, color: AppColors.onSurfaceVariant)),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _open ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Symbols.chevron_right, size: 18, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            alignment: Alignment.topLeft,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Wrap(
                  alignment: WrapAlignment.start,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var p = 0; p < seg.parts.length; p++) _segmentCard(seg.parts[p], p),
                  ],
                ),
              ),
            ),
            crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _segmentCard(TranscriptPart p, int partIndex) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LangCodeChip(p.lang),
        const SizedBox(width: 8),
        Flexible(
          child: highlightedPartText(p,
              seg: widget.segIndex,
              partIndex: partIndex,
              activeWord: widget.activeWord,
              style: AppType.body(size: 16)),
        ),
      ],
    );
    return Container(
      // No width cap — bubbles may use the full card width (matches History).
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: p.isRtl
          ? Directionality(textDirection: TextDirection.rtl, child: content)
          : content,
    );
  }
}
