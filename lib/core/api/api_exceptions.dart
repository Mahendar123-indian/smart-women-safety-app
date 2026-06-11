// lib/core/api/api_exceptions.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — API EXCEPTION ENGINE v5.0 (202 PRODUCTION)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [FIXED] Dynamic Data Trap: Added type-checks for backend error bodies.
// ✅ [RESILIENCE] Fallback Messaging: Ensures user always sees a helpful hint.
// ✅ [STABILITY] Switch-Case Exhaustion: Handles all DioException types.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final dynamic data;

  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.data,
  });

  factory ApiException.fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const ApiException(
          message: 'Connection timed out. Please check your signal strength.',
          code: 'TIMEOUT',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          message: AppConstants.networkError,
          code: 'NO_CONNECTION',
        );
      case DioExceptionType.badResponse:
        return ApiException._fromResponse(e.response);
      case DioExceptionType.cancel:
        return const ApiException(
            message: 'The request was cancelled.',
            code: 'CANCELLED'
        );
      case DioExceptionType.badCertificate:
        return const ApiException(
          message: 'Secure connection failed. Potential network interference.',
          code: 'SSL_ERROR',
        );
      default:
        return ApiException(
          message: e.message ?? AppConstants.unknownError,
          code: 'NETWORK_GENERIC',
        );
    }
  }

  factory ApiException._fromResponse(Response? response) {
    if (response == null) {
      return const ApiException(
          message: AppConstants.serverError,
          code: 'NO_RESPONSE_DATA'
      );
    }

    final statusCode = response.statusCode;
    final dynamic data = response.data;
    String message = AppConstants.serverError;

    // ✅ FIXED: Safer extraction of error messages from diverse backend payloads
    if (data is Map<String, dynamic>) {
      message = data['message']?.toString() ??
          data['error']?.toString() ??
          data['detail']?.toString() ??
          message;
    } else if (data is String && data.isNotEmpty) {
      message = data;
    }

    return switch (statusCode) {
      400 => ApiException(message: message, statusCode: 400, code: 'BAD_REQUEST', data: data),
      401 => const ApiException(message: AppConstants.authError, statusCode: 401, code: 'UNAUTHORIZED'),
      403 => const ApiException(message: 'Access denied. You do not have permission.', statusCode: 403, code: 'FORBIDDEN'),
      404 => const ApiException(message: 'The requested resource was not found.', statusCode: 404, code: 'NOT_FOUND'),
      409 => ApiException(message: message, statusCode: 409, code: 'CONFLICT', data: data),
      422 => ApiException(message: message, statusCode: 422, code: 'VALIDATION_FAILED', data: data),
      429 => const ApiException(message: 'Too many requests. Please wait a moment.', statusCode: 429, code: 'RATE_LIMITED'),
      500 => const ApiException(message: AppConstants.serverError, statusCode: 500, code: 'INTERNAL_SERVER_ERROR'),
      502 || 503 || 504 => const ApiException(message: 'Server is temporarily unavailable.', statusCode: 502, code: 'SERVER_OFFLINE'),
      _ => ApiException(message: message, statusCode: statusCode, code: 'UNHANDLED_HTTP_ERROR'),
    };
  }

  @override
  String toString() => message; // Cleaner for UI Snackbars
}