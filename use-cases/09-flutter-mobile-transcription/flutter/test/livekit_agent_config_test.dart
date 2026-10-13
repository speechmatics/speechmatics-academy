import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:speechmatics_translate/data/livekit_agent_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LiveKitAgentConfig config(String endpoint,
          {String token = 'app-token', String name = 'everyvoice-agent'}) =>
      LiveKitAgentConfig(
          endpoint: endpoint, accessToken: token, agentName: name);
  test(
      'access token only goes to HTTPS endpoints or explicit local development',
      () {
    for (final endpoint in [
      'https://example.com/token',
      'http://localhost:8080/token',
      'http://127.0.0.1:8080/token',
      'http://[::1]:8080/token'
    ]) {
      expect(config(endpoint).validationError, isNull, reason: endpoint);
    }
    for (final endpoint in [
      '',
      'not a url',
      'http://example.com/token',
      'https://user:secret@example.com/token',
      'https://example.com/token?key=secret',
      'https://example.com/token#fragment',
      'wss://example.com/token'
    ]) {
      expect(config(endpoint).validationError, isNotNull, reason: endpoint);
    }
    expect(config('https://example.com/token', token: '').validationError,
        isNotNull);
    expect(config('https://example.com/token', name: '').validationError,
        isNotNull);
  });
  test('agent setup persists only in dedicated secure storage keys', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'sm_api_key': 'sm-existing', 'google_api_key': 'google-existing'});
    final store = LiveKitAgentConfigStore();
    await store.save(config('https://example.com/token'));
    final loaded = await store.load();
    expect(loaded.endpoint, 'https://example.com/token');
    expect(loaded.accessToken, 'app-token');
    expect(loaded.agentName, 'everyvoice-agent');
    const storage = FlutterSecureStorage();
    expect(await storage.read(key: 'livekit_agent_connection_mode'),
        'customEndpoint');
    expect(await storage.read(key: 'sm_api_key'), 'sm-existing');
    expect(await storage.read(key: 'google_api_key'), 'google-existing');
  });

  LiveKitAgentConfig hosted(String id,
          {String name = 'everyvoice-agent',
          String endpoint = '',
          String token = ''}) =>
      LiveKitAgentConfig(
        mode: LiveKitAgentConnectionMode.hostedDevelopment,
        developmentServerId: id,
        endpoint: endpoint,
        accessToken: token,
        agentName: name,
      );

  test('hosted mode accepts a bare server ID without endpoint credentials', () {
    for (final id in ['test-server-123', ' A1_b2-C3 ', 'a', 'a' * 256]) {
      expect(hosted(id).validationError, isNull, reason: id);
    }
  });

  test('hosted mode rejects URLs, invalid IDs and missing agent names', () {
    for (final id in [
      '',
      ' ',
      'https://example.com/token',
      'example.com',
      'id/other',
      'id?token=secret',
      'id#fragment',
      'id with spaces',
      'id\nheader',
      '-id',
      'id_',
      'a' * 257,
    ]) {
      expect(
          hosted(id, endpoint: 'https://example.com/token', token: 'saved')
              .validationError,
          isNotNull,
          reason: id);
    }
    expect(hosted('test-server-123', name: '').validationError, isNotNull);
    expect(
        hosted('test-server-123', name: 'a' * 129).validationError, isNotNull);
  });

  test('new installs prefer the configured hosted server', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final loaded = await LiveKitAgentConfigStore(
            defaultDevelopmentServerId: 'build-server-123')
        .load();
    expect(loaded.mode, LiveKitAgentConnectionMode.hostedDevelopment);
    expect(loaded.developmentServerId, 'build-server-123');
    expect(loaded.validationError, isNull);
  });

  test('legacy local HTTP setup migrates in memory and retains fallback values',
      () async {
    for (final endpoint in [
      'http://localhost:8000/token',
      'http://127.0.0.1:8000/token',
      'http://[::1]:8000/token',
    ]) {
      FlutterSecureStorage.setMockInitialValues({
        'livekit_agent_endpoint': endpoint,
        'livekit_agent_access_token': 'saved-custom-token',
        'livekit_agent_name': 'saved-agent',
      });
      final loaded = await LiveKitAgentConfigStore(
              defaultDevelopmentServerId: 'build-server-123')
          .load();
      expect(loaded.mode, LiveKitAgentConnectionMode.hostedDevelopment);
      expect(loaded.developmentServerId, 'build-server-123');
      expect(loaded.endpoint, endpoint);
      expect(loaded.accessToken, 'saved-custom-token');
      expect(loaded.agentName, 'saved-agent');
      expect(
          await const FlutterSecureStorage()
              .read(key: 'livekit_agent_connection_mode'),
          isNull);
    }
  });

  test('legacy HTTPS and explicit custom selections stay custom', () async {
    for (final values in [
      {'livekit_agent_endpoint': 'https://example.com/token'},
      {
        'livekit_agent_endpoint': 'http://localhost:8000/token',
        'livekit_agent_connection_mode': 'customEndpoint',
      },
      {
        'livekit_agent_endpoint': 'http://localhost:8000/token',
        'livekit_agent_connection_mode': 'futureMode',
      },
    ]) {
      FlutterSecureStorage.setMockInitialValues({
        ...values,
        'livekit_agent_access_token': 'saved-custom-token',
        'livekit_agent_name': 'saved-agent',
      });
      final loaded = await LiveKitAgentConfigStore(
              defaultDevelopmentServerId: 'build-server-123')
          .load();
      expect(loaded.mode, LiveKitAgentConnectionMode.customEndpoint);
      expect(loaded.endpoint, values['livekit_agent_endpoint']);
      expect(loaded.accessToken, 'saved-custom-token');
    }
  });

  test('no configured hosted default leaves legacy setup custom', () async {
    FlutterSecureStorage.setMockInitialValues({
      'livekit_agent_endpoint': 'http://localhost:8000/token',
      'livekit_agent_access_token': 'saved-custom-token',
    });
    final loaded =
        await LiveKitAgentConfigStore(defaultDevelopmentServerId: '').load();
    expect(loaded.mode, LiveKitAgentConnectionMode.customEndpoint);
    expect(loaded.developmentServerId, isEmpty);
  });

  test('hosted choice and ID persist without replacing custom credentials',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = LiveKitAgentConfigStore(
        defaultDevelopmentServerId: 'different-build-default');
    await store.save(const LiveKitAgentConfig(
      mode: LiveKitAgentConnectionMode.hostedDevelopment,
      developmentServerId: ' saved-hosted-server ',
      endpoint: 'https://example.com/token',
      accessToken: 'saved-custom-token',
      agentName: 'everyvoice-agent',
    ));
    final loaded = await store.load();
    expect(loaded.mode, LiveKitAgentConnectionMode.hostedDevelopment);
    expect(loaded.developmentServerId, 'saved-hosted-server');
    expect(loaded.endpoint, 'https://example.com/token');
    expect(loaded.accessToken, 'saved-custom-token');
  });

  test('invalid hosted save leaves existing settings unchanged', () async {
    FlutterSecureStorage.setMockInitialValues({
      'livekit_agent_connection_mode': 'customEndpoint',
      'livekit_agent_access_token': 'saved-custom-token',
    });
    await expectLater(
        LiveKitAgentConfigStore().save(hosted('https://invalid',
            endpoint: 'https://example.com/token', token: 'replacement')),
        throwsFormatException);
    final storage = const FlutterSecureStorage();
    expect(await storage.read(key: 'livekit_agent_connection_mode'),
        'customEndpoint');
    expect(await storage.read(key: 'livekit_agent_access_token'),
        'saved-custom-token');
  });
}
