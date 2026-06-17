import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../app_config.dart';

/// Resolves and stores the Speechmatics + Google API keys.
/// Priority: in-app value (flutter_secure_storage) → `--dart-define` fallback.
class ApiKeys {
  ApiKeys([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _smKey = 'sm_api_key';
  static const _googleKey = 'google_api_key';

  Future<String?> speechmatics() async =>
      _nz(await _storage.read(key: _smKey)) ?? _nz(AppConfig.smKeyFromDefine);

  Future<String?> google() async =>
      _nz(await _storage.read(key: _googleKey)) ?? _nz(AppConfig.googleKeyFromDefine);

  Future<void> setSpeechmatics(String value) =>
      _storage.write(key: _smKey, value: value.trim());

  Future<void> setGoogle(String value) =>
      _storage.write(key: _googleKey, value: value.trim());

  /// True if the in-app (stored) value is set, regardless of the define fallback.
  Future<bool> hasStoredSpeechmatics() async =>
      _nz(await _storage.read(key: _smKey)) != null;
  Future<bool> hasStoredGoogle() async =>
      _nz(await _storage.read(key: _googleKey)) != null;

  static String? _nz(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
}
