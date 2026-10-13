import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speechmatics_translate/data/livekit_agent_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const config = LiveKitAgentConfig(
    endpoint: 'https://example.com/token',
    accessToken: 'test-only-token',
    agentName: 'everyvoice-agent',
  );
  late List<MethodCall> calls;
  late Map<String, String> values;

  setUp(() {
    calls = [];
    values = {};
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final args = (call.arguments as Map).cast<String, dynamic>();
      final key = args['key'] as String;
      if (call.method == 'write') values[key] = args['value'] as String;
      return call.method == 'read' ? values[key] : null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
      'Android Agent reads and writes isolate key material and disable destructive reset',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final store = LiveKitAgentConfigStore();
    await store.save(config);
    expect((await store.load()).accessToken, 'test-only-token');
    expect(calls.where((call) => call.method == 'write'), hasLength(5));
    expect(calls.where((call) => call.method == 'read'), hasLength(5));
    for (final call in calls) {
      final options = (call.arguments as Map)['options'] as Map;
      expect(options['storageNamespace'], 'everyvoice_livekit_agent');
      expect(options['resetOnError'], 'false');
    }
  });

  test('Apple Agent reads and writes use a dedicated Keychain service',
      () async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      debugDefaultTargetPlatformOverride = platform;
      calls.clear();
      final store = LiveKitAgentConfigStore();
      await store.save(config);
      expect((await store.load()).accessToken, 'test-only-token');
      expect(calls, hasLength(10));
      for (final call in calls) {
        final options = (call.arguments as Map)['options'] as Map;
        expect(options['accountName'], 'everyvoice_livekit_agent');
      }
    }
  });

  test(
      'Agent storage failure propagates without fallback reads or delete/reset calls',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      throw PlatformException(
          code: 'InvalidKeyException', message: 'Failed to unwrap');
    });
    await expectLater(
        LiveKitAgentConfigStore().load(), throwsA(isA<PlatformException>()));
    expect(calls, hasLength(1));
    expect(calls.single.method, 'read');
    final options = (calls.single.arguments as Map)['options'] as Map;
    expect(options['storageNamespace'], 'everyvoice_livekit_agent');
    expect(options['resetOnError'], 'false');
  });
}
