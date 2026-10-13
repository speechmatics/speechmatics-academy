import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../models/classic_lang_catalog.dart';
import '../models/google_lang_catalog.dart';
import '../models/lang_catalog.dart';
import '../state/settings_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_top_bar.dart';

/// Which language setting this panel edits. One shared full-screen design
/// (mirrors the Language Hints selection screen) for every language choice in
/// the app; the mode picks the catalog, the selection semantics and which
/// SettingsStore field is written.
enum TranslateTargetMode {
  /// Batch "Translate to" — Google Translate target, single-select.
  batchGoogle,

  /// Real-Time "Translate to" — Google-powered like Batch,
  /// single-select.
  rtGoogle,

  /// Real-Time source language — classic catalog, single-select.
  rtSource,

  /// Batch classic (Standard/Enhanced) language — classic catalog incl.
  /// bilingual packs, single-select, with a pinned Auto-detect action that
  /// clears the specific choice.
  batchLanguage,
}

class TranslateTargetArgs {
  const TranslateTargetArgs(this.mode);
  final TranslateTargetMode mode;
}

/// Full-screen translation-target picker (same panel language as the
/// Language Hints screen: search, selected chip, bordered language list).
class TranslateTargetScreen extends StatefulWidget {
  const TranslateTargetScreen({super.key});

  @override
  State<TranslateTargetScreen> createState() => _TranslateTargetScreenState();
}

class _TranslateTargetScreenState extends State<TranslateTargetScreen> {
  String _query = '';

  TranslateTargetMode get _mode {
    final args = ModalRoute.of(context)?.settings.arguments;
    return args is TranslateTargetArgs
        ? args.mode
        : TranslateTargetMode.batchGoogle;
  }

  /// Classic catalog entries as panel rows (native names where the omni
  /// catalog knows them; bilingual packs labelled as such).
  List<LangInfo> _classicAsLangInfo({required bool includePacks}) {
    final entries = [
      for (final l in ClassicLangCatalog.all)
        if (includePacks || !l.bilingual) l
    ]..sort((a, b) => a.name.compareTo(b.name));
    return [
      for (final l in entries)
        LangInfo(
          l.id,
          l.name,
          l.bilingual ? 'Bilingual pack' : (LangCatalog.info(l.id)?.native ?? ''),
          rtl: LangCatalog.isRtl(l.id),
        ),
    ];
  }

  List<LangInfo> get _catalog => switch (_mode) {
        TranslateTargetMode.batchGoogle ||
        TranslateTargetMode.rtGoogle =>
          GoogleLangCatalog.all,
        TranslateTargetMode.rtSource =>
          _classicAsLangInfo(includePacks: false),
        TranslateTargetMode.batchLanguage =>
          _classicAsLangInfo(includePacks: true),
      };

  Set<String> _selectedCodes(SettingsStore s) => switch (_mode) {
        TranslateTargetMode.batchGoogle => {s.targetLanguageCode},
        TranslateTargetMode.rtGoogle => {s.rtTargetLanguageCode},
        TranslateTargetMode.rtSource => {s.rtLanguage},
        TranslateTargetMode.batchLanguage =>
          s.classicLanguageMode == 'specific' ? {s.classicLanguage} : {},
      };

  void _select(SettingsStore s, LangInfo l) {
    // Tapping the language that is already selected clears it (same action
    // as the CLEAR ALL header button).
    if (_selectedCodes(s).contains(l.code)) {
      _clear(s);
      return;
    }
    switch (_mode) {
      case TranslateTargetMode.batchGoogle:
        s.setTarget(l.code, l.name);
        Navigator.pop(context);
      case TranslateTargetMode.rtGoogle:
        s.setRtTarget(l.code, l.name);
        Navigator.pop(context);
      case TranslateTargetMode.rtSource:
        s.setRtLanguage(l.code);
        Navigator.pop(context);
      case TranslateTargetMode.batchLanguage:
        s.setClassicLanguageMode('specific');
        s.setClassicLanguage(l.code);
        Navigator.pop(context);
    }
  }

  /// CLEAR ALL semantics per mode: translation targets turn the feature's
  /// toggle off (the stored target survives for when it's re-enabled);
  /// the batch classic language falls back to Auto-detect; the RT source is
  /// mandatory, so it resets to the English default.
  void _clear(SettingsStore s) {
    switch (_mode) {
      case TranslateTargetMode.batchGoogle:
        s.setTranslation(false);
        _snack('Translation turned off.');
      case TranslateTargetMode.rtGoogle:
        s.setRtTranslation(false);
        _snack('Live translation turned off.');
      case TranslateTargetMode.rtSource:
        s.setRtLanguage('en');
        _snack('Source language reset to English.');
      case TranslateTargetMode.batchLanguage:
        s.setClassicLanguageMode('auto');
        _snack('Back to automatic language detection.');
    }
    Navigator.pop(context);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

  List<LangInfo> get _filtered {
    if (_query.isEmpty) return _catalog;
    final q = _query.toLowerCase();
    return _catalog
        .where((l) =>
            l.name.toLowerCase().contains(q) ||
            l.native.toLowerCase().contains(q) ||
            l.code.toLowerCase().contains(q))
        .toList();
  }

  String get _caption => switch (_mode) {
        TranslateTargetMode.batchGoogle =>
          'Transcripts are translated to this language with Google Translate',
        TranslateTargetMode.rtGoogle =>
          'Live captions are translated to this language with Google Translate as you speak',
        TranslateTargetMode.rtSource =>
          'Live captions are transcribed in this language',
        TranslateTargetMode.batchLanguage =>
          'Classic models transcribe one specific language — or detect it automatically',
      };

  String get _footer => switch (_mode) {
        TranslateTargetMode.rtSource =>
          '${_catalog.length} real-time languages',
        TranslateTargetMode.batchLanguage =>
          '${_catalog.length} classic languages and packs',
        _ => '${_catalog.length} languages supported by Google Translate',
      };

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsStore>();
    final filtered = _filtered;
    final selectedCodes = _selectedCodes(s);
    final selectedLangs = _catalog
        .where((l) => selectedCodes.contains(l.code))
        .toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const BrandTopBar(leading: TopBarLeading.back),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
          children: [
            const SizedBox(height: 8),
            _searchField(),
            const SizedBox(height: 12),
            Text(_caption,
                style: AppType.body(size: 14, color: AppColors.primary, height: 1.4)),
            const SizedBox(height: 24),
            if (selectedLangs.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Text('SELECTED',
                        style: AppType.headline(
                                size: 12, color: AppColors.tertiary)
                            .copyWith(letterSpacing: 2)),
                  ),
                  InkWell(
                    onTap: () => _clear(s),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Text('CLEAR ALL',
                          style: AppType.body(
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color: AppColors.recordActive)
                              .copyWith(letterSpacing: 1.5)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedLangs.map(_selectedChip).toList(),
              ),
              const SizedBox(height: 24),
            ],
            if (_mode == TranslateTargetMode.batchLanguage) ...[
              _autoDetectCard(s),
              const SizedBox(height: 24),
            ],
            Text('ALL LANGUAGES',
                style: AppType.headline(size: 12, color: AppColors.tertiary)
                    .copyWith(letterSpacing: 2)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant),
                boxShadow: const [
                  BoxShadow(color: Color(0x08000000), blurRadius: 20, offset: Offset(0, 4)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (int i = 0; i < filtered.length; i++)
                    _langRow(s, filtered[i], selectedCodes.contains(filtered[i].code),
                        last: i == filtered.length - 1),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Opacity(
              opacity: 0.7,
              child: Text(_footer,
                  textAlign: TextAlign.center,
                  style: AppType.body(size: 12, color: AppColors.tertiary)),
            ),
          ],
        ),
      ),
    );
  }

  /// Pinned "clear" action for the batch classic language: back to
  /// language identification (language: auto).
  Widget _autoDetectCard(SettingsStore s) {
    final on = s.classicLanguageMode == 'auto';
    return Container(
      decoration: BoxDecoration(
        color: on ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: on ? AppColors.primary : AppColors.outlineVariant),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 20, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          s.setClassicLanguageMode('auto');
          Navigator.pop(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: on
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.surfaceContainerHighest,
                    shape: BoxShape.circle),
                child: Icon(Symbols.travel_explore,
                    size: 20,
                    color: on ? AppColors.primary : AppColors.onSurface),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auto-detect',
                        style: AppType.body(size: 16, weight: FontWeight.w600)),
                    Text('The language is identified automatically',
                        style:
                            AppType.body(size: 14, color: AppColors.tertiary)),
                  ],
                ),
              ),
              if (on)
                Icon(Symbols.check_circle,
                    size: 22, color: AppColors.primary, fill: 1)
              else
                Icon(Symbols.radio_button_unchecked,
                    size: 22, color: AppColors.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      onChanged: (v) => setState(() => _query = v),
      style: AppType.body(size: 16),
      decoration: InputDecoration(
        hintText: 'Search languages',
        hintStyle: AppType.body(size: 16, color: AppColors.tertiary),
        prefixIcon: Icon(Symbols.search, color: AppColors.tertiary),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.surfaceContainerHighest),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _selectedChip(LangInfo l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Symbols.translate, size: 14, color: Colors.white),
        const SizedBox(width: 6),
        Text(l.name,
            style: AppType.headline(size: 12, weight: FontWeight.w500, color: Colors.white)),
      ]),
    );
  }

  Widget _langRow(SettingsStore s, LangInfo l, bool on,
      {required bool last, bool isSource = false}) {
    return Container(
      decoration: BoxDecoration(
        color: on ? AppColors.primary.withValues(alpha: 0.05) : null,
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.surfaceContainerLow)),
      ),
      child: InkWell(
        onTap: isSource
            ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'This is the source language — captions already stream in it.'),
                duration: Duration(seconds: 2)))
            : () => _select(s, l),
        child: Opacity(
          opacity: isSource ? 0.55 : 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: on
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.surfaceContainerHighest,
                      shape: BoxShape.circle),
                  child: Text(_codeBadge(l.code),
                      style: AppType.headline(
                          size: 12,
                          weight: FontWeight.w600,
                          color: on ? AppColors.primary : AppColors.onSurface)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.name,
                          style: AppType.body(size: 16, weight: FontWeight.w600)),
                      if (l.native.isNotEmpty)
                        Text(l.native,
                            style: AppType.body(size: 14, color: AppColors.tertiary)),
                    ],
                  ),
                ),
                if (isSource)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Text('SOURCE',
                        style: AppType.labelCaps(
                            size: 9, color: AppColors.onSurfaceVariant)),
                  )
                else if (on)
                  Icon(Symbols.check_circle,
                      size: 22, color: AppColors.primary, fill: 1)
                else
                  Icon(Symbols.radio_button_unchecked,
                      size: 22, color: AppColors.outlineVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Badge text for the leading circle — 'zh-CN' style codes shorten to fit.
  String _codeBadge(String code) {
    final base = code.split('-').first;
    return base.toUpperCase();
  }
}
