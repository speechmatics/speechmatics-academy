/// Web stub — the live pipeline never runs on web (no CORS on the
/// Speechmatics batch API), so audio persistence is inert there.
class AudioStore {
  AudioStore._();

  static Future<String> save({
    required String itemId,
    required List<int> bytes,
    required String sourceFilename,
  }) async =>
      throw UnsupportedError('Audio persistence is not supported on this platform.');

  static Future<String?> resolve(String? audioFile) async => null;

  static Future<void> delete(String? audioFile) async {}

  static Future<List<double>?> loadWaveform(String audioFile) async => null;

  static Future<void> saveWaveform(String audioFile, int sampleCount, List<double> data) async {}
}
