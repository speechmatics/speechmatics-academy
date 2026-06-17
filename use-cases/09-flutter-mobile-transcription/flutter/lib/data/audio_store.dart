// Persists submitted audio for later playback. Real implementation on
// mobile/desktop (dart:io + path_provider); inert stub on web (the live
// pipeline doesn't run there anyway — Speechmatics batch has no CORS).
export 'audio_store_stub.dart' if (dart.library.io) 'audio_store_io.dart';
