import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A session persisted on-device. Access tokens are short-lived (15 min
/// server-side) so [accessTokenExpiresAt] lets the interceptor refresh
/// *before* a request would otherwise fail with a 401.
class StoredSession {
  const StoredSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
    required this.userId,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;
  final String userId;

  bool get isAccessTokenExpired =>
      DateTime.now().isAfter(accessTokenExpiresAt);

  bool get isRefreshTokenExpired =>
      DateTime.now().isAfter(refreshTokenExpiresAt);
}

/// Wraps [FlutterSecureStorage] so the rest of the app never touches raw
/// keys. Tokens never touch disk unencrypted: iOS uses the Keychain,
/// Android uses Keystore-backed EncryptedSharedPreferences.
class TokenStorage {
  TokenStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'ip_access_token';
  static const _kRefreshToken = 'ip_refresh_token';
  static const _kAccessExpiresAt = 'ip_access_expires_at';
  static const _kRefreshExpiresAt = 'ip_refresh_expires_at';
  static const _kUserId = 'ip_user_id';

  Future<void> save(StoredSession session) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: session.accessToken),
      _storage.write(key: _kRefreshToken, value: session.refreshToken),
      _storage.write(
        key: _kAccessExpiresAt,
        value: session.accessTokenExpiresAt.toIso8601String(),
      ),
      _storage.write(
        key: _kRefreshExpiresAt,
        value: session.refreshTokenExpiresAt.toIso8601String(),
      ),
      _storage.write(key: _kUserId, value: session.userId),
    ]);
  }

  Future<StoredSession?> read() async {
    final values = await Future.wait([
      _storage.read(key: _kAccessToken),
      _storage.read(key: _kRefreshToken),
      _storage.read(key: _kAccessExpiresAt),
      _storage.read(key: _kRefreshExpiresAt),
      _storage.read(key: _kUserId),
    ]);

    final accessToken = values[0];
    final refreshToken = values[1];
    final accessExpiresAt = values[2];
    final refreshExpiresAt = values[3];
    final userId = values[4];

    if (accessToken == null ||
        refreshToken == null ||
        accessExpiresAt == null ||
        refreshExpiresAt == null ||
        userId == null) {
      return null;
    }

    return StoredSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: DateTime.parse(accessExpiresAt),
      refreshTokenExpiresAt: DateTime.parse(refreshExpiresAt),
      userId: userId,
    );
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kAccessExpiresAt),
      _storage.delete(key: _kRefreshExpiresAt),
      _storage.delete(key: _kUserId),
    ]);
  }
}
