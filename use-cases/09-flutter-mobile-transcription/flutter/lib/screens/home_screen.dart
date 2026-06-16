import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../models/history_item.dart';
import '../routes.dart';
import '../state/history_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/job_id_pill.dart';
import '../widgets/brand_top_bar.dart';
import '../widgets/lang_chip.dart';
import '../widgets/speech_bottom_nav.dart';
import 'transcription_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ripple =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _ripple.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const BrandTopBar(),
      bottomNavigationBar: const SpeechBottomNav(current: SpeechTab.home),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const SizedBox(height: 8),
            ..._batchContent(context),
          ],
        ),
      ),
    );
  }

  // ---- Batch ----
  List<Widget> _batchContent(BuildContext context) => [
        const SizedBox(height: 16),
        _hero(context),
        const SizedBox(height: 56),
        Row(
          children: [
            Expanded(
              child: Text('RECENT TRANSCRIPTIONS',
                  style: AppType.headline(
                      size: 13, color: AppColors.onSurfaceVariant)
                      .copyWith(letterSpacing: 2)),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, Routes.history),
              child: Text('VIEW ALL',
                  style: AppType.body(
                      size: 12,
                      weight: FontWeight.w700,
                      color: AppColors.primary)
                      .copyWith(letterSpacing: 1.5)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._recentCards(context),
      ];

  List<Widget> _recentCards(BuildContext context) {
    final recent = context.watch<HistoryStore>().recent.take(3).toList();
    if (recent.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Text('No transcriptions yet. Record or upload audio to begin.',
              style: AppType.body(size: 14, color: AppColors.onSurfaceVariant)),
        ),
      ];
    }
    final widgets = <Widget>[];
    for (final item in recent) {
      widgets.add(_recentCard(context, item));
      widgets.add(const SizedBox(height: 16));
    }
    widgets.removeLast();
    return widgets;
  }

  Widget _hero(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 256,
          height: 256,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _ripple,
                builder: (_, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    _ring(1.0, 0.0),
                    _ring(0.75, 0.33),
                    _ring(0.5, 0.66),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, child) {
                  final t = Curves.easeInOut.transform(_pulse.value);
                  return Transform.scale(
                    scale: 1 + 0.09 * t,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25 + 0.35 * t),
                            blurRadius: 18 + 34 * t,
                            spreadRadius: 1 + 9 * t,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  );
                },
                child: _recordButton(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppType.display(size: 40),
            children: const [
              TextSpan(text: 'Understand every '),
              TextSpan(text: 'voice.', style: TextStyle(color: AppColors.primary)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('READY TO CAPTURE',
            style: AppType.mono(
                size: 12, weight: FontWeight.w500, color: AppColors.onSurfaceVariant, spacing: 1.5)),
      ],
    );
  }

  Widget _ring(double sizeFactor, double phase) {
    final p = (_ripple.value + phase) % 1.0;
    final scale = 0.8 + p * 0.8; // 0.8 -> 1.6
    final opacity = p < 0.5 ? p * 0.3 : (1 - p) * 0.3;
    return Opacity(
      opacity: opacity.clamp(0, 1),
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 256 * sizeFactor,
          height: 256 * sizeFactor,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _recordButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, Routes.recording),
      child: Container(
        width: 88,
        height: 88,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Text(
          'START',
          style: AppType.headline(size: 16, weight: FontWeight.w700, color: Colors.white)
              .copyWith(letterSpacing: 1.5),
        ),
      ),
    );
  }

  Widget _avatar(IconData icon) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
    );
  }

  Widget _recentCard(BuildContext context, HistoryItem item) {
    return _card(
      onTap: () => Navigator.pushNamed(context, Routes.transcription,
          arguments: TranscriptionArgs(item.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniPill(_dateLabel(item), mono: true),
              if (item.languages.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LangCodeChip(item.languages.first),
                    if (item.languages.length > 1) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(item.arrow == '↔' ? Symbols.sync_alt : Symbols.arrow_forward,
                            size: 12, color: AppColors.onSurfaceVariant),
                      ),
                      LangCodeChip(item.languages.last),
                    ],
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.headline(size: 20)),
              ),
              const SizedBox(width: 4),
              _renameButton(() => _renameDialog(item)),
            ],
          ),
          const SizedBox(height: 8),
          Text(_snippet(item),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.body(size: 14, color: AppColors.onSurfaceVariant, height: 1.5)),
          const SizedBox(height: 12),
          JobIdPill(item.jobId),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _cardLeading(item),
              Icon(Symbols.arrow_forward, color: AppColors.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardLeading(HistoryItem item) {
    final speakers = item.speakers ?? 0;
    if (speakers > 1) {
      final shown = speakers > 4 ? 4 : speakers;
      const step = 20.0; // 28px avatar with an 8px overlap
      return SizedBox(
        width: 28 + (shown - 1) * step,
        height: 28,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < shown; i++)
              Positioned(left: i * step, child: _avatar(Symbols.person)),
          ],
        ),
      );
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10), shape: BoxShape.circle),
      child: Icon(item.isConversation ? Symbols.forum : Symbols.graphic_eq,
          size: 14, color: AppColors.primary),
    );
  }

  String _dateLabel(HistoryItem item) {
    if (item.createdAt != null) {
      return DateFormat('MMM d • HH:mm').format(item.createdAt!).toUpperCase();
    }
    return item.relativeLabel.toUpperCase();
  }

  String _snippet(HistoryItem item) {
    String text = '';
    final segs = item.segments;
    if (segs != null && segs.isNotEmpty) {
      text = segs.expand((s) => s.parts).map((p) => p.text).join(' ');
    } else if (item.translationText != null) {
      text = item.translationText!;
    }
    text = text.trim();
    if (text.isEmpty) return '';
    if (text.length > 120) text = '${text.substring(0, 120)}…';
    return '"$text"';
  }

  Widget _renameButton(VoidCallback onTap) {
    return Tooltip(
      message: 'Rename',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(Symbols.edit, size: 16, color: AppColors.onSurfaceVariant),
        ),
      ),
    );
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

  Widget _miniPill(String text, {bool mono = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: mono
                ? AppType.mono(size: 10, color: AppColors.onSurfaceVariant)
                : AppType.body(size: 10, color: AppColors.onSurfaceVariant)),
      );

  Widget _card({required Widget child, VoidCallback? onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: const [
            BoxShadow(color: Color(0x0D000000), blurRadius: 30, offset: Offset(0, 10)),
          ],
        ),
        child: child,
      ),
    );
  }

}
