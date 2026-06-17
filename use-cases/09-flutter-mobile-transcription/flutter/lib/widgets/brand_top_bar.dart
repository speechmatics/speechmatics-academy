import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';

enum TopBarLeading { none, back, close }

/// Canonical top app bar: optional leading (back/close), centered Speechmatics
/// wordmark, and optional trailing actions (right slot).
///
/// Translucent + blurred with a hairline bottom border — matches the
/// `bg-surface/90 backdrop-blur` header used across the reference screens.
class BrandTopBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandTopBar({
    super.key,
    this.leading = TopBarLeading.none,
    this.onLeading,
    this.trailing,
  });

  final TopBarLeading leading;
  final VoidCallback? onLeading;

  /// Optional trailing actions shown in the right slot.
  final List<Widget>? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: Color(0xE6F8FAF9), // surface @ 90%
            border: Border(
              bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _leadingButton(context),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Image.asset(
                      'assets/images/sm_logo.png',
                      height: 22,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: trailing ?? const <Widget>[],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leadingButton(BuildContext context) {
    switch (leading) {
      case TopBarLeading.back:
        return _iconBtn(context, Symbols.arrow_back);
      case TopBarLeading.close:
        return _iconBtn(context, Symbols.close);
      case TopBarLeading.none:
        return const SizedBox.shrink();
    }
  }

  Widget _iconBtn(BuildContext context, IconData icon) {
    return IconButton(
      onPressed: onLeading ?? () => Navigator.maybePop(context),
      icon: Icon(icon, size: 22, color: AppColors.onSurface),
      style: IconButton.styleFrom(shape: const CircleBorder()),
    );
  }
}
