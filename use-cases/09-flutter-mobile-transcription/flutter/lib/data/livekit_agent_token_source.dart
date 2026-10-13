import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as lk;
import 'livekit_agent_config.dart';

class LiveKitAgentTokenSource implements lk.TokenSourceConfigurable {
  LiveKitAgentTokenSource(LiveKitAgentConfig config, {http.Client? client})
      : _mode = config.mode,
        _client = client ?? http.Client() {
    final validationError = config.validationError;
    if (validationError != null) throw FormatException(validationError);
    if (_mode == LiveKitAgentConnectionMode.hostedDevelopment) {
      final development =
          lk.DevelopmentTokenSource(id: config.developmentServerId.trim());
      _endpoint = lk.EndpointTokenSource(
        url: development.uri,
        headers: development.headers,
        client: _client,
      );
    } else {
      _endpoint = lk.EndpointTokenSource(
        url: Uri.parse(config.endpoint.trim()),
        headers: {'Authorization': 'Bearer ${config.accessToken.trim()}'},
        client: _client,
      );
    }
  }
  final LiveKitAgentConnectionMode _mode;
  final http.Client _client;
  late final lk.EndpointTokenSource _endpoint;
  bool _cancelled = false;
  void cancel() {
    _cancelled = true;
    _client.close();
  }

  @override
  Future<lk.TokenSourceResponse> fetch(lk.TokenRequestOptions options) async {
    if (_cancelled) throw StateError('Agent connection cancelled.');
    try {
      final response =
          await _endpoint.fetch(options).timeout(const Duration(seconds: 15));
      if (_cancelled) throw StateError('Agent connection cancelled.');
      final server = Uri.tryParse(response.serverUrl);
      if (server == null ||
          server.scheme != 'wss' ||
          server.host.isEmpty ||
          server.userInfo.isNotEmpty ||
          response.participantToken.trim().isEmpty) {
        throw const FormatException('Invalid Agent connection response.');
      }
      return response;
    } on lk.TokenSourceHttpException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        if (_mode == LiveKitAgentConnectionMode.hostedDevelopment) {
          throw StateError('LiveKit development token server rejected access. '
              'Check the Server ID and enable development token access in LiveKit.');
        }
        throw StateError(
            'Agent access token was rejected. Check connection setup.');
      }
      throw StateError(
          'Agent token service returned HTTP ${error.statusCode}.');
    } on TimeoutException {
      _client.close();
      throw StateError('Agent token service timed out.');
    } on StateError {
      rethrow;
    } catch (_) {
      throw StateError(
          'Unable to contact the Agent token service. Check connection setup.');
    }
  }
}
