import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../models/lang_catalog.dart';
import '../state/settings_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_top_bar.dart';

class LanguageHintsScreen extends StatefulWidget {
  const LanguageHintsScreen({super.key});

  @override
  State<LanguageHintsScreen> createState() => _LanguageHintsScreenState();
}

class _LanguageHintsScreenState extends State<LanguageHintsScreen> {
  String _query = '';

  // Language hints are a Melia-1 (omni) feature — this screen is reachable
  // only from Omni Mode and always serves the omni catalog.
  List<LangInfo> _filtered(SettingsStore s) {
    if (_query.isEmpty) return LangCatalog.all;
    final q = _query.toLowerCase();
    return LangCatalog.all
        .where((l) =>
            l.name.toLowerCase().contains(q) ||
            l.native.toLowerCase().contains(q) ||
            l.code.toLowerCase().contains(q))
        .toList();
  }

  void _toggle(SettingsStore s, String code) {
    final set = s.languageHints.toSet();
    if (set.contains(code)) {
      set.remove(code);
    } else {
      set.add(code);
    }
    s.setLanguageHints(set.toList());
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsStore>();
    final filtered = _filtered(s);
    final selected = s.languageHints.toSet();
    final selectedLangs = LangCatalog.all.where((l) => selected.contains(l.code)).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const BrandTopBar(leading: TopBarLeading.back),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () =>
                      s.setLanguageHints(LangCatalog.all.map((l) => l.code).toList()),
                  child: Text('SELECT ALL',
                      style: AppType.body(size: 12, weight: FontWeight.w600, color: AppColors.primary)),
                ),
                TextButton(
                  onPressed: () => s.setLanguageHints(const []),
                  child: Text('CLEAR',
                      style: AppType.body(size: 12, weight: FontWeight.w600, color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _searchField(),
            const SizedBox(height: 12),
            Text('Bias Melia-1 toward these languages',
                style: AppType.body(size: 14, color: AppColors.primary, height: 1.4)),
            const SizedBox(height: 24),
            if (selectedLangs.isNotEmpty) ...[
              Text('SELECTED · ${selectedLangs.length}',
                  style: AppType.headline(size: 12, color: AppColors.tertiary).copyWith(letterSpacing: 2)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedLangs.map((l) => _selectedChip(s, l)).toList(),
              ),
              const SizedBox(height: 24),
            ],
            Text('ALL LANGUAGES',
                style: AppType.headline(size: 12, color: AppColors.tertiary).copyWith(letterSpacing: 2)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant),
                boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 20, offset: Offset(0, 4))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (int i = 0; i < filtered.length; i++)
                    _langRow(s, filtered[i], selected.contains(filtered[i].code),
                        last: i == filtered.length - 1),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Opacity(
              opacity: 0.7,
              child: Text(
                  '${LangCatalog.all.length} languages supported · leave empty to auto-detect',
                  textAlign: TextAlign.center,
                  style: AppType.body(size: 12, color: AppColors.tertiary)),
            ),
          ],
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

  Widget _selectedChip(SettingsStore s, LangInfo l) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(l.name, style: AppType.headline(size: 12, weight: FontWeight.w500, color: Colors.white)),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _toggle(s, l.code),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Symbols.close, size: 14, color: Colors.white),
          ),
        ),
      ]),
    );
  }

  Widget _langRow(SettingsStore s, LangInfo l, bool on, {required bool last}) {
    return Container(
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.surfaceContainerLow)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.surfaceContainerHighest, shape: BoxShape.circle),
              child: Text(l.code.toUpperCase(), style: AppType.headline(size: 13, weight: FontWeight.w600)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.name, style: AppType.body(size: 16, weight: FontWeight.w600)),
                  if (l.native.isNotEmpty)
                    Text(l.native, style: AppType.body(size: 14, color: AppColors.tertiary)),
                ],
              ),
            ),
            Switch(
              value: on,
              thumbColor: const WidgetStatePropertyAll(Colors.white),
              trackColor: WidgetStateProperty.resolveWith(
                  (st) => st.contains(WidgetState.selected) ? AppColors.primary : AppColors.surfaceContainerHighest),
              trackOutlineColor: WidgetStateProperty.resolveWith(
                  (st) => st.contains(WidgetState.selected) ? AppColors.primary : AppColors.surfaceContainerHighest),
              onChanged: (_) => _toggle(s, l.code),
            ),
          ],
        ),
      ),
    );
  }
}
