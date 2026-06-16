// Shares text content as a file via the system share sheet (e.g. .srt
// subtitles). Real implementation on mobile; inert stub on web.
export 'share_text_stub.dart' if (dart.library.io) 'share_text_io.dart';
