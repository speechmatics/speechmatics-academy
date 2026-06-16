import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

enum SpeechTab { home, upload, history, settings, none }

/// Bottom navigation shared across the four primary destinations.
/// Tapping a destination replaces the current route (matches the per-page
/// navigation in the HTML reference).
class SpeechBottomNav extends StatelessWidget {
  const SpeechBottomNav({super.key, required this.current});

  final SpeechTab current;

  static const _items = [
    (_NavItem(SpeechTab.home, Symbols.home, 'Home', Routes.home)),
    (_NavItem(SpeechTab.upload, Symbols.cloud_upload, 'Upload', Routes.upload)),
    (_NavItem(SpeechTab.history, Symbols.history, 'History', Routes.history)),
    (_NavItem(SpeechTab.settings, Symbols.settings, 'Settings', Routes.settings)),
  ];

  @override
  Widget build(BuildContext context) {
    final bar = ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xE6FFFFFF),
            border: Border(
              top: BorderSide(color: AppColors.outlineVariant, width: 1),
            ),
            boxShadow: [
              BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -2)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _items.map((it) => _tab(context, it)).toList(),
              ),
            ),
          ),
        ),
      ),
    );
    // Tab destinations REPLACE the route, so they are the only entry on the
    // navigator stack — without this, the system back gesture would minimize
    // the app. Intercept it and go Home instead. Home itself keeps the
    // default (back leaves the app), and pushed screens (none) pop normally.
    if (current == SpeechTab.home || current == SpeechTab.none) return bar;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pushReplacementNamed(Routes.home);
      },
      child: bar,
    );
  }

  Widget _tab(BuildContext context, _NavItem item) {
    final active = item.tab == current;
    final color = active ? AppColors.primary : AppColors.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: active
          ? null
          : () => Navigator.of(context).pushReplacementNamed(item.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 26, color: color, fill: active ? 1 : 0),
            const SizedBox(height: 4),
            Text(
              item.label.toUpperCase(),
              style: AppType.labelCaps(size: 10, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.tab, this.icon, this.label, this.route);
  final SpeechTab tab;
  final IconData icon;
  final String label;
  final String route;
}
