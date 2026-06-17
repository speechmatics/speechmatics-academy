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

  static const googleTranslateUrl =
      'https://translation.googleapis.com/language/translate/v2';

  // Optional build-time keys: flutter run --dart-define=SM_API_KEY=... --dart-define=GOOGLE_API_KEY=...
  static const smKeyFromDefine = String.fromEnvironment('SM_API_KEY');
  static const googleKeyFromDefine = String.fromEnvironment('GOOGLE_API_KEY');
}
