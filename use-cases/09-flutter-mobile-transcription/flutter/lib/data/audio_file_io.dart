import 'dart:io';

Future<List<int>> readAudioBytes(String path) => File(path).readAsBytes();

/// Best-effort removal of a temp recording file.
Future<void> deleteAudioFile(String path) async {
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}
