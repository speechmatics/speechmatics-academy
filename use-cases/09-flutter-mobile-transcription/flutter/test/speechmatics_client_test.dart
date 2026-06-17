import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:speechmatics_translate/data/dto/job_status.dart';
import 'package:speechmatics_translate/data/speechmatics_client.dart';

http.Response _job(String status) =>
    http.Response(jsonEncode({'job': {'status': status}}), 200);

void main() {
  const tick = Duration(milliseconds: 1);

  group('pollUntilDone fault tolerance', () {
    test('transient network failures do NOT fail the job (screen-lock case)', () async {
      var calls = 0;
      final sm = SpeechmaticsClient(
        apiKey: 'k',
        client: MockClient((req) async {
          calls++;
          // First two polls die (e.g. Android suspended the network on lock),
          // then the connection comes back and the job is found running→done.
          if (calls <= 2) throw http.ClientException('Connection closed');
          return calls == 3 ? _job('running') : _job('done');
        }),
      );
      final seen = await sm.pollUntilDone('j1', interval: tick).toList();
      expect(seen.map((s) => s.state).toList(), [JobState.running, JobState.done]);
      expect(calls, 4);
    });

    test('definitive 4xx verdicts still fail immediately', () async {
      final sm = SpeechmaticsClient(
        apiKey: 'bad',
        client: MockClient((req) async =>
            http.Response(jsonEncode({'error': 'Permission Denied'}), 401)),
      );
      await expectLater(
        sm.pollUntilDone('j1', interval: tick).toList(),
        throwsA(isA<SpeechmaticsException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('gives up after persistent consecutive failures', () async {
      var calls = 0;
      final sm = SpeechmaticsClient(
        apiKey: 'k',
        client: MockClient((req) async {
          calls++;
          throw http.ClientException('down');
        }),
      );
      await expectLater(
        sm.pollUntilDone('j1', interval: tick).toList(),
        throwsA(isA<SpeechmaticsException>().having(
            (e) => e.message, 'message', contains('Lost connection'))),
      );
      expect(calls, greaterThanOrEqualTo(2)); // retried before giving up
    });

    test('5xx server blips are retried like network failures', () async {
      var calls = 0;
      final sm = SpeechmaticsClient(
        apiKey: 'k',
        client: MockClient((req) async {
          calls++;
          return calls == 1 ? http.Response('gateway timeout', 504) : _job('done');
        }),
      );
      final seen = await sm.pollUntilDone('j1', interval: tick).toList();
      expect(seen.single.state, JobState.done);
    });
  });
}
