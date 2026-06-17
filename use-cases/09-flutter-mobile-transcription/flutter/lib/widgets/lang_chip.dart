import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Tiny language-code chip, e.g. `EN`, tinted by the per-language accent.
class LangCodeChip extends StatelessWidget {
  const LangCodeChip(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.forLang(code);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        code.toUpperCase(),
        style: AppType.mono(size: 10, weight: FontWeight.w700, color: c, spacing: 0.2),
      ),
    );
  }
}

/// Rounded language pill, e.g. `English`, tinted by the per-language accent.
class LangPill extends StatelessWidget {
  const LangPill(this.label, {super.key, required this.code});

  final String label;
  final String code;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.forLang(code);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppType.body(size: 12, weight: FontWeight.w600, color: c),
      ),
    );
  }
}
