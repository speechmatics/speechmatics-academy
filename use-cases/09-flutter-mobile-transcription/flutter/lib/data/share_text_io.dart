import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const bool canShareFiles = true;

/// Writes [content] to a temp file named `<baseName>.<extension>` and opens
/// the system share sheet for it.
Future<void> shareTextAsFile({
  required String content,
  required String baseName,
  required String extension,
}) async {
  final dir = await getTemporaryDirectory();
  final safe = baseName.replaceAll(RegExp(r'[^\w\- ]+'), '').trim();
  final name = safe.isEmpty ? 'transcript' : safe;
  final f = File('${dir.path}${Platform.pathSeparator}$name.$extension');
  await f.writeAsString(content, flush: true);
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
}
