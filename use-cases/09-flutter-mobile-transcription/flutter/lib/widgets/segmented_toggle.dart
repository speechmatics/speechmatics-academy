import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class SegItem<T> {
  const SegItem(this.value, this.label);
  final T value;
  final String label;
}

/// A pill / segmented control. Active segment is jade-filled with a soft
/// shadow; inactive segments are transparent. Used for the Batch/Real-Time
/// switch, language mode, view toggle, etc.
class SegmentedToggle<T> extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.expand = false,
    this.radius = 999,
    this.segHPad = 20,
    this.segVPad = 8,
    this.fontSize = 13,
    this.disabled = const {},
  });

  final List<SegItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  /// When true each segment flexes to fill the available width.
  final bool expand;
  final double radius;
  final double segHPad;
  final double segVPad;
  final double fontSize;

  /// Values rendered greyed-out and non-tappable (constraint stays visible).
  final Set<T> disabled;

  @override
  Widget build(BuildContext context) {
    final inner = radius >= 999 ? 999.0 : radius - 2;
    final row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: items.map((it) {
        final active = it.value == value;
        final seg = AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: segHPad, vertical: segVPad),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(inner),
            boxShadow: active
                ? const [
                    BoxShadow(
                        color: Color(0x4D29A383),
                        blurRadius: 3,
                        offset: Offset(0, 1)),
                  ]
                : null,
          ),
          // Never wrap a segment label — shrink it to fit instead (3+ segments
          // on narrow phones would otherwise push the last letter to a 2nd row).
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              it.label,
              maxLines: 1,
              style: AppType.body(
                size: fontSize,
                weight: FontWeight.w600,
                color: active ? AppColors.onPrimary : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        );
        final isDisabled = disabled.contains(it.value);
        final tappable = isDisabled
            ? Opacity(opacity: 0.4, child: seg)
            : InkWell(
                borderRadius: BorderRadius.circular(inner),
                onTap: () => onChanged(it.value),
                child: seg,
              );
        return expand ? Expanded(child: tappable) : tappable;
      }).toList(),
    );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: row,
    );
  }
}
