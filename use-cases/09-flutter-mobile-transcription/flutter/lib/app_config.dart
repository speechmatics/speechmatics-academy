/// Endpoints + tunables for the two API clients.
class AppConfig {
  AppConfig._();

  static const pollInterval = Duration(seconds: 3);
  // Large files (an hour of audio + speech-intelligence add-ons) can take
  // well over 10 minutes to process — give them headroom.
  static const pollTimeout = Duration(minutes: 30);
  // Consecutive failed poll requests tolerated before giving up (~2 min of
  // grace with backoff) — covers screen-lock/Doze network suspensions.
  static const maxPollFailures = 8;

  /// Speechmatics batch base for a region ('eu1' or 'us1').
  static String speechmaticsBase(String region) =>
      'https://${region == 'us1' ? 'us1' : 'eu1'}.asr.api.speechmatics.com/v2';

  /// Speechmatics RT websocket base for an endpoint mode.
  /// 'auto' uses the global endpoint, which routes each connection to the
  /// nearest region for the lowest latency — no hard-coded region needed.
  static String rtBase(String endpointMode) => switch (endpointMode) {
        'eu' => 'wss://eu.rt.speechmatics.com/v2',
        'us' => 'wss://us.rt.speechmatics.com/v2',
        _ => 'wss://global.rt.speechmatics.com/v2',
      };

  // RT session tunables.
  static const rtChunkBytes = 4096;
  static const rtConnectTimeout = Duration(seconds: 10);
  static const rtStartTimeout = Duration(seconds: 10); // RecognitionStarted wait
  static const rtFinishTimeout = Duration(seconds: 5); // EndOfTranscript wait

  static const googleTranslateUrl =
      'https://translation.googleapis.com/language/translate/v2';

  // Optional build-time keys: flutter run --dart-define=SM_API_KEY=... --dart-define=GOOGLE_API_KEY=...
  static const smKeyFromDefine = String.fromEnvironment('SM_API_KEY');
  static const googleKeyFromDefine = String.fromEnvironment('GOOGLE_API_KEY');
}
