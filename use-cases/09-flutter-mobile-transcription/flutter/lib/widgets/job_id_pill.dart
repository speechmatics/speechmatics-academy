import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Small monospace `JOB ID: <id>` chip. Tap to copy the id to the clipboard.
/// The id is the Speechmatics job id returned at submission.
class JobIdPill extends StatelessWidget {
  const JobIdPill(this.id, {super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Job ID copied: $id'), duration: const Duration(seconds: 1)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'JOB ID: $id',
              style: AppType.mono(
                  size: 10, weight: FontWeight.w500, color: AppColors.onSurfaceVariant, spacing: 0.4),
            ),
            const SizedBox(width: 6),
            Icon(Symbols.content_copy, size: 12, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
