import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import 'dto/job_status.dart';

class SpeechmaticsException implements Exception {
  SpeechmaticsException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Thin REST client for the Speechmatics batch (self-serve) API.
class SpeechmaticsClient {
  SpeechmaticsClient({
    required this.apiKey,
    this.region = 'eu1',
    http.Client? client,
  }) : _http = client ?? http.Client();

  final String apiKey;
  final String region;
  final http.Client _http;

  String get _base => AppConfig.speechmaticsBase(region);
  Map<String, String> get _auth => {'Authorization': 'Bearer $apiKey'};

  /// Submit a transcription job. Returns the job id.
  Future<String> submitJob({
    required List<int> audioBytes,
    required String filename,
    required Map<String, dynamic> config,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_base/jobs'))
      ..headers.addAll(_auth)
      ..fields['config'] = jsonEncode(config)
      ..files.add(http.MultipartFile.fromBytes('data_file', audioBytes, filename: filename));

    final resp = await http.Response.fromStream(await _http.send(req));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final id = (jsonDecode(resp.body) as Map<String, dynamic>)['id'];
      if (id is String) return id;
      throw SpeechmaticsException('Submit succeeded but no job id in response.');
    }
    throw SpeechmaticsException(
      _friendly('Job submission failed', resp),
      statusCode: resp.statusCode,
    );
  }

  Future<JobStatus> getStatus(String jobId) async {
    final resp = await _http.get(Uri.parse('$_base/jobs/$jobId'), headers: _auth);
    if (resp.statusCode != 200) {
      throw SpeechmaticsException(_friendly('Could not fetch job status', resp),
          statusCode: resp.statusCode);
    }
    final job = (jsonDecode(resp.body) as Map<String, dynamic>)['job'] as Map<String, dynamic>;
    return JobStatus.fromJob(job);
  }

  /// Raw json-v2 transcript map.
  Future<Map<String, dynamic>> getTranscript(String jobId) async {
    final resp = await _http.get(
        Uri.parse('$_base/jobs/$jobId/transcript?format=json-v2'),
        headers: _auth);
    if (resp.statusCode != 200) {
      throw SpeechmaticsException(_friendly('Could not fetch transcript', resp),
          statusCode: resp.statusCode);
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Raw transcript body in an alternate format (e.g. 'srt' | 'txt').
  Future<String> getTranscriptRaw(String jobId, {required String format}) async {
    final resp = await _http.get(
        Uri.parse('$_base/jobs/$jobId/transcript?format=$format'),
        headers: _auth);
    if (resp.statusCode != 200) {
      throw SpeechmaticsException(_friendly('Could not fetch transcript', resp),
          statusCode: resp.statusCode);
    }
    return utf8.decode(resp.bodyBytes);
  }

  /// Polls until the job reaches a terminal state (or times out).
  ///
  /// FAULT-TOLERANT: a poll request that fails does NOT fail the job — the
  /// job keeps running server-side regardless of what happens to this client.
  /// Screen lock / Doze / radio sleep on Android can drop in-flight requests
  /// (a long job would otherwise "fail" the moment the phone locked); we retry
  /// with gentle backoff and only give up after [AppConfig.maxPollFailures]
  /// CONSECUTIVE failures. Definitive API verdicts (HTTP 4xx — bad key,
  /// deleted job) still surface immediately.
  Stream<JobStatus> pollUntilDone(
    String jobId, {
    Duration interval = AppConfig.pollInterval,
    Duration timeout = AppConfig.pollTimeout,
  }) async* {
    final deadline = DateTime.now().add(timeout);
    var failures = 0;
    while (true) {
      JobStatus status;
      try {
        status = await getStatus(jobId);
        failures = 0;
      } catch (e) {
        final code = e is SpeechmaticsException ? e.statusCode : null;
        if (code != null && code >= 400 && code < 500) rethrow;
        failures++;
        if (failures >= AppConfig.maxPollFailures) {
          throw SpeechmaticsException(
              'Lost connection while waiting for the transcript — check your '
              'network and try again (the job may still complete on the server).');
        }
        await Future.delayed(interval * failures); // 3s, 6s, 9s, …
        continue;
      }
      yield status;
      if (status.isTerminal) return;
      if (DateTime.now().isAfter(deadline)) {
        throw SpeechmaticsException('Transcription timed out after ${timeout.inMinutes} min.');
      }
      await Future.delayed(interval);
    }
  }

  String _friendly(String prefix, http.Response resp) {
    String detail = resp.body;
    try {
      final m = jsonDecode(resp.body);
      if (m is Map) {
        // `detail` carries the specific validation reason; prefer it over the
        // generic `error` ("Job rejected").
        if (m['error'] != null) detail = m['error'].toString();
        if (m['detail'] != null) detail = m['detail'].toString();
      }
    } catch (_) {}
    if (detail.length > 400) detail = '${detail.substring(0, 400)}…';
    return '$prefix (HTTP ${resp.statusCode}): $detail';
  }

  void dispose() => _http.close();
}
