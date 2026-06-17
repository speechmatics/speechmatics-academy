import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/history_item.dart';
import '../theme/app_colors.dart';

/// Identifies the transcript word currently being spoken:
/// segment index → part index → word index.
typedef ActiveWord = ({int seg, int part, int word});

/// Renders a transcript part, highlighting the active word during playback.
///
/// Falls back to a plain [Text] when the part has no word timings (items
/// created before timings were captured) or no [activeWord] source exists
/// (no audio). Because each word's text carries its own delimiters and
/// punctuation, the rich text is glyph-identical to `Text(part.text)`.
Widget highlightedPartText(
  TranscriptPart part, {
  required int seg,
  required int partIndex,
  ValueListenable<ActiveWord?>? activeWord,
  required TextStyle style,
}) {
  if (activeWord == null || part.words.isEmpty) {
    return Text(part.text, style: style);
  }
  final highlight = TextStyle(
    backgroundColor: AppColors.primary.withValues(alpha: 0.25),
  );
  return ValueListenableBuilder<ActiveWord?>(
    valueListenable: activeWord,
    builder: (_, active, __) {
      final wordIdx =
          (active != null && active.seg == seg && active.part == partIndex) ? active.word : -1;
      if (wordIdx < 0) return Text(part.text, style: style);
      return Text.rich(
        TextSpan(
          style: style,
          children: [
            for (var k = 0; k < part.words.length; k++)
              TextSpan(text: part.words[k].text, style: k == wordIdx ? highlight : null),
          ],
        ),
      );
    },
  );
}
