import 'dart:typed_data';

import 'rt_protocol.dart';

/// Web stub — live transcription needs native websocket header auth and mic
/// streaming, neither of which this build target supports.
class RtSession {
  RtSession({
    required String apiKey,
    required Uri endpoint,
    required Map<String, dynamic> startRecognition,
  });

  Stream<RtEvent> get events => const Stream.empty();
  int get seqNo => 0;

  Future<void> start() async =>
      throw UnsupportedError('Live transcription is not supported on this platform.');

  void addAudio(Uint8List chunk) {}
  Future<void> finish() async {}
  Future<void> abort() async {}
}
