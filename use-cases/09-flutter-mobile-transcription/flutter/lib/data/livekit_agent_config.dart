import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum LiveKitAgentConnectionMode { hostedDevelopment, customEndpoint }

class LiveKitAgentConfig {
  const LiveKitAgentConfig(
      {required this.endpoint,
      required this.accessToken,
      required this.agentName,
      this.mode = LiveKitAgentConnectionMode.customEndpoint,
      this.developmentServerId = ''});
  final String endpoint;
  final String accessToken;
  final String agentName;
  final LiveKitAgentConnectionMode mode;
  final String developmentServerId;
  String? get validationError {
    if (mode == LiveKitAgentConnectionMode.hostedDevelopment) {
      // Match a bare ID without relying on the SDK to strip punctuation.
      if (!RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9_-]{0,254}[A-Za-z0-9])?$')
          .hasMatch(developmentServerId.trim())) {
        return 'Enter the LiveKit Server ID (up to 256 letters, numbers, hyphens or underscores), not a URL.';
      }
    } else {
      final uri = Uri.tryParse(endpoint.trim());
      if (uri == null ||
          !uri.hasAuthority ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        return 'Enter the token endpoint URL without credentials, query parameters or a fragment.';
      }
      if (uri.scheme != 'https' &&
          !(kDebugMode && _isLoopbackHost(uri.host) && uri.scheme == 'http')) {
        return 'Use HTTPS for the token endpoint. Localhost HTTP is available in debug builds.';
      }
      if (accessToken.trim().isEmpty) return 'Enter the endpoint access token.';
    }
    if (agentName.trim().isEmpty || agentName.trim().length > 128) {
      return 'Enter an agent name of at most 128 characters.';
    }
    return null;
  }
}

class LiveKitAgentConfigStore {
  LiveKitAgentConfigStore(
      {FlutterSecureStorage? storage,
      String defaultDevelopmentServerId =
          LiveKitAgentConfigStore.defaultDevelopmentServerId})
      : _defaultDevelopmentServerId = defaultDevelopmentServerId.trim(),
        _storage = storage ??
            const FlutterSecureStorage(
              // Isolate data, algorithm markers, wrapped keys AND KeyStore
              // aliases from the pre-existing Speechmatics/Google key store.
              // An unwrap failure must surface, never erase stored values.
              aOptions: AndroidOptions(
                storageNamespace: 'everyvoice_livekit_agent',
                resetOnError: false,
              ),
              iOptions: IOSOptions(accountName: 'everyvoice_livekit_agent'),
              mOptions: MacOsOptions(accountName: 'everyvoice_livekit_agent'),
            );
  final FlutterSecureStorage _storage;
  final String _defaultDevelopmentServerId;
  static const _endpointKey = 'livekit_agent_endpoint';
  static const _tokenKey = 'livekit_agent_access_token';
  static const _nameKey = 'livekit_agent_name';
  static const _modeKey = 'livekit_agent_connection_mode';
  static const _developmentServerIdKey = 'livekit_agent_development_server_id';
  static const defaultDevelopmentServerId =
      String.fromEnvironment('LIVEKIT_TOKEN_SERVER_ID');
  static const defaultEndpoint =
      String.fromEnvironment('LIVEKIT_TOKEN_ENDPOINT');
  static const defaultAgentName = String.fromEnvironment('LIVEKIT_AGENT_NAME',
      defaultValue: 'everyvoice-agent');

  Future<LiveKitAgentConfig> load() async {
    final savedEndpoint = await _storage.read(key: _endpointKey);
    final accessToken = await _storage.read(key: _tokenKey) ?? '';
    final agentName = await _storage.read(key: _nameKey) ?? defaultAgentName;
    final savedMode = await _storage.read(key: _modeKey);
    final serverId = await _storage.read(key: _developmentServerIdKey) ??
        _defaultDevelopmentServerId;
    final legacyUri = Uri.tryParse(savedEndpoint?.trim() ?? '');
    final useHostedDefault = _defaultDevelopmentServerId.isNotEmpty &&
        (savedEndpoint == null ||
            savedEndpoint.trim().isEmpty ||
            (legacyUri?.scheme == 'http' && _isLoopbackHost(legacyUri!.host)));
    // Only missing-mode legacy settings may migrate. Explicit custom and
    // unknown future modes keep their existing authentication path.
    final mode =
        savedMode == LiveKitAgentConnectionMode.hostedDevelopment.name ||
                (savedMode == null && useHostedDefault)
            ? LiveKitAgentConnectionMode.hostedDevelopment
            : LiveKitAgentConnectionMode.customEndpoint;
    return LiveKitAgentConfig(
      endpoint: savedEndpoint ?? defaultEndpoint,
      accessToken: accessToken,
      agentName: agentName,
      mode: mode,
      developmentServerId: serverId,
    );
  }

  Future<void> save(LiveKitAgentConfig config) async {
    final error = config.validationError;
    if (error != null) throw FormatException(error);
    await _storage.write(key: _endpointKey, value: config.endpoint.trim());
    await _storage.write(key: _tokenKey, value: config.accessToken.trim());
    await _storage.write(key: _nameKey, value: config.agentName.trim());
    await _storage.write(
        key: _developmentServerIdKey, value: config.developmentServerId.trim());
    await _storage.write(key: _modeKey, value: config.mode.name);
  }
}

bool _isLoopbackHost(String host) =>
    ['localhost', '127.0.0.1', '[::1]', '::1'].contains(host);
