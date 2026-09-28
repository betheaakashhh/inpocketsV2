import 'dart:io';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import 'auth_models.dart';

class AuthRepository {
  AuthRepository({required this.apiClient, required this.tokenStorage});

  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  Future<void> requestOtp(String phoneNumber) {
    return apiClient.post<Map<String, dynamic>>(
      '/auth/request-otp',
      data: {'phone_number': phoneNumber},
      requiresAuth: false,
    );
  }

  /// Verifies the OTP and, on success, persists the resulting session so
  /// every subsequent request is authenticated automatically.
  Future<CurrentUser> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    final data = await apiClient.post<Map<String, dynamic>>(
      '/auth/verify-otp',
      data: {
        'phone_number': phoneNumber,
        'otp': otp,
        'device_name': _deviceName(),
        'device_type': _deviceType(),
      },
      requiresAuth: false,
    );

    await tokenStorage.save(
      StoredSession(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
        accessTokenExpiresAt:
            DateTime.parse(data['access_token_expires_at'] as String),
        refreshTokenExpiresAt:
            DateTime.parse(data['refresh_token_expires_at'] as String),
        userId: data['user_id'] as String,
      ),
    );

    return getMe();
  }

  Future<CurrentUser> getMe() async {
    final data = await apiClient.get<Map<String, dynamic>>('/auth/me');
    return CurrentUser.fromJson(data);
  }

  Future<void> logout() async {
    try {
      await apiClient.post<Map<String, dynamic>>('/auth/logout');
    } finally {
      await tokenStorage.clear();
    }
  }

  Future<List<DeviceSession>> getSessions() async {
    final data = await apiClient.get<Map<String, dynamic>>('/auth/sessions');
    final items = data['sessions'] as List<dynamic>;
    return items
        .map((e) => DeviceSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> revokeOtherSessions() async {
    final data =
        await apiClient.delete<Map<String, dynamic>>('/auth/sessions/others');
    return data['revoked_count'] as int? ?? 0;
  }

  Future<void> revokeSession(String sessionId) {
    return apiClient.delete<Map<String, dynamic>>('/auth/sessions/$sessionId');
  }

  /// Clears local tokens without calling /auth/logout — used when the
  /// refresh token itself has already been rejected by the server, so
  /// there is no valid session left to revoke.
  Future<void> clearLocalSession() => tokenStorage.clear();

  Future<bool> hasStoredSession() async {
    final session = await tokenStorage.read();
    return session != null && !session.isRefreshTokenExpired;
  }

  String _deviceType() => Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'other');

  String _deviceName() {
    // Kept simple and dependency-free; swap for `device_info_plus` if you
    // want the actual model name (e.g. "Pixel 8", "iPhone 15 Pro").
    return Platform.isIOS ? 'iOS device' : (Platform.isAndroid ? 'Android device' : 'Device');
  }
}
