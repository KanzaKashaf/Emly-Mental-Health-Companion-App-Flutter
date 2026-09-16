import 'package:dio/dio.dart';

class ApiError implements Exception {
  final String message;
  final Map<String, List<String>>? fieldErrors;
  final int? statusCode;
  final String? code;

  ApiError({
    required this.message,
    this.fieldErrors,
    this.statusCode,
    this.code,
  });

  factory ApiError.fromJson(Map<String, dynamic> json, {int? statusCode}) {
    // Your backend format:
    // {
    //   "error": {
    //     "code": "http_error",
    //     "message": "Email already exists",
    //     "details": [...]
    //   }
    // }
    final backendError = json['error'];

    if (backendError is Map) {
      final errorCode = backendError['code']?.toString();
      final backendMessage =
          backendError['message']?.toString() ?? 'Something went wrong';

      final details = backendError['details'];
      final parsedFieldErrors = _parseDetails(details);

      return ApiError(
        message: _friendlyMessage(backendMessage),
        fieldErrors: parsedFieldErrors,
        statusCode: statusCode,
        code: errorCode,
      );
    }

    // FastAPI fallback:
    // { "detail": "..." }
    // { "detail": [ ... validation errors ... ] }
    final detail = json['detail'];

    if (detail is String) {
      return ApiError(
        message: _friendlyMessage(detail),
        statusCode: statusCode,
        code: 'http_error',
      );
    }

    if (detail is List) {
      final parsedFieldErrors = _parseDetails(detail);

      return ApiError(
        message: _firstFieldError(parsedFieldErrors) ?? 'Validation error',
        fieldErrors: parsedFieldErrors,
        statusCode: statusCode,
        code: 'validation_error',
      );
    }

    // Other fallback:
    // { "message": "..." }
    final message = json['message'];
    if (message != null) {
      return ApiError(
        message: _friendlyMessage(message.toString()),
        statusCode: statusCode,
        code: 'http_error',
      );
    }

    return ApiError(
      message: 'Something went wrong. Please try again.',
      statusCode: statusCode,
      code: 'unknown',
    );
  }

  factory ApiError.fromDio(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;

    // Timeout errors
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return ApiError(
        message: 'Connection timed out. Please check your internet.',
        statusCode: 0,
        code: 'network_error',
      );
    }

    // No internet / DNS / server unreachable
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown) {
      return ApiError(
        message: 'Network error. Please check your connection.',
        statusCode: 0,
        code: 'network_error',
      );
    }

    // Backend returned JSON error
    if (data is Map<String, dynamic>) {
      return ApiError.fromJson(data, statusCode: statusCode);
    }

    // Backend returned plain text
    if (data is String && data.trim().isNotEmpty) {
      return ApiError(
        message: _friendlyMessage(data),
        statusCode: statusCode,
        code: 'http_error',
      );
    }

    // Server error
    if (statusCode != null && statusCode >= 500) {
      return ApiError(
        message: 'Server error. Please try again later.',
        statusCode: statusCode,
        code: 'server_error',
      );
    }

    return ApiError(
      message: 'Something went wrong. Please try again.',
      statusCode: statusCode,
      code: 'unknown',
    );
  }

  static Map<String, List<String>>? _parseDetails(dynamic details) {
    if (details is! List) return null;

    final Map<String, List<String>> errors = {};

    for (final item in details) {
      if (item is Map) {
        final msg = (item['msg'] ?? 'Invalid value').toString();
        final loc = item['loc'];

        String field = 'general';

        if (loc is List && loc.isNotEmpty) {
          field = loc.last.toString();
        }

        errors.putIfAbsent(field, () => []);
        errors[field]!.add(msg);
      }
    }

    return errors.isEmpty ? null : errors;
  }

  static String? _firstFieldError(Map<String, List<String>>? errors) {
    if (errors == null || errors.isEmpty) return null;

    final first = errors.entries.first;
    final field = first.key;
    final messages = first.value;

    if (messages.isEmpty) return null;

    if (field == 'general') return messages.first;

    return '${_prettyFieldName(field)}: ${messages.first}';
  }

  static String _prettyFieldName(String field) {
    switch (field) {
      case 'dateOfBirth':
        return 'Date of birth';
      case 'profileImage':
        return 'Profile image';
      default:
        if (field.isEmpty) return 'Field';
        return field[0].toUpperCase() + field.substring(1);
    }
  }

  static String _friendlyMessage(String message) {
    final msg = message.trim();

    // Technical auth errors: user should not see raw backend wording
    switch (msg) {
      case 'Missing Authorization Bearer token':
      case 'Invalid token':
      case 'Invalid token type':
      case 'Invalid refresh token payload':
      case 'Refresh token revoked':
      case 'Refresh token expired':
        return 'Your session has expired. Please log in again.';

      case 'Account disabled':
        return 'Your account has been disabled. Please contact support.';

      default:
        break;
    }

    if (msg.startsWith('Invalid Google token')) {
      return 'Google sign-in failed. Please try again.';
    }

    if (msg.startsWith('Invalid reset token')) {
      return 'Reset link expired. Request a new code.';
    }

    if (msg.startsWith('Failed to send email')) {
      return 'Email service unavailable. Try again later.';
    }

    // Most backend messages are already user-friendly
    return msg.isNotEmpty ? msg : 'Something went wrong. Please try again.';
  }

  bool get isNetworkError => statusCode == 0;
  bool get isAuthError => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isValidation => statusCode == 422;
  bool get isRateLimit => statusCode == 429;
  bool get isServerError => statusCode != null && statusCode! >= 500;

  String? fieldError(String fieldName) {
    final list = fieldErrors?[fieldName];
    if (list == null || list.isEmpty) return null;
    return list.first;
  }

  @override
  String toString() {
    return 'ApiError(statusCode: $statusCode, code: $code, message: $message, fieldErrors: $fieldErrors)';
  }
}