import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:speechmatics_translate/data/livekit_agent_config.dart';
import 'package:speechmatics_translate/data/livekit_agent_token_source.dart';

void main() {
  const config = LiveKitAgentConfig(
      endpoint: 'https://example.com/token',
      accessToken: 'test-access-token',
      agentName: 'everyvoice-agent');
  const options = lk.TokenRequestOptions(
      agentName: 'everyvoice-agent',
      agentMetadata: '{"personality":"Be concise."}');
  const hostedConfig = LiveKitAgentConfig(
    mode: LiveKitAgentConnectionMode.hostedDevelopment,
    developmentServerId: 'test-server-123',
    endpoint: 'https://custom.example.com/token',
    accessToken: 'saved-custom-secret',
    agentName: 'everyvoice-agent',
  );
  test(
      'endpoint request sends authenticated named dispatch without caller room or identity',
      () async {
    http.Request? sent;
    final source =
        LiveKitAgentTokenSource(config, client: MockClient((request) async {
      sent = request;
      return http.Response(
          '{"server_url":"wss://test.livekit.cloud","participant_token":"scoped-token"}',
          201);
    }));
    final result = await source.fetch(options);
    expect(result.participantToken, 'scoped-token');
    expect(sent!.method, 'POST');
    expect(sent!.headers['authorization'], 'Bearer test-access-token');
    expect(jsonDecode(sent!.body), {
      'room_config': {
        'agents': [
          {
            'agent_name': 'everyvoice-agent',
            'metadata': '{"personality":"Be concise."}'
          }
        ]
      }
    });
    source.cancel();
  });
  test('cancellation rejects a late token response before room connection',
      () async {
    final response = Completer<http.Response>();
    final source = LiveKitAgentTokenSource(config,
        client: MockClient((_) => response.future));
    final fetching = source.fetch(options);
    source.cancel();
    response.complete(http.Response(
        '{"server_url":"wss://test.livekit.cloud","participant_token":"late-token"}',
        201));
    await expectLater(fetching, throwsA(isA<StateError>()));
  });
  test('server error bodies cannot leak credentials into SDK errors', () async {
    final source = LiveKitAgentTokenSource(config,
        client: MockClient((_) async =>
            http.Response('test-access-token secret-response', 401)));
    await expectLater(
        source.fetch(options),
        throwsA(predicate<Object>((error) =>
            error.toString().contains('access token') &&
            !error.toString().contains('test-access-token') &&
            !error.toString().contains('secret-response'))));
    source.cancel();
  });
  test('hosted requests use canonical SDK URL and ID with no bearer credential',
      () async {
    http.Request? sent;
    final source = LiveKitAgentTokenSource(hostedConfig,
        client: MockClient((request) async {
      sent = request;
      return http.Response(
          '{"server_url":"wss://test.livekit.cloud","participant_token":"scoped-token"}',
          200);
    }));
    final result = await source.fetch(options);
    expect(result.participantToken, 'scoped-token');
    expect(sent!.method, 'POST');
    expect(sent!.url.toString(),
        'https://cloud-api.livekit.io/api/v2/sandbox/connection-details');
    expect(sent!.headers['x-sandbox-id'], 'test-server-123');
    expect(sent!.headers['content-type'], contains('application/json'));
    expect(sent!.headers.containsKey('authorization'), isFalse);
    expect('${sent!.headers} ${sent!.body}',
        isNot(contains('saved-custom-secret')));
    expect(jsonDecode(sent!.body), {
      'room_config': {
        'agents': [
          {
            'agent_name': 'everyvoice-agent',
            'metadata': '{"personality":"Be concise."}'
          }
        ]
      }
    });
    source.cancel();
  });

  test('hosted authorization errors give setup guidance without secret bodies',
      () async {
    for (final status in [401, 403]) {
      final source = LiveKitAgentTokenSource(hostedConfig,
          client: MockClient((_) async => http.Response(
              'test-server-123 saved-custom-secret secret-response', status)));
      await expectLater(
          source.fetch(options),
          throwsA(predicate<Object>((error) =>
              error.toString().contains('development token server') &&
              !error.toString().contains('test-server-123') &&
              !error.toString().contains('saved-custom-secret') &&
              !error.toString().contains('secret-response'))));
      source.cancel();
    }
  });

  for (final entry in {'custom': config, 'hosted': hostedConfig}.entries) {
    test('${entry.key} rejects late tokens and further fetches after cancel',
        () async {
      final response = Completer<http.Response>();
      final client = _OwnedClient((_) => response.future);
      final source = LiveKitAgentTokenSource(entry.value, client: client);
      final fetching = source.fetch(options);
      source.cancel();
      expect(client.closed, isTrue);
      response.complete(http.Response(
          '{"server_url":"wss://test.livekit.cloud","participant_token":"late-token"}',
          201));
      await expectLater(fetching, throwsA(isA<StateError>()));
      await expectLater(source.fetch(options), throwsA(isA<StateError>()));
    });

    testWidgets('${entry.key} token timeout closes the owned client',
        (tester) async {
      final client = _OwnedClient((_) => Completer<http.Response>().future);
      final source = LiveKitAgentTokenSource(entry.value, client: client);
      final failure = expectLater(
          source.fetch(options),
          throwsA(isA<StateError>().having(
              (error) => error.message, 'message', contains('timed out'))));
      await tester.pump(const Duration(seconds: 16));
      await failure;
      expect(client.closed, isTrue);
    });

    test(
        '${entry.key} sanitizes service failures and malformed token responses',
        () async {
      for (final response in [
        http.Response('secret-response', 500),
        http.Response('secret-response', 200),
        http.Response(
            '{"server_url":"http://example.com","participant_token":"secret-response"}',
            200),
        http.Response(
            '{"server_url":"wss://test.livekit.cloud","participant_token":""}',
            200),
      ]) {
        final source = LiveKitAgentTokenSource(entry.value,
            client: MockClient((_) async => response));
        await expectLater(
            source.fetch(options),
            throwsA(predicate<Object>((error) =>
                error is StateError &&
                !error.toString().contains('secret-response'))));
        source.cancel();
      }
    });
  }
}

class _OwnedClient extends MockClient {
  _OwnedClient(super.fn);
  bool closed = false;
  @override
  void close() {
    closed = true;
    super.close();
  }
}
