/// A normalized error the UI layer can always rely on, regardless of
/// which of the backend's two error shapes produced it:
///   • FastAPI's default:      {"detail": "message"} or
///                              {"detail": [{"msg": "...", ...}, ...]}
///   • The app's AppException handler: {"error": {"code","message","request_id"}}
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.requestId,
    this.isNetworkError = false,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final String? requestId;

  /// True for connectivity failures (no internet, DNS, timeout) where
  /// there was never a server response to parse.
  final bool isNetworkError;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isRateLimited => statusCode == 429;
  bool get isServerError => (statusCode ?? 0) >= 500;

  factory ApiException.network([String? detail]) => ApiException(
        message: detail ??
            "Can't reach InPockets right now. Check your connection and "
                'try again.',
        isNetworkError: true,
      );

  factory ApiException.unexpected([String? detail]) => ApiException(
        message: detail ?? 'Something went wrong on our end. Please retry.',
      );

  static ApiException fromResponse({
    required int? statusCode,
    required dynamic data,
  }) {
    String? message;
    String? code;
    String? requestId;

    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        message = error['message'] as String?;
        code = error['code'] as String?;
        requestId = error['request_id'] as String?;
      }

      final detail = data['detail'];
      if (message == null && detail is String) {
        message = detail;
      } else if (message == null && detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) {
          message = first['msg'] as String;
        }
      }
    }

    message ??= _fallbackForStatus(statusCode);

    return ApiException(
      message: message,
      statusCode: statusCode,
      code: code,
      requestId: requestId,
    );
  }

  static String _fallbackForStatus(int? statusCode) {
    switch (statusCode) {
      case 400:
        return 'That request looks invalid. Please check and try again.';
      case 401:
        return 'Your session has expired. Please log in again.';
      case 403:
        return "You don't have permission to do that.";
      case 404:
        return "We couldn't find what you're looking for.";
      case 429:
        return "You've tried that a few too many times. Please wait a bit.";
      case 502:
      case 503:
        return 'A verification service is temporarily unavailable. '
            'Please try again shortly.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}
