import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Marks a request as not requiring an Authorization header (login, OTP,
/// refresh) — set via Dio's `extra` map since Dio has no first-class
/// concept of "public" endpoints.
const _kSkipAuthKey = 'skip_auth';
const _kSkipRefreshRetryKey = 'skip_refresh_retry';

/// Thin, typed wrapper around [Dio] that is the *only* place in the app
/// allowed to talk to the network. Every repository goes through this.
///
/// Responsibilities:
///  • Attach the current access token to every authenticated request.
///  • On a 401, transparently refresh the session (once, even if several
///    requests 401 at the same moment — single-flight via [_refreshLock])
///    and retry the original request exactly once.
///  • If refreshing itself fails (refresh token expired / reuse
///    detected), call [onSessionExpired] so the app can force a clean
///    logout instead of getting stuck in a retry loop.
///  • Normalize every failure into [ApiException].
class ApiClient {
  ApiClient({required this.tokenStorage, required this.onSessionExpired}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiV1BaseUrl,
        connectTimeout: AppConfig.requestTimeout,
        receiveTimeout: AppConfig.requestTimeout,
        sendTimeout: AppConfig.requestTimeout,
        contentType: 'application/json',
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );

    if (AppConfig.enableVerboseNetworkLogs) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (o) => developer.log(o.toString(), name: 'inpockets.net'),
        ),
      );
    }
  }

  late final Dio _dio;
  final TokenStorage tokenStorage;

  /// Invoked when the refresh token itself is no longer valid. The app
  /// should clear all local session state and route back to the login
  /// flow when this fires.
  final Future<void> Function() onSessionExpired;

  Completer<bool>? _refreshLock;

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['X-Client'] = 'inpockets-flutter';

    final skipAuth = options.extra[_kSkipAuthKey] == true;
    if (!skipAuth) {
      final session = await tokenStorage.read();
      if (session != null) {
        options.headers['Authorization'] = 'Bearer ${session.accessToken}';
      }
    }

    handler.next(options);
  }

  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final requestOptions = err.requestOptions;

    final isConnectivityFailure = response == null &&
        (err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.receiveTimeout ||
            err.type == DioExceptionType.sendTimeout ||
            err.type == DioExceptionType.connectionError);

    if (isConnectivityFailure) {
      handler.reject(
        DioException(
          requestOptions: requestOptions,
          error: ApiException.network(),
          type: err.type,
        ),
      );
      return;
    }

    final statusCode = response?.statusCode;
    final skipRefreshRetry = requestOptions.extra[_kSkipRefreshRetryKey] == true;
    final alreadyRetried = requestOptions.extra['retried'] == true;

    if (statusCode == 401 && !skipRefreshRetry && !alreadyRetried) {
      final refreshed = await _refreshSession();

      if (refreshed) {
        try {
          final retryResponse = await _retry(requestOptions);
          handler.resolve(retryResponse);
          return;
        } on DioException catch (retryError) {
          handler.next(retryError);
          return;
        }
      } else {
        await onSessionExpired();
      }
    }

    handler.next(
      DioException(
        requestOptions: requestOptions,
        response: response,
        error: ApiException.fromResponse(
          statusCode: statusCode,
          data: response?.data,
        ),
        type: err.type,
      ),
    );
  }

  Future<Response<dynamic>> _retry(RequestOptions options) {
    final retryOptions = options.copyWith(
      extra: {...options.extra, 'retried': true},
    );
    return _dio.fetch(retryOptions);
  }

  /// Ensures only one refresh call is ever in flight, even if multiple
  /// requests 401 in the same instant (e.g. a screen firing three
  /// parallel GETs right as the access token expires).
  Future<bool> _refreshSession() {
    final existingLock = _refreshLock;
    if (existingLock != null) {
      return existingLock.future;
    }

    final lock = Completer<bool>();
    _refreshLock = lock;

    () async {
      try {
        final session = await tokenStorage.read();
        if (session == null || session.isRefreshTokenExpired) {
          lock.complete(false);
          return;
        }

        final response = await _dio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refresh_token': session.refreshToken},
          options: Options(extra: {_kSkipAuthKey: true, _kSkipRefreshRetryKey: true}),
        );

        final data = response.data!;
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
        lock.complete(true);
      } catch (_) {
        lock.complete(false);
      } finally {
        _refreshLock = null;
      }
    }();

    return lock.future;
  }

  Future<T> _unwrap<T>(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      return response.data as T;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.unexpected(e.message);
    }
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool requiresAuth = true,
  }) {
    return _unwrap<T>(
      () => _dio.get<dynamic>(
        path,
        queryParameters: query,
        options: Options(extra: {_kSkipAuthKey: !requiresAuth}),
      ),
    );
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    bool requiresAuth = true,
  }) {
    return _unwrap<T>(
      () => _dio.post<dynamic>(
        path,
        data: data,
        options: Options(extra: {_kSkipAuthKey: !requiresAuth}),
      ),
    );
  }

  Future<T> put<T>(
    String path, {
    dynamic data,
    bool requiresAuth = true,
  }) {
    return _unwrap<T>(
      () => _dio.put<dynamic>(
        path,
        data: data,
        options: Options(extra: {_kSkipAuthKey: !requiresAuth}),
      ),
    );
  }

  Future<T> patch<T>(
    String path, {
    dynamic data,
    bool requiresAuth = true,
  }) {
    return _unwrap<T>(
      () => _dio.patch<dynamic>(
        path,
        data: data,
        options: Options(extra: {_kSkipAuthKey: !requiresAuth}),
      ),
    );
  }

  Future<T> delete<T>(
    String path, {
    dynamic data,
    bool requiresAuth = true,
  }) {
    return _unwrap<T>(
      () => _dio.delete<dynamic>(
        path,
        data: data,
        options: Options(extra: {_kSkipAuthKey: !requiresAuth}),
      ),
    );
  }

  /// Multipart upload — used for adding a new version of an existing
  /// document family (see DocumentsRepository).
  Future<T> postMultipart<T>(
    String path, {
    required FormData formData,
  }) {
    return _unwrap<T>(() => _dio.post<dynamic>(path, data: formData));
  }

  /// Raw bytes response (e.g. GET /documents/{id}/content).
  Future<List<int>> getBytes(String path) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? const [];
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.unexpected(e.message);
    }
  }
}
