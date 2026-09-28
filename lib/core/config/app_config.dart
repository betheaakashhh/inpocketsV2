/// Central place for every environment-dependent value in the app.
///
/// The InPockets backend (FastAPI) is expected to be reachable at
/// [apiBaseUrl]. During local development it listens on port 8000
/// (see the backend's docker-compose.yml).
///
/// IMPORTANT — picking the right host for local development:
///   • Android emulator  -> http://10.0.2.2:8000        (10.0.2.2 is the
///                          emulator's alias for your host machine)
///   • iOS simulator     -> http://127.0.0.1:8000
///   • Physical device   -> http://<your-computer-LAN-IP>:8000
///                          (phone and computer must be on the same Wi-Fi)
///
/// Override at build/run time without touching this file:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8000
class AppConfig {
  AppConfig._();

  static const String _defaultBaseUrl = 'http://10.0.2.2:8000';

  /// Base URL of the InPockets backend, *without* a trailing slash and
  /// *without* the `/api/v1` suffix — that's added by [apiV1BaseUrl].
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static String get apiV1BaseUrl => '$apiBaseUrl/api/v1';

  /// How long a full request (connect + send + receive) may take before
  /// the app gives up and shows a retry state.
  static const Duration requestTimeout = Duration(seconds: 20);

  /// Matches the backend's ACCESS_TOKEN_EXPIRY_MINUTES (15 min). We refresh
  /// a little early so an in-flight request never races token expiry.
  static const Duration accessTokenRefreshSkew = Duration(minutes: 1);

  static const bool enableVerboseNetworkLogs = bool.fromEnvironment(
    'VERBOSE_LOGS',
    defaultValue: false,
  );
}
