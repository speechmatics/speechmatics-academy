import 'package:flutter/material.dart';

/// Speechmatics Translate brand palette (jade-led, light/bright).
/// Distilled from the 8 Lovable reference screens into one coherent token set.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF29A383); // jade
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFD9F5EC); // mint highlight
  static const Color recordActive = Color(0xFFFF5212); // recording orange

  // Surfaces
  static const Color background = Color(0xFFF8FAF9); // sage
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F4);
  static const Color surfaceContainerLow = Color(0xFFF2F4F3);
  static const Color surfaceContainerHigh = Color(0xFFE6E9E8);
  static const Color surfaceContainerHighest = Color(0xFFE1E3E2);

  // Text / lines
  static const Color onSurface = Color(0xFF1A1C1B);
  static const Color onSurfaceVariant = Color(0xFF5F6B66);
  static const Color tertiary = Color(0xFF8A938E); // faint labels
  static const Color outline = Color(0xFF6D7A74);
  static const Color outlineVariant = Color(0xFFE2E3E1);

  // Dark "live config" panel (settings)
  static const Color technicalBg = Color(0xFF0D3C48);
  static const Color technicalBorder = Color(0xFF16505E);

  // Accents (warnings, status)
  static const Color amber = Color(0xFFD97706);
  static const Color warningAmber = Color(0xFFFFC53D);
  static const Color cyan = Color(0xFF0891B2);
  static const Color violet = Color(0xFF7C3AED);
  static const Color error = Color(0xFFBA1A1A);

  // Per-language chip colors (EN/ES/AR/FR/JA/DE …)
  static const Map<String, Color> langColor = {
    'EN': primary,
    'ES': amber,
    'AR': cyan,
    'FR': violet,
    'JA': cyan,
    'DE': amber,
    'RU': violet,
    'LV': primary,
  };

  static Color forLang(String code) =>
      langColor[code.toUpperCase()] ?? onSurfaceVariant;
}
