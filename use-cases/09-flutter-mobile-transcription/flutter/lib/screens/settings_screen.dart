import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../data/api_keys.dart';
import '../data/config_mapper.dart';
import '../models/classic_lang_catalog.dart';
import '../models/lang_catalog.dart';
import '../models/speaker_profile.dart';
import '../routes.dart';
import '../state/settings_store.dart';
import '../state/speaker_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_top_bar.dart';
import '../widgets/segmented_toggle.dart';
import '../widgets/speech_bottom_nav.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeys = ApiKeys();
  final _smKeyController = TextEditingController();
  final _googleKeyController = TextEditingController();
  bool _smSaved = false;
  bool _googleSaved = false;
  // Saved keys collapse to a compact row; these expand them for replacement.
  bool _smEditing = false;
  bool _googleEditing = false;

  // Seeded once so per-keystroke store writes don't reset the cursor.
  late final TextEditingController _dictController;
  late final TextEditingController _topicsController;

  @override
  void initState() {
    super.initState();
    final store = context.read<SettingsStore>();
    _dictController = TextEditingController(text: store.customDictText);
    _topicsController = TextEditingController(text: store.topicsText);
    _apiKeys.hasStoredSpeechmatics().then((v) {
      if (mounted) setState(() => _smSaved = v);
    });
    _apiKeys.hasStoredGoogle().then((v) {
      if (mounted) setState(() => _googleSaved = v);
    });
  }

  @override
  void dispose() {
    _smKeyController.dispose();
    _googleKeyController.dispose();
    _dictController.dispose();
    _topicsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsStore>();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const BrandTopBar(),
      bottomNavigationBar: const SpeechBottomNav(current: SpeechTab.settings),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text('Settings',
                style: AppType.display(size: 24, weight: FontWeight.w600, color: const Color(0xFF0D3C48))),
            const SizedBox(height: 24),
            _label('PROCESSING MODE'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedToggle<String>(
                value: s.mode,
                onChanged: s.setMode,
                // Real-Time isn't implemented yet — visible but locked.
                disabled: const {'realtime'},
                items: const [SegItem('batch', 'Batch'), SegItem('realtime', 'Real-Time')],
                segHPad: 20,
                segVPad: 8,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('Real-Time transcription is coming soon.',
                  style: AppType.body(size: 12, color: AppColors.tertiary)),
            ),
            const SizedBox(height: 24),
            if (s.mode == 'batch') ..._batch(context, s) else _realtime(),
          ],
        ),
      ),
    );
  }

  // ---------- Batch settings ----------
  List<Widget> _batch(BuildContext context, SettingsStore s) => [
        _apiKeysSection(s),
        const SizedBox(height: 24),
        _speakersSection(context, s),
        const SizedBox(height: 24),
        _domainSection(s),
        const SizedBox(height: 24),
        _label('MODEL'),
        const SizedBox(height: 12),
        _modelCard(s),
        const SizedBox(height: 24),
        _label('LANGUAGE'),
        const SizedBox(height: 12),
        _plainCard(
          child: s.isClassic ? _classicLanguageBody(context, s) : _omniLanguageBody(context, s),
        ),
        const SizedBox(height: 24),
        _toggleSection(
          title: 'DIARIZATION',
          label: 'Enable diarization',
          value: s.diarization,
          onChanged: s.setDiarization,
          sub: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select how to separate speech in the audio.',
                  style: AppType.body(size: 13, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: SegmentedToggle<String>(
                  value: s.diarizationType,
                  onChanged: s.setDiarizationType,
                  expand: true,
                  radius: 10,
                  fontSize: 14,
                  items: const [SegItem('speaker', 'Speakers'), SegItem('channel', 'Channels')],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (s.isClassic) _customDictSection(s) else _lockedSection('CUSTOM DICTIONARY', 'Enable custom dictionary'),
        const SizedBox(height: 24),
        _toggleSection(
          title: 'TRANSLATION',
          label: 'Enable translation (Google)',
          value: s.translation,
          onChanged: s.setTranslation,
          sub: _rowPicker(
            title: 'Translate to',
            value: s.targetLanguageName,
            onTap: () => _pickLanguage(context, (l) => s.setTarget(l.code, l.name)),
          ),
        ),
        const SizedBox(height: 24),
        if (s.isClassic) _audioFilteringSection(s) else _lockedSection('AUDIO FILTERING', 'Enable audio filtering'),
        const SizedBox(height: 24),
        if (s.isClassic)
          _punctuationSection(s)
        else
          _infoSection('PUNCTUATION', 'Automatic', 'Melia-1 adds punctuation automatically (not configurable).'),
        const SizedBox(height: 24),
        if (s.isClassic)
          _subtitleSection(s)
        else
          _lockedSection('SUBTITLE FORMAT', 'Enable subtitle formatting', note: _siNote(s)),
        const SizedBox(height: 24),
        if (s.isClassic)
          _summarySection(s)
        else
          _lockedSection('SUMMARY', 'Enable summary', note: _siNote(s)),
        const SizedBox(height: 24),
        if (s.isClassic)
          _topicsSection(s)
        else
          _lockedSection('TOPICS', 'Enable topics', note: _siNote(s)),
        const SizedBox(height: 24),
        if (s.isClassic)
          _chaptersSection(s)
        else
          _lockedSection('CHAPTERS', 'Enable chapters', note: _siNote(s)),
        const SizedBox(height: 24),
        if (s.isClassic) _audioEventsSection(s) else _lockedSection('AUDIO EVENTS', 'Enable audio events'),
        const SizedBox(height: 24),
        _label('LIVE CONFIG PREVIEW'),
        const SizedBox(height: 12),
        _configPreview(s),
      ];

  // ---------- language ----------
  /// Melia-1 is always omnilingual — Classic Mode is shown but disabled
  /// (it belongs to the Standard/Enhanced models).
  Widget _omniLanguageBody(BuildContext context, SettingsStore s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedToggle<String>(
          value: 'omnilingual',
          onChanged: (_) {},
          expand: true,
          radius: 10,
          segVPad: 8,
          fontSize: 14,
          disabled: const {'single'},
          items: const [
            SegItem('omnilingual', 'Omni Mode'),
            SegItem('single', 'Classic Mode'),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        Row(children: [
          Icon(Symbols.network_intelligence, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Omni Mode detects every spoken language (model: omni-v1)',
                style: AppType.body(size: 13, color: AppColors.onSurfaceVariant)),
          ),
        ]),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        _hintsRow(context, s),
        if (s.languageHints.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _strictRow(s),
        ],
      ],
    );
  }

  /// Classic (Standard/Enhanced): Auto-detect (language identification, with
  /// optional expected-language hints) vs Classic Mode (a specific language /
  /// bilingual pack from the classic catalog).
  Widget _classicLanguageBody(BuildContext context, SettingsStore s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedToggle<String>(
          value: s.classicLanguageMode,
          onChanged: s.setClassicLanguageMode,
          expand: true,
          radius: 10,
          segVPad: 8,
          fontSize: 14,
          items: const [
            SegItem('auto', 'Auto-detect'),
            SegItem('specific', 'Classic Mode'),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        if (s.classicLanguageMode == 'auto')
          // No language hints here — hints are a Melia-1 (omni) feature.
          Row(children: [
            Icon(Symbols.travel_explore, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text('The language is identified automatically (language: auto)',
                  style: AppType.body(size: 13, color: AppColors.onSurfaceVariant)),
            ),
          ])
        else
          _rowPicker(
            title: 'Language',
            value: ClassicLangCatalog.nameFor(s.classicLanguage),
            onTap: () => _pickClassicLanguage(context, s),
          ),
      ],
    );
  }

  /// Same panel design as the Melia-1 picker, with the classic catalog
  /// (one alphabetical list; bilingual packs included where they sort).
  Future<void> _pickClassicLanguage(BuildContext context, SettingsStore s) async {
    final entries = [...ClassicLangCatalog.all]..sort((a, b) => a.name.compareTo(b.name));
    final picked = await showModalBottomSheet<ClassicLangInfo>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Choose a language', style: AppType.headline(size: 18)),
            ),
            for (final l in entries)
              ListTile(
                title: Text(l.name, style: AppType.body(size: 16)),
                subtitle: _classicSubtitle(l),
                trailing: Text(l.id.toUpperCase(),
                    style: AppType.mono(size: 12, color: AppColors.onSurfaceVariant)),
                onTap: () => Navigator.pop(ctx, l),
              ),
          ],
        ),
      ),
    );
    if (picked != null) s.setClassicLanguage(picked.id);
  }

  /// Native name where the omni catalog knows it; packs marked as such.
  Widget? _classicSubtitle(ClassicLangInfo l) {
    if (l.bilingual) {
      return Text('Bilingual pack', style: AppType.body(size: 13, color: AppColors.tertiary));
    }
    final native = LangCatalog.info(l.id)?.native;
    if (native == null || native.isEmpty) return null;
    return Text(native, style: AppType.body(size: 13, color: AppColors.tertiary));
  }

  // ---------- speakers (identification) ----------
  /// Enrolled voices for batch speaker identification (probe-verified
  /// 2026-06-12): the profile name doubles as the transcript label. Matching
  /// works on the classic models (omni-v1 accepts the block but ignores it).
  Widget _speakersSection(BuildContext context, SettingsStore s) {
    final store = context.watch<SpeakerStore>();
    final profiles = store.profiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('SPEAKERS'),
        const SizedBox(height: 12),
        _plainCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (profiles.isEmpty)
                Text(
                    'No speakers enrolled yet. Enrol a voice once and it will be '
                    'recognized by name in future transcriptions.',
                    style: AppType.body(size: 13, color: AppColors.onSurfaceVariant))
              else ...[
                for (var i = 0; i < profiles.length; i++) ...[
                  if (i > 0) const Divider(height: 16),
                  _speakerRow(context, profiles[i]),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Identify enrolled speakers',
                            style: AppType.body(size: 15, weight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                            'Matched voices are labelled by name in new transcriptions '
                            '(classic models — best with Enhanced).',
                            style: AppType.body(size: 12, color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  _switch(s.speakerIdentification, s.setSpeakerIdentification),
                ]),
                if (s.speakerIdentification) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Matching sensitivity',
                            style: AppType.body(size: 13, color: AppColors.onSurfaceVariant)),
                      ),
                      Text(s.speakerSensitivity.toStringAsFixed(1),
                          style: AppType.mono(size: 12, color: AppColors.primary)),
                    ],
                  ),
                  Slider(
                    value: s.speakerSensitivity.clamp(0.0, 1.0),
                    min: 0,
                    max: 1,
                    divisions: 10,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.surfaceContainerHighest,
                    onChanged: s.setSpeakerSensitivity,
                  ),
                  Text(
                      'Lower values make it more likely to match enrolled speakers; '
                      'higher values favour detecting new, generic speakers. Default 0.5.',
                      style: AppType.body(size: 12, color: AppColors.onSurfaceVariant)),
                ],
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pushNamed(context, Routes.enroll),
                  icon: const Icon(Symbols.person_add, size: 18, color: Colors.white),
                  label: Text('Enrol speaker',
                      style: AppType.body(size: 14, weight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _speakerRow(BuildContext context, SpeakerProfile p) {
    Widget btn(IconData icon, Color color, String tooltip, VoidCallback onTap) => IconButton(
          onPressed: onTap,
          tooltip: tooltip,
          icon: Icon(icon, size: 18, color: color),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.all(6),
          ),
        );
    final date = p.enrolledAt != null ? DateFormat('d MMM yyyy').format(p.enrolledAt!) : null;
    return Row(children: [
      Container(
        width: 36,
        height: 36,
        decoration:
            const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
        child: Icon(Symbols.person, size: 20, fill: 1, color: AppColors.primary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.body(size: 15, weight: FontWeight.w600)),
            if (date != null)
              Text('Enrolled $date', style: AppType.body(size: 12, color: AppColors.tertiary)),
          ],
        ),
      ),
      btn(Symbols.edit, AppColors.primary, 'Rename', () => _renameSpeaker(context, p)),
      btn(Symbols.delete, AppColors.error, 'Remove', () => _confirmDeleteSpeaker(context, p)),
    ]);
  }

  Future<void> _renameSpeaker(BuildContext context, SpeakerProfile p) async {
    final controller = TextEditingController(text: p.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename speaker'),
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
    if (result != null && result.isNotEmpty && context.mounted) {
      context.read<SpeakerStore>().rename(p.id, result);
    }
  }

  Future<void> _confirmDeleteSpeaker(BuildContext context, SpeakerProfile p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${p.name}?'),
        content: const Text('Their voice will no longer be identified in new transcriptions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<SpeakerStore>().delete(p.id);
    }
  }

  // ---------- domain ----------
  /// Domain language packs (probe-verified 2026-06-12): medical / finance,
  /// Enhanced only, and they need a specific language (Classic Mode) —
  /// `language: auto` + domain is rejected by the API. Locked on Standard;
  /// locked on Melia-1 with a "coming soon" note (per Speechmatics roadmap).
  Widget _domainSection(SettingsStore s) {
    const items = [
      SegItem('none', 'None'),
      SegItem('medical', 'Medical'),
      SegItem('finance', 'Finance'),
    ];

    if (s.model != 'enhanced') {
      final note = s.isClassic
          ? 'Not available with Standard — requires the Enhanced model.'
          : 'Coming to Melia-1 soon — available with Enhanced today.';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _label('DOMAIN'),
            const SizedBox(width: 8),
            Icon(Symbols.lock, size: 18, color: AppColors.warningAmber),
          ]),
          const SizedBox(height: 12),
          Opacity(
            opacity: 0.7,
            child: _plainCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedToggle<String>(
                    value: 'none',
                    onChanged: (_) {},
                    expand: true,
                    radius: 10,
                    segVPad: 8,
                    fontSize: 14,
                    disabled: const {'none', 'medical', 'finance'},
                    items: items,
                  ),
                  const SizedBox(height: 12),
                  Text(note, style: AppType.body(size: 12, color: AppColors.warningAmber)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final needsLanguage = s.domain != 'none' && s.classicLanguageMode == 'auto';
    final caption = s.domain == 'none'
        ? 'Domain language packs tune Enhanced for specialised vocabulary.'
        : needsLanguage
            ? 'Domains need a specific language — set LANGUAGE to Classic Mode to apply.'
            : 'The ${s.domain} pack is applied to the selected language.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('DOMAIN'),
        const SizedBox(height: 12),
        _plainCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedToggle<String>(
                value: s.domain,
                onChanged: s.setDomain,
                expand: true,
                radius: 10,
                segVPad: 8,
                fontSize: 14,
                items: items,
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(children: [
                Icon(needsLanguage ? Symbols.warning : Symbols.domain,
                    size: 16,
                    color: needsLanguage ? AppColors.warningAmber : AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(caption,
                      style: AppType.body(
                          size: 13,
                          color: needsLanguage
                              ? AppColors.warningAmber
                              : AppColors.onSurfaceVariant)),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- model ----------
  Widget _modelCard(SettingsStore s) {
    final (badge, desc) = switch (s.model) {
      'standard' => ('FAST', 'Classic engine with the fastest turnaround.'),
      'enhanced' => ('HIGH ACCURACY', 'Classic engine with the highest accuracy.'),
      _ => ('NEXT-GEN', 'Omnilingual next-gen model — detects every language spoken.'),
    };
    return _plainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedToggle<String>(
            value: s.model,
            onChanged: s.setModel,
            expand: true,
            radius: 10,
            segHPad: 4,
            segVPad: 8,
            fontSize: 14,
            items: const [
              SegItem('omni-v1', 'Melia-1'),
              SegItem('enhanced', 'Enhanced'),
              SegItem('standard', 'Standard'),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Symbols.info, size: 16, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(desc, style: AppType.body(size: 13, color: AppColors.onSurfaceVariant)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(4)),
                child: Text(badge,
                    style: AppType.body(size: 10, weight: FontWeight.w700, color: AppColors.primary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- classic-only sections (standard/enhanced models) ----------
  String _siNote(SettingsStore s) => 'Not available with Melia-1';

  Widget _subtitleSection(SettingsStore s) {
    return _toggleSection(
      title: 'SUBTITLE FORMAT',
      label: 'Enable subtitle formatting',
      value: s.subtitles,
      onChanged: s.setSubtitles,
      sub: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Generates SRT subtitles you can copy or share from the result.',
              style: AppType.body(size: 13, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Max line length', style: AppType.body(size: 13, color: AppColors.onSurfaceVariant)),
              const Spacer(),
              Text('${s.subtitleMaxLineLength.round()}',
                  style: AppType.mono(size: 12, color: AppColors.primary)),
            ],
          ),
          Slider(
            value: s.subtitleMaxLineLength.clamp(28, 46),
            min: 28,
            max: 46,
            divisions: 18,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.surfaceContainerHighest,
            onChanged: s.setSubtitleMaxLineLength,
          ),
          const SizedBox(height: 4),
          Text('Max lines per cue', style: AppType.body(size: 13, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: SegmentedToggle<int>(
              value: s.subtitleMaxLines,
              onChanged: s.setSubtitleMaxLines,
              expand: true,
              radius: 10,
              fontSize: 14,
              items: const [SegItem(1, '1'), SegItem(2, '2'), SegItem(3, '3')],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summarySection(SettingsStore s) {
    return _toggleSection(
      title: 'SUMMARY',
      label: 'Enable summary',
      value: s.summary,
      onChanged: s.setSummary,
      sub: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Style', style: AppType.body(size: 13, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: SegmentedToggle<String>(
              value: s.summaryType,
              onChanged: s.setSummaryType,
              expand: true,
              radius: 10,
              fontSize: 14,
              items: const [SegItem('bullets', 'Bullets'), SegItem('paragraphs', 'Paragraphs')],
            ),
          ),
          const SizedBox(height: 12),
          Text('Length', style: AppType.body(size: 13, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: SegmentedToggle<String>(
              value: s.summaryLength,
              onChanged: s.setSummaryLength,
              expand: true,
              radius: 10,
              fontSize: 14,
              items: const [SegItem('brief', 'Brief'), SegItem('detailed', 'Detailed')],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topicsSection(SettingsStore s) {
    final seeds = ConfigMapper.parseTopics(s.topicsText).length;
    return _toggleSection(
      title: 'TOPICS',
      label: 'Enable topic detection',
      value: s.topics,
      onChanged: s.setTopics,
      sub: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Optional seed topics (comma separated). Leave empty for automatic detection.',
              style: AppType.body(size: 13, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 12),
          TextField(
            controller: _topicsController,
            style: AppType.body(size: 14),
            decoration: _inputDecoration('cooking, space travel, finance'),
            onChanged: s.setTopicsText,
          ),
          const SizedBox(height: 8),
          Text(seeds == 0 ? 'Automatic' : (seeds == 1 ? '1 seed topic' : '$seeds seed topics'),
              style: AppType.body(size: 12, color: AppColors.tertiary)),
        ],
      ),
    );
  }

  Widget _chaptersSection(SettingsStore s) {
    return _toggleSection(
      title: 'CHAPTERS',
      label: 'Enable chapters',
      value: s.chapters,
      onChanged: s.setChapters,
      sub: Text(
          'Splits the recording into titled chapters with summaries — tap a chapter in the result to jump there.',
          style: AppType.body(size: 13, color: AppColors.onSurfaceVariant)),
    );
  }

  Widget _customDictSection(SettingsStore s) {
    final entries = ConfigMapper.parseVocab(s.customDictText).length;
    return _toggleSection(
      title: 'CUSTOM DICTIONARY',
      label: 'Enable custom dictionary',
      value: s.customDict,
      onChanged: s.setCustomDict,
      sub: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('One entry per comma. Add pronunciations in parentheses:\n'
              'gnocchi (nyohki, nochi), CEO (C.E.O.), Speechmatics',
              style: AppType.body(size: 13, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 12),
          TextField(
            controller: _dictController,
            maxLines: 3,
            style: AppType.body(size: 14),
            decoration: _inputDecoration('gnocchi (nyohki), CEO (C.E.O.)'),
            onChanged: s.setCustomDictText,
          ),
          const SizedBox(height: 8),
          Text(entries == 1 ? '1 entry' : '$entries entries',
              style: AppType.body(size: 12, color: AppColors.tertiary)),
        ],
      ),
    );
  }

  Widget _punctuationSection(SettingsStore s) {
    const markLabels = [
      ('comma', ','),
      ('period', '.'),
      ('question_mark', '?'),
      ('exclamation_mark', '!'),
    ];
    return _toggleSection(
      title: 'PUNCTUATION',
      label: 'Customize punctuation',
      value: s.punctuation,
      onChanged: s.setPunctuation,
      sub: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Permitted marks', style: AppType.body(size: 13, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final (id, symbol) in markLabels)
                FilterChip(
                  label: Text(symbol,
                      style: AppType.mono(size: 14, weight: FontWeight.w700,
                          color: s.marks.contains(id) ? AppColors.primary : AppColors.onSurfaceVariant)),
                  selected: s.marks.contains(id),
                  onSelected: (_) => s.toggleMark(id),
                  selectedColor: AppColors.primaryContainer,
                  checkmarkColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceVariant,
                  side: const BorderSide(color: AppColors.outlineVariant),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Sensitivity', style: AppType.body(size: 13, color: AppColors.onSurfaceVariant)),
              const Spacer(),
              Text(s.sensitivity.toStringAsFixed(1),
                  style: AppType.mono(size: 12, color: AppColors.primary)),
            ],
          ),
          Slider(
            value: s.sensitivity,
            min: 0,
            max: 1,
            divisions: 10,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.surfaceContainerHighest,
            onChanged: s.setSensitivity,
          ),
        ],
      ),
    );
  }

  Widget _audioFilteringSection(SettingsStore s) {
    return _toggleSection(
      title: 'AUDIO FILTERING',
      label: 'Enable audio filtering',
      value: s.audioFiltering,
      onChanged: s.setAudioFiltering,
      sub: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    'Filter out quiet background audio below the threshold. '
                    'Typical: 1–5 — high values can remove speech entirely.',
                    style: AppType.body(size: 13, color: AppColors.onSurfaceVariant)),
              ),
              const SizedBox(width: 8),
              Text('${s.volume.round()}',
                  style: AppType.mono(size: 12, color: AppColors.primary)),
            ],
          ),
          Slider(
            value: s.volume.clamp(0, 20),
            min: 0,
            max: 20,
            divisions: 20,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.surfaceContainerHighest,
            onChanged: s.setVolume,
          ),
        ],
      ),
    );
  }

  Widget _audioEventsSection(SettingsStore s) {
    const types = ['laughter', 'music', 'applause'];
    return _toggleSection(
      title: 'AUDIO EVENTS',
      label: 'Enable audio events',
      value: s.audioEvents,
      onChanged: s.setAudioEvents,
      sub: Wrap(
        spacing: 8,
        children: [
          for (final t in types)
            FilterChip(
              label: Text(t,
                  style: AppType.body(size: 13, weight: FontWeight.w600,
                      color: s.events.contains(t) ? AppColors.primary : AppColors.onSurfaceVariant)),
              selected: s.events.contains(t),
              onSelected: (_) => s.toggleEvent(t),
              selectedColor: AppColors.primaryContainer,
              checkmarkColor: AppColors.primary,
              backgroundColor: AppColors.surfaceVariant,
              side: const BorderSide(color: AppColors.outlineVariant),
            ),
        ],
      ),
    );
  }

  // ---------- API keys ----------
  Widget _apiKeysSection(SettingsStore s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('API ACCESS'),
        const SizedBox(height: 12),
        _plainCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Region', style: AppType.body(size: 15, weight: FontWeight.w500)),
              const SizedBox(height: 8),
              SegmentedToggle<String>(
                value: s.region,
                onChanged: s.setRegion,
                radius: 10,
                fontSize: 13,
                items: const [SegItem('eu1', 'EU'), SegItem('us1', 'US')],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _keyField(
                label: 'Speechmatics API key',
                controller: _smKeyController,
                saved: _smSaved,
                editing: _smEditing,
                onEdit: () => setState(() => _smEditing = true),
                onCancel: () => setState(() {
                  _smEditing = false;
                  _smKeyController.clear();
                }),
                onSave: (v) async {
                  await _apiKeys.setSpeechmatics(v);
                  if (mounted) {
                    setState(() {
                      _smSaved = true;
                      _smEditing = false;
                    });
                  }
                  _smKeyController.clear();
                },
              ),
              const SizedBox(height: 16),
              _keyField(
                label: 'Google Translate API key',
                controller: _googleKeyController,
                saved: _googleSaved,
                editing: _googleEditing,
                onEdit: () => setState(() => _googleEditing = true),
                onCancel: () => setState(() {
                  _googleEditing = false;
                  _googleKeyController.clear();
                }),
                onSave: (v) async {
                  await _apiKeys.setGoogle(v);
                  if (mounted) {
                    setState(() {
                      _googleSaved = true;
                      _googleEditing = false;
                    });
                  }
                  _googleKeyController.clear();
                },
              ),
              const SizedBox(height: 8),
              Text('Keys are stored securely on this device.',
                  style: AppType.body(size: 12, color: AppColors.tertiary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _keyField({
    required String label,
    required TextEditingController controller,
    required bool saved,
    required bool editing,
    required VoidCallback onEdit,
    required VoidCallback onCancel,
    required Future<void> Function(String) onSave,
  }) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
          color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(4)),
      child: Text('SAVED',
          style: AppType.body(size: 9, weight: FontWeight.w700, color: AppColors.primary)),
    );

    // Saved keys collapse to a compact row; "Replace" expands the editor.
    if (saved && !editing) {
      return Row(
        children: [
          Expanded(child: Text(label, style: AppType.body(size: 14, weight: FontWeight.w500))),
          Text('••••••••', style: AppType.mono(size: 13, color: AppColors.onSurfaceVariant)),
          const SizedBox(width: 8),
          badge,
          IconButton(
            onPressed: onEdit,
            tooltip: 'Replace key',
            icon: Icon(Symbols.edit, size: 18, color: AppColors.primary),
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.all(6),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppType.body(size: 14, weight: FontWeight.w500)),
            const SizedBox(width: 8),
            if (saved) badge,
            const Spacer(),
            if (saved && editing)
              IconButton(
                onPressed: onCancel,
                tooltip: 'Cancel',
                icon: Icon(Symbols.close, size: 18, color: AppColors.onSurfaceVariant),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.all(6),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: true,
              style: AppType.mono(size: 13, color: AppColors.onSurface),
              decoration: _inputDecoration(saved ? 'Enter new key to replace' : 'Paste key'),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) onSave(v);
            },
            child: const Text('Save'),
          ),
        ]),
      ],
    );
  }

  // ---------- language hints + pickers ----------
  Widget _hintsRow(BuildContext context, SettingsStore s) {
    final names = s.languageHints.map(LangCatalog.nameFor).toList();
    return InkWell(
      onTap: () => Navigator.pushNamed(context, Routes.hints),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Language hints (optional)',
                    style: AppType.body(size: 16, weight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('Bias detection toward these languages',
                    style: AppType.body(size: 13, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text('${names.length}',
                          style: AppType.body(size: 12, weight: FontWeight.w700, color: AppColors.primary)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(names.isEmpty ? 'Auto-detect' : names.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body(size: 13, color: AppColors.tertiary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Symbols.chevron_right, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _strictRow(SettingsStore s) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Strict language hints',
                  style: AppType.body(size: 16, weight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('Constrain output to ONLY the languages above (no auto-detect drift).',
                  style: AppType.body(size: 13, color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _switch(s.languageHintsStrict, s.setLanguageHintsStrict),
      ],
    );
  }

  Widget _rowPicker({required String title, required String value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Text(title, style: AppType.body(size: 15, weight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: AppType.body(size: 15, weight: FontWeight.w500, color: AppColors.primary)),
          Icon(Symbols.chevron_right, color: AppColors.primary),
        ],
      ),
    );
  }

  Future<void> _pickLanguage(BuildContext context, void Function(LangInfo) onPicked) async {
    final picked = await showModalBottomSheet<LangInfo>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Choose a language', style: AppType.headline(size: 18)),
            ),
            for (final l in LangCatalog.all)
              ListTile(
                title: Text(l.name, style: AppType.body(size: 16)),
                subtitle: Text(l.native, style: AppType.body(size: 13, color: AppColors.tertiary)),
                trailing: Text(l.code.toUpperCase(),
                    style: AppType.mono(size: 12, color: AppColors.onSurfaceVariant)),
                onTap: () => Navigator.pop(ctx, l),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onPicked(picked);
  }

  // ---------- Real-Time ----------
  Widget _realtime() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [BoxShadow(color: Color(0x0F0D3C48), blurRadius: 20, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
                child: const Text('🚀', style: TextStyle(fontSize: 40)),
              ),
              Positioned(
                top: -4,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.warningAmber, borderRadius: BorderRadius.circular(999)),
                  child: Text('Coming Soon',
                      style: AppType.body(size: 10, weight: FontWeight.w700, color: const Color(0xFF0D3C48))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Real-Time Transcription',
              style: AppType.headline(size: 20, color: const Color(0xFF0D3C48))),
          const SizedBox(height: 8),
          Text(
            'Real-time transcription is currently in development and will be available in a future release.',
            textAlign: TextAlign.center,
            style: AppType.body(size: 14, color: AppColors.onSurfaceVariant, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ---------- building blocks ----------
  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(t,
            style: AppType.headline(size: 14, weight: FontWeight.w500, color: AppColors.outline)
                .copyWith(letterSpacing: 1.0)),
      );

  Widget _plainCard({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEBF0F1)),
          boxShadow: const [BoxShadow(color: Color(0x0D0D3C48), blurRadius: 20, offset: Offset(0, 4))],
        ),
        child: child,
      );

  /// A non-interactive section showing a fixed status (e.g. Punctuation = Automatic).
  Widget _infoSection(String title, String value, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(title),
        const SizedBox(height: 12),
        _plainCard(
          child: Row(
            children: [
              Expanded(
                child: Text(desc,
                    style: AppType.body(size: 14, color: AppColors.onSurfaceVariant)),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(999)),
                child: Text(value,
                    style: AppType.body(size: 12, weight: FontWeight.w700, color: AppColors.primary)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toggleSection({
    required String title,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? sub,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(title),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEBF0F1)),
            boxShadow: const [BoxShadow(color: Color(0x0D0D3C48), blurRadius: 20, offset: Offset(0, 4))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(child: Text(label, style: AppType.body(size: 15, weight: FontWeight.w500))),
                    _switch(value, onChanged),
                  ],
                ),
              ),
              if (sub != null && value)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.surfaceContainerHighest)),
                  ),
                  child: sub,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lockedSection(String title, String label, {String note = 'Not available with Melia-1'}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _label(title),
          const SizedBox(width: 8),
          Icon(Symbols.lock, size: 18, color: AppColors.warningAmber),
        ]),
        const SizedBox(height: 12),
        Opacity(
          opacity: 0.7,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEBF0F1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(child: Text(label, style: AppType.body(size: 15, weight: FontWeight.w500))),
                    _switch(false, null),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(note,
                      style: AppType.body(size: 12, color: AppColors.warningAmber)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _switch(bool value, ValueChanged<bool>? onChanged) {
    return Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.surfaceContainerHighest),
      trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.surfaceContainerHighest),
    );
  }

  Widget _configPreview(SettingsStore s) {
    final json = const JsonEncoder.withIndent('  ').convert(ConfigMapper.build(s.snapshot()));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.technicalBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.technicalBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('transcription_config',
                style: AppType.mono(size: 14, color: const Color(0xFFFBFDFC))),
            const Spacer(),
            const Icon(Symbols.bolt, size: 16, color: Color(0xFF6ADAB7)),
          ]),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: AppColors.technicalBorder),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(json,
                style: AppType.mono(size: 12, color: const Color(0xFFD9F5EC), weight: FontWeight.w400)
                    .copyWith(height: 1.5)),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Symbols.translate, size: 14, color: Color(0xFFA3CDDC)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  s.translation
                      ? 'Google Translate → ${s.targetLanguageName} (post-transcription)'
                      : 'Translation off',
                  style: AppType.body(size: 12, color: const Color(0xFFA3CDDC))),
            ),
          ]),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
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
      );
}
