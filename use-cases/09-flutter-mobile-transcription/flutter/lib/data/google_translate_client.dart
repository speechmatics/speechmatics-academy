import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';

class TranslateException implements Exception {
  TranslateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Google Cloud Translation v2 (Basic) client. Translates a list of strings,
/// batching to stay under the per-request limits (<=128 strings / ~28k chars).
/// Source language is omitted by default (auto-detect) since transcripts are
/// multilingual.
class GoogleTranslateClient {
  GoogleTranslateClient({required this.apiKey, http.Client? client})
      : _http = client ?? http.Client();

  final String apiKey;
  final http.Client _http;

  static const _maxStrings = 128;
  static const _maxChars = 28000;

  Future<List<String>> translate({
    required List<String> q,
    required String target,
    String? source,
    String format = 'text',
  }) async {
    if (q.isEmpty) return [];
    final out = <String>[];
    for (final batch in _batches(q)) {
      final resp = await _http.post(
        Uri.parse('${AppConfig.googleTranslateUrl}?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'q': batch,
          'target': target,
          if (source != null) 'source': source,
          'format': format,
        }),
      );
      if (resp.statusCode != 200) {
        throw TranslateException(_friendly(resp));
      }
      final data = (jsonDecode(resp.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      final translations = data['translations'] as List;
      out.addAll(translations.map((t) => _unescape((t['translatedText'] ?? '').toString())));
    }
    return out;
  }

  Iterable<List<String>> _batches(List<String> q) sync* {
    var batch = <String>[];
    var chars = 0;
    for (final s in q) {
      if (batch.isNotEmpty && (batch.length >= _maxStrings || chars + s.length > _maxChars)) {
        yield batch;
        batch = [];
        chars = 0;
      }
      batch.add(s);
      chars += s.length;
    }
    if (batch.isNotEmpty) yield batch;
  }

  String _friendly(http.Response resp) {
    String detail = resp.body;
    try {
      final m = jsonDecode(resp.body);
      if (m is Map && m['error'] is Map && m['error']['message'] != null) {
        detail = m['error']['message'].toString();
      }
    } catch (_) {}
    if (detail.length > 300) detail = '${detail.substring(0, 300)}…';
    return 'Translation failed (HTTP ${resp.statusCode}): $detail';
  }

  // format:text usually returns plain text, but unescape common entities just in case.
  String _unescape(String s) => s
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  void dispose() => _http.close();
}
