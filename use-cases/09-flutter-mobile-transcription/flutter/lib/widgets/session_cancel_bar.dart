import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The bottom bar while a capture/live session is running. Mirrors
/// SpeechBottomNav's chrome (same blur, border, padding) so swapping the two
/// doesn't change the bar height mid-session; the action itself is a
/// contained orange pill so a stray tab-tap can't land anywhere destructive.
class SessionCancelBar extends StatelessWidget {
  const SessionCancelBar(
      {super.key, required this.label, required this.onCancel});

  final String label;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xE6FFFFFF),
            border: Border(
              top: BorderSide(color: AppColors.outlineVariant, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 16,
                  offset: Offset(0, -2)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              // heightFactor pins the bar to the pill's height — a plain
              // Center would expand into all the height the scaffold offers
              // its bottom bar (i.e. the whole screen).
              child: Center(
                heightFactor: 1,
                child: InkWell(
                  onTap: onCancel,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    // Fixed height + no `alignment:` — an aligned Container
                    // EXPANDS to its incoming constraints, and the scaffold
                    // offers its bottom bar the whole screen (emulator-
                    // verified full-screen pill). The Row centers content
                    // across the 220 minimum width instead.
                    constraints: const BoxConstraints(minWidth: 220),
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: AppColors.recordActive.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color:
                              AppColors.recordActive.withValues(alpha: 0.45)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.recordActive.withValues(alpha: 0.14),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Symbols.close,
                            size: 18, color: AppColors.recordActive),
                        const SizedBox(width: 8),
                        Text(label,
                            style: AppType.labelCaps(
                                size: 10, color: AppColors.recordActive)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
