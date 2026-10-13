import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:speechmatics_translate/data/livekit_agent_config.dart';
import 'package:speechmatics_translate/data/livekit_agent_transport.dart';
import 'package:speechmatics_translate/state/livekit_agent_controller.dart';

class _Microphone implements LiveKitAgentMicrophone {
  bool capturing = true;
  bool published = false;
  bool disposed = false;
  final publishing = Completer<void>();
  Completer<void>? publishGate;
  @override
  Future<void> publish() async {
    publishing.complete();
    await publishGate?.future;
    capturing = true;
    published = true;
  }

  @override
  Future<void> stop() async {
    capturing = false;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class _Room extends LiveKitAgentRoom {
  final microphone = _Microphone();
  final capturing = Completer<void>();
  Completer<void>? captureGate;
  Completer<void>? unmuteGate;
  final unmuting = Completer<void>();
  bool disconnected = false;
  @override
  Future<void> connectRoom(
    String url,
    String token, {
    lk.ConnectOptions? connectOptions,
    lk.FastConnectOptions? fastConnectOptions,
  }) async {}
  @override
  Future<LiveKitAgentMicrophone> createMicrophone() async {
    capturing.complete();
    await captureGate?.future;
    return microphone;
  }

  @override
  bool get microphoneEnabled => microphone.capturing;
  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (enabled) {
      unmuting.complete();
      await unmuteGate?.future;
    }
    // Mirrors SDK restartTrack: its native stream can finish after participant
    // teardown; looking up localParticipant afterward can no longer stop it.
    if (!disconnected || enabled) microphone.capturing = enabled;
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
  }

}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Room room;
  late LiveKitSdkAgentTransport transport;
  late LiveKitAgentController controller;
  setUp(() {
    room = _Room();
    final jwt =
        '${base64UrlEncode(utf8.encode('{}'))}.${base64UrlEncode(utf8.encode('{}'))}.signature';
    transport = LiveKitSdkAgentTransport(
      config: const LiveKitAgentConfig(
          endpoint: 'https://example.com/token',
          accessToken: 'test',
          agentName: 'everyvoice-agent'),
      personality: '',
      room: room,
      tokenClient: MockClient((_) async => http.Response(
          jsonEncode({
            'server_url': 'wss://test.livekit.cloud',
            'participant_token': jwt,
          }),
          201)),
    );
    controller =
        LiveKitAgentController(transport: transport, saveHistory: (_) {});
  });
  tearDown(() => controller.dispose());

  test(
      'actual SDK adapter stops and disposes capture returned after cancellation without publishing',
      () async {
    room.captureGate = Completer();
    final starting = controller.start();
    await room.capturing.future;
    final ending = controller.end();
    room.captureGate!.complete();
    await Future.wait([starting, ending]);
    expect(room.microphone.published, isFalse);
    expect(room.microphone.capturing, isFalse);
    expect(room.microphone.disposed, isTrue);
  });

  test(
      'actual SDK adapter stops owned capture while publish is pending and again after it settles',
      () async {
    room.microphone.publishGate = Completer();
    final starting = controller.start();
    await room.microphone.publishing.future;
    final ending = controller.end();
    await Future<void>.delayed(Duration.zero);
    expect(room.microphone.capturing, isFalse);
    room.microphone.publishGate!.complete();
    await Future.wait([starting, ending]);
    expect(room.microphone.capturing, isFalse);
    expect(room.microphone.disposed, isTrue);
  });

  test(
      'actual SDK adapter stops retained track after late native unmute despite disconnected participant',
      () async {
    await controller.start();
    await transport.setMicrophoneEnabled(false);
    room.unmuteGate = Completer();
    final unmuting = transport.setMicrophoneEnabled(true);
    await room.unmuting.future;
    await transport.interrupt();
    room.unmuteGate!.complete();
    await unmuting;
    await transport.close();
    expect(room.microphone.capturing, isFalse);
    expect(room.microphone.disposed, isTrue);
  });
}
