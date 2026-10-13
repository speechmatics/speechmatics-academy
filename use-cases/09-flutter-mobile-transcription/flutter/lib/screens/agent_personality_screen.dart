import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../models/agent_personality_templates.dart';
import '../state/settings_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_top_bar.dart';

/// Full-screen agent.md editor — markdown instructions defining the voice
/// agent's role, tone and rules. Saving applies when the next session starts.
class AgentPersonalityScreen extends StatefulWidget {
  const AgentPersonalityScreen({super.key});

  @override
  State<AgentPersonalityScreen> createState() => _AgentPersonalityScreenState();
}

class _AgentPersonalityScreenState extends State<AgentPersonalityScreen> {
  late final TextEditingController _md;
  late String _template; // template id the editor started from

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsStore>();
    _template = s.agentPersonalityTemplate == 'custom'
        ? 'custom'
        : s.agentPersonalityTemplate;
    _md = TextEditingController(text: s.agentPersonalityText)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _md.dispose();
    super.dispose();
  }

  void _loadTemplate(String id) {
    setState(() {
      _template = id;
      _md.text = AgentPersonalityTemplates.contentFor(id);
    });
  }

  void _save() {
    final s = context.read<SettingsStore>();
    // Text that drifted from its starter template is a custom personality.
    final effective = _template != 'custom' &&
            _md.text == AgentPersonalityTemplates.contentFor(_template)
        ? _template
        : 'custom';
    s.setAgentPersonality(effective, _md.text);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('PERSONALITY SAVED · NEXT SESSION'),
      duration: const Duration(seconds: 2),
    ));
    Navigator.pop(context);
  }

  void _reset() {
    final id = _template == 'custom' ? 'assistant' : _template;
    _loadTemplate(id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('RESET TO ${AgentPersonalityTemplates.displayName(id).toUpperCase()}'),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const BrandTopBar(leading: TopBarLeading.back),
      bottomNavigationBar: _actionBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Symbols.psychology,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Agent personality · agent.md',
                    style: AppType.headline(size: 14, weight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              Text(
                  "Markdown instructions that define the agent's role, tone and rules. Saving applies when your next Agent session starts.",
                  style: AppType.body(
                      size: 14, color: AppColors.primary, height: 1.45)),
              const SizedBox(height: 24),
              Text('STARTER TEMPLATES',
                  style: AppType.headline(size: 12, color: AppColors.tertiary)
                      .copyWith(letterSpacing: 2)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in AgentPersonalityTemplates.ids)
                    _templateChip(id),
                ],
              ),
              const SizedBox(height: 24),
              Text('INSTRUCTIONS',
                  style: AppType.headline(size: 12, color: AppColors.tertiary)
                      .copyWith(letterSpacing: 2)),
              const SizedBox(height: 8),
              Expanded(child: _editor()),
              const SizedBox(height: 10),
              Text(
                  'Headings and bullet lists work best — keep rules short and imperative. These instructions are sent when you start a session.',
                  style: AppType.body(
                      size: 12, color: AppColors.tertiary, height: 1.45)),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _templateChip(String id) {
    final on = _template == id &&
        _md.text == AgentPersonalityTemplates.contentFor(id);
    return InkWell(
      onTap: () => _loadTemplate(id),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppColors.primary : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: on ? AppColors.primary : AppColors.surfaceContainerHighest),
          boxShadow: on
              ? [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ]
              : null,
        ),
        child: Text(AgentPersonalityTemplates.displayName(id),
            style: AppType.headline(
                size: 12,
                weight: FontWeight.w600,
                color: on ? Colors.white : AppColors.onSurfaceVariant)),
      ),
    );
  }

  Widget _editor() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.technicalBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.technicalBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Symbols.description, size: 15, color: Color(0xFF6ADAB7)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('agent.md',
                  style: AppType.mono(
                          size: 11,
                          weight: FontWeight.w700,
                          color: const Color(0xFFFBFDFC))
                      .copyWith(letterSpacing: 1.4)),
            ),
            Text('${_md.text.length} CHARS',
                style: AppType.mono(
                        size: 10,
                        weight: FontWeight.w700,
                        color: const Color(0xFF7E8C86))
                    .copyWith(letterSpacing: 1.1)),
          ]),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppColors.technicalBorder),
          ),
          Expanded(
            child: TextField(
              controller: _md,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              cursorColor: const Color(0xFF6ADAB7),
              style: AppType.mono(size: 12.5, color: const Color(0xFFD9F5EC))
                  .copyWith(height: 1.6),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fixed bottom bar: outlined RESET + filled SAVE pill (design actionbar).
  Widget _actionBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF0F8FAF9),
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Row(children: [
            InkWell(
              onTap: _reset,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: AppColors.surfaceContainerHighest),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Symbols.restart_alt,
                      size: 17, color: AppColors.recordActive),
                  const SizedBox(width: 8),
                  Text('RESET',
                      style: AppType.labelCaps(
                          size: 11, color: AppColors.recordActive)),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: _save,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.28),
                          blurRadius: 20,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Symbols.check, size: 17, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('SAVE PERSONALITY',
                        style:
                            AppType.labelCaps(size: 11, color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
