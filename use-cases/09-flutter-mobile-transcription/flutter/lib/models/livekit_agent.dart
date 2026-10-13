import 'package:flutter/foundation.dart';

enum LiveKitAgentPhase {
  idle,
  connecting,
  listening,
  thinking,
  speaking,
  reconnecting,
  ending,
  error,
}

class LiveKitAgentMessage {
  const LiveKitAgentMessage({
    required this.id,
    required this.timestamp,
    required this.text,
    required this.isUser,
  });
  final String id;
  final DateTime timestamp;
  final String text;
  final bool isUser;
}

/// Native SDK boundary. A transport belongs to exactly one conversation.
abstract class LiveKitAgentTransport extends ChangeNotifier {
  LiveKitAgentPhase get phase;
  String? get error;
  List<LiveKitAgentMessage> get messages;
  bool get microphoneEnabled;
  Future<void> start();
  Future<void> setMicrophoneEnabled(bool enabled);

  /// Prevent new connection work immediately, then disconnect active media.
  Future<void> interrupt();

  /// Release resources after pending start/microphone operations have settled.
  Future<void> close();
}
