import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Brand typography helpers + the app [ThemeData].
///
/// Space Grotesk = display / headlines, DM Sans = body / labels,
/// JetBrains Mono = the `melia-1` pill, timers and the live-config JSON.
class AppType {
  AppType._();

  static TextStyle display(
          {double size = 32, FontWeight weight = FontWeight.w700, Color? color}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        height: 1.1,
        letterSpacing: -0.01 * size,
        color: color ?? AppColors.onSurface,
      );

  static TextStyle headline(
          {double size = 20, FontWeight weight = FontWeight.w600, Color? color}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.onSurface,
      );

  static TextStyle body(
          {double size = 16, FontWeight weight = FontWeight.w400, Color? color, double? height}) =>
      GoogleFonts.dmSans(
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color ?? AppColors.onSurface,
      );

  static TextStyle mono(
          {double size = 12, FontWeight weight = FontWeight.w500, Color? color, double? spacing}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
        color: color ?? AppColors.onSurfaceVariant,
      );

  /// Uppercase mono "label-caps" used for section headers and nav labels.
  static TextStyle labelCaps(
          {double size = 10, FontWeight weight = FontWeight.w700, Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 1.6,
        color: color ?? AppColors.onSurfaceVariant,
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        brightness: Brightness.light,
      ),
      splashFactory: InkRipple.splashFactory,
    );

    return base.copyWith(
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).apply(
        bodyColor: AppColors.onSurface,
        displayColor: AppColors.onSurface,
      ),
      dividerColor: AppColors.outlineVariant,
      iconTheme: const IconThemeData(color: AppColors.onSurfaceVariant),
    );
  }
}
