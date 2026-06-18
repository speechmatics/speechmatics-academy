import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/share_text.dart';
import '../models/history_item.dart';
import '../state/transcript_player.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Speech-intelligence results — summary / topics / chapters / audio events /
/// SRT subtitles. Shared by the transcription result screen and the expanded
/// History card so the "Insights" view renders identically in both places.
class InsightsView extends StatefulWidget {
  const InsightsView({super.key, required this.item, this.player});

  final HistoryItem item;

  /// Powers the chapter play/stop buttons; null (no audio) hides them.
  final TranscriptPlayer? player;

  @override
  State<InsightsView> createState() => _InsightsViewState();
}

class _InsightsViewState extends State<InsightsView>
    with SingleTickerProviderStateMixin {
  // Pulsates the chapter play buttons (same rhythm as the Home START orb).
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _sections(widget.item),
    );
  }

  Widget _sectionHeader(String label, {required VoidCallback onCopy, Widget? extraAction}) {
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
          if (extraAction != null) extraAction,
          btn(Symbols.content_copy, 'Copy', AppColors.primary, onCopy),
        ]),
      ],
    );
  }

  /// Pulsing jade play button for a chapter (Home START orb styling). While
  /// playback is inside this chapter it becomes a static STOP button —
  /// tapping stop pauses and resets to the chapter start, so the next play
  /// begins the chapter from its beginning. Cold-start safe via
  /// [TranscriptPlayer.playFrom].
  Widget _chapterPlayButton(ChapterInfo chapter) {
    final tp = widget.player!;
    return ValueListenableBuilder<bool>(
      valueListenable: tp.isPlaying,
      builder: (_, playing, __) => ValueListenableBuilder<int>(
        valueListenable: tp.positionMs,
        builder: (_, posMs, __) {
          final playingThis = playing &&
              posMs >= (chapter.startSeconds * 1000).round() &&
              posMs < (chapter.endSeconds * 1000).round();
          return AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              // Pulse only while inviting play; the stop state sits still.
              final t = playingThis ? 0.0 : Curves.easeInOut.transform(_pulse.value);
              return GestureDetector(
                onTap: () => playingThis
                    ? tp.stopAndSeek(chapter.startSeconds)
                    : tp.playFrom(chapter.startSeconds),
                child: Transform.scale(
                  scale: 1 + 0.07 * t,
                  child: Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25 + 0.30 * t),
                          blurRadius: 12 + 18 * t,
                          spreadRadius: 1 + 4 * t,
                        ),
                      ],
                    ),
                    child: Icon(playingThis ? Symbols.stop : Symbols.play_arrow,
                        color: Colors.white, size: 19, fill: 1),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// White rounded card used by insights sections (translation-bubble styling).
  Widget _insightCard(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: child,
      );

  List<Widget> _sections(HistoryItem item) {
    final out = <Widget>[];

    if (item.summaryText != null) {
      out.addAll([
        _sectionHeader('SUMMARY', onCopy: () => _copy(item.summaryText!)),
        const SizedBox(height: 12),
        _insightCard(Text(item.summaryText!, style: AppType.body(size: 15, height: 1.55))),
        const SizedBox(height: 20),
      ]);
    }

    if (item.topicCounts != null) {
      out.addAll([
        _sectionHeader('TOPICS',
            onCopy: () => _copy(
                item.topicCounts!.entries.map((e) => '${e.key} (${e.value})').join('\n'))),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in item.topicCounts!.entries)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${e.key} · ${e.value}',
                    style: AppType.body(
                        size: 13, weight: FontWeight.w600, color: AppColors.primary)),
              ),
          ],
        ),
        const SizedBox(height: 20),
      ]);
    }

    if (item.chapters != null) {
      out.addAll([
        _sectionHeader('CHAPTERS',
            onCopy: () => _copy(
                item.chapters!.map((c) => '${c.timeLabel}  ${c.title}').join('\n'))),
        const SizedBox(height: 12),
        _insightCard(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < item.chapters!.length; i++) ...[
              if (i > 0) const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.chapters![i].timeLabel,
                      style: AppType.mono(
                          size: 12, weight: FontWeight.w700, color: AppColors.primary)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item.chapters![i].title,
                        style: AppType.body(size: 15, weight: FontWeight.w600)),
                  ),
                ],
              ),
              if (item.chapters![i].summary != null) ...[
                const SizedBox(height: 6),
                Text(item.chapters![i].summary!,
                    style: AppType.body(
                        size: 13, height: 1.5, color: AppColors.onSurfaceVariant)),
              ],
              if (widget.player != null) ...[
                const SizedBox(height: 12),
                Center(child: _chapterPlayButton(item.chapters![i])),
              ],
            ],
          ],
        )),
        const SizedBox(height: 20),
      ]);
    }

    if (item.audioEventCounts != null) {
      const icons = {
        'laughter': Symbols.mood,
        'music': Symbols.music_note,
        'applause': Symbols.celebration,
      };
      out.addAll([
        _sectionHeader('AUDIO EVENTS',
            onCopy: () => _copy(item.audioEventCounts!.entries
                .map((e) => '${e.key} × ${e.value}')
                .join('\n'))),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in item.audioEventCounts!.entries)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icons[e.key] ?? Symbols.graphic_eq, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('${e.key} × ${e.value}',
                      style: AppType.body(size: 13, weight: FontWeight.w600)),
                ]),
              ),
          ],
        ),
        const SizedBox(height: 20),
      ]);
    }

    if (item.srtText != null) {
      out.addAll([
        _sectionHeader('SUBTITLES (SRT)',
            onCopy: () => _copy(item.srtText!),
            extraAction: canShareFiles
                ? Builder(
                    builder: (context) => IconButton(
                      onPressed: () {
                        final box = context.findRenderObject() as RenderBox?;
                        shareTextAsFile(
                          content: item.srtText!,
                          baseName: item.title,
                          extension: 'srt',
                          sharePositionOrigin: box != null
                              ? box.localToGlobal(Offset.zero) & box.size
                              : null,
                        );
                      },
                      tooltip: 'Share .srt',
                      icon: Icon(Symbols.share, size: 20, color: AppColors.primary),
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  )
                : null),
        const SizedBox(height: 12),
        _insightCard(ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: SingleChildScrollView(
            child: Text(item.srtText!,
                style: AppType.mono(size: 12, color: AppColors.onSurfaceVariant)
                    .copyWith(height: 1.45)),
          ),
        )),
        const SizedBox(height: 20),
      ]);
    }

    return out;
  }
}
