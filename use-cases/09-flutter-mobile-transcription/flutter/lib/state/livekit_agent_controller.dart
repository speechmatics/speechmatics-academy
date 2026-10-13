import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/history_item.dart';
import '../models/livekit_agent.dart';

class LiveKitAgentController extends ChangeNotifier {
  LiveKitAgentController({required this.transport, required this.saveHistory}) {
    transport.addListener(_onTransport);
  }
  final LiveKitAgentTransport transport;
  final void Function(HistoryItem) saveHistory;
  LiveKitAgentPhase phase = LiveKitAgentPhase.idle;
  String? error;
  bool microphoneEnabled = false;
  final _captions = <String, LiveKitAgentMessage>{};
  List<LiveKitAgentMessage> get messages => List.unmodifiable(_captions.values);
  bool get isActive =>
      phase != LiveKitAgentPhase.idle && phase != LiveKitAgentPhase.error;
  bool get microphoneBusy => _micPending != null;
  bool get saved => _saved;
  bool _saved = false;
  bool _disposed = false;
  bool _startPending = false;
  bool _endingNow = false;
  Future<void>? _starting;
  Future<void>? _micPending;
  Future<void>? _ending;
  DateTime? _startedAt;

  Future<void> start() async {
    if (_starting != null || _endingNow || _disposed) return;
    _startedAt = DateTime.now();
    phase = LiveKitAgentPhase.connecting;
    _startPending = true;
    _notify();
    try {
      _starting = transport.start();
      await _starting;
      if (!_endingNow) _onTransport();
    } catch (_) {
      error =
          'Unable to start the Agent. Check the connection setup and microphone permission.';
    } finally {
      _startPending = false;
    }
    if (error != null && !_endingNow) await end();
  }

  void _onTransport() {
    if (_endingNow || _disposed) return;
    for (final message in transport.messages) {
      if (message.text.trim().isEmpty) continue;
      _captions[message.id] = message;
    }
    error = transport.error;
    phase = error == null ? transport.phase : LiveKitAgentPhase.error;
    microphoneEnabled = transport.microphoneEnabled;
    _notify();
    if (error != null && !_startPending) unawaited(end());
  }

  Future<void> toggleMicrophone() async {
    if (_endingNow || _disposed || microphoneBusy || !isActive || _startPending) {
      return;
    }
    try {
      _micPending = transport.setMicrophoneEnabled(!microphoneEnabled);
      _notify();
      await _micPending;
      if (!_endingNow) _onTransport();
    } catch (_) {
      if (!_endingNow) {
        error = 'Microphone unavailable. Check its permission and start again.';
      }
    } finally {
      _micPending = null;
      _notify();
    }
    if (error != null && !_endingNow) await end();
  }

  Future<void> end() => _ending ??= _end();

  Future<void> _end() async {
    _endingNow = true;
    phase = LiveKitAgentPhase.ending;
    microphoneEnabled = false;
    transport.removeListener(_onTransport);
    _notify();
    try {
      await transport.interrupt();
    } catch (_) {/* Final close below also attempts SDK cleanup. */}
    try {
      await _starting;
    } catch (_) {/* Already surfaced by start. */}
    try {
      await _micPending;
    } catch (_) {/* Already surfaced by toggle. */}
    try {
      await transport.close();
    } catch (_) {
      error ??= 'The session ended with a connection cleanup error.';
    }
    _save();
    phase = error == null ? LiveKitAgentPhase.idle : LiveKitAgentPhase.error;
    _notify();
  }

  void _save() {
    if (_saved || _captions.isEmpty) return;
    final now = DateTime.now();
    final elapsed = now.difference(_startedAt ?? now).inSeconds;
    final conversation = messages
        .map((message) => ConversationTurn(
              role: message.isUser ? 'User' : 'A',
              lang: 'EN',
              text: message.text.trim(),
            ))
        .toList();
    try {
      saveHistory(HistoryItem(
        id: 'agent-${(_startedAt ?? now).microsecondsSinceEpoch}',
        type: HistoryType.conversation,
        title: 'Agent session',
        jobId: '',
        languages: const ['EN'],
        relativeLabel: 'Just now',
        bucket: 'today',
        model: 'Agent STT',
        duration:
            '${elapsed ~/ 60}:${(elapsed % 60).toString().padLeft(2, '0')}',
        turns: conversation.length,
        conversation: conversation,
        createdAt: now,
      ));
      _saved = true;
    } catch (_) {
      error = 'The conversation could not be saved to History.';
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(end());
    super.dispose();
  }
}
