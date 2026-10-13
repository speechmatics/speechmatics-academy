import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:speechmatics_translate/models/history_item.dart';
import 'package:speechmatics_translate/models/livekit_agent.dart';
import 'package:speechmatics_translate/state/livekit_agent_controller.dart';

class _Transport extends LiveKitAgentTransport {
  @override
  LiveKitAgentPhase phase = LiveKitAgentPhase.idle;
  @override
  String? error;
  @override
  List<LiveKitAgentMessage> messages = [];
  @override
  bool microphoneEnabled = false;
  Completer<void>? startGate;
  Completer<void>? micGate;
  bool closed = false;
  bool interrupted = false;
  @override
  Future<void> start() async {
    await startGate?.future;
    if (error != null) {
      notifyListeners();
      return;
    }
    microphoneEnabled = true;
    phase = LiveKitAgentPhase.listening;
    notifyListeners();
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    await micGate?.future;
    microphoneEnabled = enabled;
    notifyListeners();
  }

  @override
  Future<void> interrupt() async {
    interrupted = true;
    microphoneEnabled = false;
  }

  @override
  Future<void> close() async {
    closed = true;
    microphoneEnabled = false;
  }

  void update(List<LiveKitAgentMessage> value) {
    messages = value;
    notifyListeners();
  }

  void fail(String value) {
    error = value;
    phase = LiveKitAgentPhase.error;
    notifyListeners();
  }
}

LiveKitAgentMessage _message(String id, String text, {bool user = true}) =>
    LiveKitAgentMessage(
        id: id, timestamp: DateTime(2026, 10, 5), text: text, isUser: user);

void main() {
  late _Transport transport;
  late LiveKitAgentController controller;
  late List<HistoryItem> saved;
  setUp(() {
    transport = _Transport();
    saved = [];
    controller =
        LiveKitAgentController(transport: transport, saveHistory: saved.add);
  });
  tearDown(() => controller.dispose());

  test('end during pending start waits for late media then closes it',
      () async {
    transport.startGate = Completer();
    final starting = controller.start();
    expect(controller.phase, LiveKitAgentPhase.connecting);
    final ending = controller.end();
    expect(transport.interrupted, isTrue);
    transport.startGate!.complete();
    await Future.wait([starting, ending]);
    expect(controller.phase, LiveKitAgentPhase.idle);
    expect(transport.closed, isTrue);
    expect(transport.microphoneEnabled, isFalse);
    expect(saved, isEmpty);
  });

  test('pending unmute cannot leave microphone enabled after end', () async {
    await controller.start();
    await controller.toggleMicrophone();
    expect(controller.microphoneEnabled, isFalse);
    transport.micGate = Completer();
    final unmuting = controller.toggleMicrophone();
    final ending = controller.end();
    transport.micGate!.complete();
    await Future.wait([unmuting, ending]);
    expect(transport.microphoneEnabled, isFalse);
    expect(controller.microphoneEnabled, isFalse);
    expect(transport.closed, isTrue);
  });

  test('SDK reported start error is visible and releases resources', () async {
    transport.error = 'Unable to connect';
    await controller.start();
    expect(controller.phase, LiveKitAgentPhase.error);
    expect(controller.error, 'Unable to connect');
    expect(transport.closed, isTrue);
    expect(saved, isEmpty);
  });

  test('empty conversation does not create history', () async {
    await controller.start();
    await controller.end();
    expect(saved, isEmpty);
    expect(transport.closed, isTrue);
  });

  test('segment updates replace captions and save one latest turn per id',
      () async {
    await controller.start();
    transport.update([_message('u1', 'Hel')]);
    transport
        .update([_message('u1', 'Hello'), _message('a1', 'Hi', user: false)]);
    transport.update([
      _message('u1', 'Hello'),
      _message('a1', 'Hi there', user: false),
      _message('blank', ' ')
    ]);
    expect(controller.messages.map((m) => m.text), ['Hello', 'Hi there']);
    await controller.end();
    await controller.end();
    expect(saved, hasLength(1));
    final item = HistoryItem.fromJson(saved.single.toJson());
    expect(item.conversation!.map((m) => m.text), ['Hello', 'Hi there']);
    expect(item.conversation!.map((m) => m.role), ['User', 'A']);
    expect(item.type, HistoryType.conversation);
    expect(item.model, 'Agent STT');
    expect(item.jobId, isEmpty);
    expect(item.audioFile, isNull);
  });

  test('failure mid conversation saves captions and releases microphone',
      () async {
    await controller.start();
    transport.update([_message('u1', 'Keep this')]);
    transport.fail('Agent left');
    await controller.end();
    expect(controller.phase, LiveKitAgentPhase.error);
    expect(saved.single.conversation!.single.text, 'Keep this');
    expect(transport.microphoneEnabled, isFalse);
  });

  test('dispose during start closes late media without notifying disposed UI',
      () async {
    transport.startGate = Completer();
    final starting = controller.start();
    controller.dispose();
    transport.startGate!.complete();
    await starting;
    await Future<void>.delayed(Duration.zero);
    expect(transport.closed, isTrue);
    expect(transport.microphoneEnabled, isFalse);
  });
}
