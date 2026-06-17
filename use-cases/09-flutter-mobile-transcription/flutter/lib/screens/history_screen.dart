import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../models/history_item.dart';
import '../models/sample_data.dart';
import '../state/history_store.dart';
import '../state/transcript_player.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/job_id_pill.dart';
import '../widgets/brand_top_bar.dart';
import '../widgets/insights_view.dart';
import '../widgets/lang_chip.dart';
import '../widgets/segmented_toggle.dart';
import '../widgets/speech_bottom_nav.dart';
import '../widgets/word_highlight.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'all';
  String _query = '';
  String? _expandedId;
  String? _activeId; // last-opened card — gently highlighted to keep your place
  // View inside the expanded card (same toggle as the transcription result
  // screen). Only one card is open at a time, so a single value suffices.
  String _cardView = 'original';
  final Map<String, GlobalKey> _cardKeys = {};

  // One audio player at a time, owned by the currently expanded card.
  TranscriptPlayer? _tp;
  String? _tpItemId;
  int _tpGen = 0; // bumps invalidate pending deferred releases (e.g. re-expand)
  String? _teardownId; // card keeping its expanded content while animating shut
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Highlight the latest recording on entry.
    final items = context.read<HistoryStore>().items;
    if (items.isNotEmpty) _activeId = items.first.id;
  }

  @override
  void dispose() {
    _tp?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _cardKeys.putIfAbsent(id, () => GlobalKey());

  void _open(HistoryItem item) {
    setState(() {
      _expandedId = item.id;
      _activeId = item.id;
      _cardView = 'original'; // every card opens on the Original view
      _teardownId = null; // a card switching open cancels any pending teardown
    });
    _tpGen++; // invalidate any pending deferred release
    // Re-expanding the same card: reuse the live player (waveform shows
    // instantly, nothing is re-created).
    if (_tp != null && _tpItemId == item.id) return;
    _releaseNow();
    _initPlayer(item); // cheap: no native work until play is pressed
  }

  Future<void> _initPlayer(HistoryItem item) async {
    _tpItemId = item.id;
    final tp = await TranscriptPlayer.create(item);
    if (!mounted || _tpItemId != item.id || _expandedId != item.id) {
      tp?.dispose(); // card collapsed / switched while preparing
      return;
    }
    setState(() => _tp = tp);
  }

  /// Detach the player from the tree this frame and dispose it right after —
  /// for paths where no animation is running (delete, filter change, switch).
  void _releaseNow() {
    final tp = _tp;
    _tp = null;
    _tpItemId = null;
    if (tp == null) return;
    tp.stop();
    // Dispose after the detached frame renders, so no mounted widget is still
    // subscribed to the player's notifiers when they're disposed.
    WidgetsBinding.instance.addPostFrameCallback((_) => tp.dispose());
  }

  /// Collapse a card and scroll it back to the top of the viewport, so after
  /// closing a long transcript the user lands on that card with the next
  /// recording right below (rather than stranded mid-list). The card stays the
  /// highlighted "last opened" one.
  void _collapse(HistoryItem item) {
    // Audio stops immediately, but the expanded content stays mounted while
    // the card animates shut: tearing the subtree down mid-animation forced a
    // synchronous re-layout of the whole transcript when frames were scarce.
    _tp?.stop();
    setState(() {
      _expandedId = null;
      _activeId = item.id;
      _teardownId = item.id;
    });
    final gen = ++_tpGen;
    Future.delayed(const Duration(milliseconds: 650), () => _teardownWhenIdle(gen));
    // Scroll to the card only AFTER the collapse animation finishes: computing
    // the target mid-shrink uses stale geometry and can park the offset beyond
    // the (shrunken) max scroll extent — which then visibly snaps into range
    // on the user's next touch ("first scroll jumps to under the header").
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted || _expandedId != null) return;
      // Safe: this context comes fresh from the GlobalKey AFTER the delay and
      // mounted check — it is not a captured stale context.
      final ctx = _cardKeys[item.id]?.currentContext;
      if (ctx != null) {
        // ignore: use_build_context_synchronously
        Scrollable.ensureVisible(ctx, alignment: 0.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  /// Drops the torn-down card's hidden subtree and disposes its player — but
  /// NEVER while the user is scrolling: a mid-drag setState re-layouts the
  /// list and visibly "snaps" the scroll position. Defers until the scroll
  /// settles, then runs.
  void _teardownWhenIdle(int gen) {
    if (!mounted || _tpGen != gen) return;
    if (_scroll.hasClients) {
      final scrolling = _scroll.position.isScrollingNotifier;
      if (scrolling.value) {
        late VoidCallback onSettle;
        onSettle = () {
          scrolling.removeListener(onSettle);
          _teardownWhenIdle(gen); // re-checks mounted/gen/scrolling
        };
        scrolling.addListener(onSettle);
        return;
      }
    }
    final tp = _tp;
    _tp = null;
    _tpItemId = null;
    setState(() => _teardownId = null);
    if (tp != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => tp.dispose());
    }
  }

  static const _filters = [
    ('all', 'All'),
    ('favorites', 'Favourites'),
    ('today', 'Today'),
    ('week', 'Week'),
  ];

  bool _matchesFilter(HistoryItem i) {
    switch (_filter) {
      case 'favorites':
        return i.favorite;
      case 'today':
        return i.effectiveBucket == 'today';
      case 'week':
        return ['today', 'yesterday', 'week'].contains(i.effectiveBucket);
      default:
        return true;
    }
  }

  bool _matchesSearch(HistoryItem i) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    final typeLabel = i.type == HistoryType.conversation ? 'live transcription' : 'recording';
    return [i.title, typeLabel, ...i.languages].any((v) => v.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<HistoryStore>().items;
    final filtered = items.where((i) => _matchesFilter(i) && _matchesSearch(i)).toList();
    final groups = <String, List<HistoryItem>>{};
    for (final i in filtered) {
      groups.putIfAbsent(i.effectiveBucket, () => []).add(i);
    }

    // The expanded card was filtered/searched out of view — release its audio
    // player (otherwise playback continues invisibly) and reset the expansion.
    if (_expandedId != null && !filtered.any((i) => i.id == _expandedId)) {
      _tpGen++;
      _releaseNow();
      _expandedId = null;
      _teardownId = null;
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      extendBodyBehindAppBar: true,
      appBar: const BrandTopBar(),
      bottomNavigationBar: const SpeechBottomNav(current: SpeechTab.history),
      body: SafeArea(
        child: ListView(
          controller: _scroll,
          // Bouncing physics: fast flings into the top edge decelerate with a
          // soft bounce instead of the clamping dead-stop, which read as the
          // list "snapping" the first card under its section header.
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text('History',
                style: AppType.display(size: 24, weight: FontWeight.w600, color: const Color(0xFF0D3C48))),
            const SizedBox(height: 4),
            Text('Review previous transcriptions and conversations',
                style: AppType.body(size: 14, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 16),
            _searchField(),
            const SizedBox(height: 16),
            _filterBar(),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              _emptyState()
            else
              ...historyBuckets.where(groups.containsKey).map((b) => _group(b, groups[b]!)),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      onChanged: (v) => setState(() => _query = v),
      style: AppType.body(size: 14),
      decoration: InputDecoration(
        hintText: 'Search transcripts...',
        hintStyle: AppType.body(size: 14, color: AppColors.onSurfaceVariant),
        prefixIcon: Icon(Symbols.search, size: 20, color: AppColors.onSurfaceVariant),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: _filters.map((f) {
          final active = _filter == f.$1;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_filter == f.$1) return;
                setState(() => _filter = f.$1);
              },
              // Plain Container — an animated cross-fade here briefly showed
              // TWO chips highlighted on quick taps (the outgoing one was
              // still fading), which read as a double selection.
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: active
                      ? const [BoxShadow(color: Color(0x0F000000), blurRadius: 2, offset: Offset(0, 1))]
                      : null,
                ),
                child: Text(f.$2,
                    style: AppType.body(
                        size: 12,
                        weight: FontWeight.w600,
                        color: active ? AppColors.onSurface : AppColors.onSurfaceVariant)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _group(String bucket, List<HistoryItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
          child: Text(bucketLabels[bucket]!.toUpperCase(),
              style: AppType.body(size: 11, weight: FontWeight.w700, color: AppColors.onSurfaceVariant)
                  .copyWith(letterSpacing: 1.0)),
        ),
        ...items.map(_card),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _card(HistoryItem item) {
    final open = _expandedId == item.id;
    final active = _activeId == item.id; // last-opened card (gentle highlight)
    return AnimatedContainer(
      key: _keyFor(item.id),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.primary.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: open
              ? AppColors.primary.withValues(alpha: 0.45)
              : (active ? AppColors.primary.withValues(alpha: 0.3) : AppColors.outlineVariant),
          width: active ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => open ? _collapse(item) : _open(item),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _langPair(item),
                      const Spacer(),
                      // Star (favourite) sits left of the type badge; its own
                      // gesture wins so tapping never expands the card.
                      InkWell(
                        onTap: () => context.read<HistoryStore>().toggleFavorite(item.id),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Symbols.star,
                            size: 18,
                            fill: item.favorite ? 1 : 0,
                            color: item.favorite
                                ? AppColors.warningAmber
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _typeBadge(item.type),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.body(size: 16, weight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 4),
                                _renameButton(() => _renameDialog(item)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(item.metaParts.join('  ·  '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.body(size: 12, color: AppColors.onSurfaceVariant)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                JobIdPill(item.jobId),
                                const Spacer(),
                                _iconAction(Symbols.content_copy, AppColors.primary,
                                    'Copy transcript', () => _copyTranscript(item)),
                                _iconAction(Symbols.delete, AppColors.error, 'Delete',
                                    () => _confirmDelete(item)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: open ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Symbols.chevron_right, size: 20, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            alignment: Alignment.topLeft,
            firstChild: const SizedBox(width: double.infinity),
            // AnimatedCrossFade keeps BOTH children mounted and laid out — a
            // fully-built transcript per collapsed card made the whole list
            // heavy (scroll jank, stutter on rebuilds). Only the open card and
            // the one still animating shut get real content; everything else
            // carries an empty box.
            // Tapping anywhere on the expanded transcript collapses the card;
            // interactive children (e.g. Resume) win the gesture.
            secondChild: (open || _teardownId == item.id)
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _collapse(item),
                    child: _expanded(item),
                  )
                : const SizedBox(width: double.infinity),
            crossFadeState: open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _langPair(HistoryItem item) {
    if (item.languages.isEmpty) return const SizedBox.shrink();
    if (item.languages.length == 1) return LangCodeChip(item.languages.first);
    final icon = item.arrow == '↔' ? Symbols.sync_alt : Symbols.arrow_forward;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      LangCodeChip(item.languages.first),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
      ),
      LangCodeChip(item.languages.last),
    ]);
  }

  Widget _typeBadge(HistoryType t) {
    final label = t == HistoryType.conversation ? 'Live transcription' : 'Recording';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.outlineVariant),
        color: Colors.white,
      ),
      child: Text(label.toUpperCase(),
          style: AppType.body(size: 10, weight: FontWeight.w700, color: AppColors.onSurfaceVariant)
              .copyWith(letterSpacing: 0.8)),
    );
  }

  Widget _expanded(HistoryItem item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Same view toggle as the transcription result screen.
          if (!item.isConversation) ...[
            SegmentedToggle<String>(
              value: _cardView,
              onChanged: (v) => setState(() => _cardView = v),
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
            const SizedBox(height: 12),
          ],
          if (_tp != null && _tpItemId == item.id) ...[
            PlaybackBar(player: _tp!),
            const SizedBox(height: 12),
          ],
          if (item.isConversation) _conversation(item) else _batch(item),
          // Copy & Delete now live on the JOB ID row (always visible without scrolling).
          if (item.isConversation) ...[
            const SizedBox(height: 4),
            _resumeButton(item),
          ],
        ],
      ),
    );
  }


  Widget _batch(HistoryItem item) {
    // Safety guard — the Insights segment only exists when the item has
    // insights, but never strand the view on an empty tab.
    final view = (_cardView == 'insights' && !item.hasInsights) ? 'original' : _cardView;

    if (view == 'insights') {
      // Same widget as the transcription result screen's Insights view.
      return InsightsView(
        item: item,
        player: (_tp != null && _tpItemId == item.id) ? _tp : null,
      );
    }

    final showOriginal = view == 'original' || view == 'split';
    final showTranslation = view == 'translation' || view == 'split';
    final segments = item.segments ?? const <TranscriptSegment>[];
    // Word highlight only applies to the card that owns the active player.
    final activeWord = (_tp != null && _tpItemId == item.id) ? _tp!.activeWord : null;
    final translation = (item.translationText ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showOriginal)
          for (var s = 0; s < segments.length; s++) ...[
            Row(children: [
              Text(segments[s].speaker, style: AppType.body(size: 12, weight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text(segments[s].time, style: AppType.mono(size: 10, color: AppColors.onSurfaceVariant)),
            ]),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.start,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var pIdx = 0; pIdx < segments[s].parts.length; pIdx++)
                    Builder(builder: (context) {
                      final p = segments[s].parts[pIdx];
                      final card = Row(mainAxisSize: MainAxisSize.min, children: [
                        LangCodeChip(p.lang),
                        const SizedBox(width: 8),
                        Flexible(
                          child: highlightedPartText(p,
                              seg: s,
                              partIndex: pIdx,
                              activeWord: activeWord,
                              style: AppType.body(size: 14)),
                        ),
                      ]);
                      return Container(
                        // No width cap — bubbles may use the full card width,
                        // aligning with the playback bar above.
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: p.isRtl
                            ? Directionality(textDirection: TextDirection.rtl, child: card)
                            : card,
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        if (showTranslation) ...[
          Row(children: [
            Icon(Symbols.translate, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('TRANSLATED',
                style: AppType.body(size: 11, weight: FontWeight.w700, color: AppColors.onSurfaceVariant)
                    .copyWith(letterSpacing: 1.0)),
          ]),
          const SizedBox(height: 6),
          if (translation.isNotEmpty)
            Text(item.translationText!, style: AppType.body(size: 14, height: 1.5))
          else
            Text('Translation not available. Enable Google translation in Settings.',
                style: AppType.body(size: 14, color: AppColors.onSurfaceVariant)),
        ],
      ],
    );
  }

  Widget _conversation(HistoryItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final turn in item.conversation ?? const <ConversationTurn>[]) ...[
          Row(children: [
            Text(turn.role.toUpperCase(),
                style: AppType.body(
                        size: 11,
                        weight: FontWeight.w700,
                        color: turn.isUser ? AppColors.primary : AppColors.onSurfaceVariant)
                    .copyWith(letterSpacing: 1.0)),
            const SizedBox(width: 8),
            LangCodeChip(turn.lang),
          ]),
          const SizedBox(height: 4),
          turn.isRtl
              ? Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(turn.text, style: AppType.body(size: 14, height: 1.5)))
              : Text(turn.text, style: AppType.body(size: 14, height: 1.5)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _iconAction(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _resumeButton(HistoryItem item) {
    return FilledButton.icon(
      onPressed: () => _toast('Resuming conversation'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Symbols.forum, size: 16, color: Colors.white),
      label: Text('Resume Conversation',
          style: AppType.body(size: 12, weight: FontWeight.w600, color: Colors.white)),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  String _plainText(HistoryItem item) {
    final buf = StringBuffer();
    if (item.isConversation) {
      for (final t in item.conversation ?? const <ConversationTurn>[]) {
        buf.writeln('${t.role}: ${t.text}');
      }
    } else {
      for (final s in item.segments ?? const <TranscriptSegment>[]) {
        buf.writeln('${s.speaker}: ${s.parts.map((p) => p.text).join(' ')}');
      }
      if ((item.translationText ?? '').trim().isNotEmpty) {
        buf
          ..writeln()
          ..writeln('Translation:')
          ..writeln(item.translationText);
      }
      if (item.summaryText != null) {
        buf
          ..writeln()
          ..writeln('Summary:')
          ..writeln(item.summaryText);
      }
      if (item.topicCounts != null) {
        buf
          ..writeln()
          ..writeln('Topics:')
          ..writeln(item.topicCounts!.entries.map((e) => '${e.key} (${e.value})').join('\n'));
      }
      if (item.chapters != null) {
        buf
          ..writeln()
          ..writeln('Chapters:')
          ..writeln(item.chapters!.map((c) => '${c.timeLabel} ${c.title}').join('\n'));
      }
    }
    return buf.toString().trim();
  }

  void _copyTranscript(HistoryItem item) {
    Clipboard.setData(ClipboardData(text: _plainText(item)));
    _toast('Copied to clipboard');
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
    if (result != null && result.isNotEmpty) {
      if (!mounted) return;
      context.read<HistoryStore>().rename(item.id, result);
      _toast('Title updated');
    }
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
    if (ok == true) {
      if (!mounted) return;
      if (_tpItemId == item.id) {
        _tpGen++;
        _releaseNow(); // release the audio file before deleting it
      }
      if (_expandedId == item.id) setState(() => _expandedId = null);
      context.read<HistoryStore>().delete(item.id);
      _toast('Transcript deleted');
    }
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Symbols.history, size: 28, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text('No transcripts yet', style: AppType.headline(size: 18)),
          const SizedBox(height: 4),
          Text('Start your first transcription or conversation.',
              textAlign: TextAlign.center,
              style: AppType.body(size: 14, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
