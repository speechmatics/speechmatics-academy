// Speechmatics real-time websocket session. dart:io transport on
// mobile/desktop; a throwing stub on web (no header auth there, and the app's
// live pipeline is native-only anyway).
export 'rt_client_stub.dart' if (dart.library.io) 'rt_client_io.dart';
