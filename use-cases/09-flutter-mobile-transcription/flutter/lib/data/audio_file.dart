// Reads a recorded audio file to bytes. Uses dart:io on mobile/desktop; a
// throwing stub on web (recording-to-file isn't a web target).
export 'audio_file_stub.dart' if (dart.library.io) 'audio_file_io.dart';
