// lib/core/api/api_client.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — API CLIENT v5.1 (PRODUCTION READY)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import 'api_exceptions.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: Duration(seconds: AppConstants.connectTimeoutSeconds),
      receiveTimeout: Duration(seconds: AppConstants.receiveTimeoutSeconds),
      sendTimeout: Duration(seconds: AppConstants.sendTimeoutSeconds),
      headers: {
        // ✅ FIXED: Added Fallbacks to prevent "Getter not defined" errors
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.addAll([
      _AuthInterceptor(_dio, _secureStorage),
      _LoggingInterceptor(),
      _RetryInterceptor(_dio),
    ]);
  }

  factory ApiClient() {
    _instance ??= ApiClient._internal();
    return _instance!;
  }

  // ── Auth Endpoints ─────────────────────────────────────────────

  Future<Response> login(Map<String, dynamic> data) =>
      _post(AppConstants.loginEndpoint, data, requiresAuth: false);

  Future<Response> register(Map<String, dynamic> data) =>
      _post(AppConstants.registerEndpoint, data, requiresAuth: false);

  Future<Response> refreshToken(String refreshToken) =>
      _post(AppConstants.refreshTokenEndpoint, {'refresh_token': refreshToken}, requiresAuth: false);

  Future<Response> getApiKey() => _get(AppConstants.apiKeyEndpoint);

  // ── ML Endpoints ─────────────────────────────────────────────

  Future<Response> analyzeForDanger(Map<String, dynamic> data) =>
      _post(AppConstants.mlAnalyzeEndpoint, data);

  Future<Response> analyzeAudio(FormData formData) =>
      _postForm(AppConstants.mlAnalyzeAudioEndpoint, formData);

  Future<Response> getAreaRiskScore(double lat, double lng) =>
      _get(AppConstants.areaRiskEndpoint, params: {'lat': lat, 'lng': lng});

  // ── Location & SOS Endpoints ──────────────────────────────────

  Future<Response> updateLocation(Map<String, dynamic> data) =>
      _post(AppConstants.locationUpdateEndpoint, data);

  Future<Response> triggerSOS(Map<String, dynamic> data) =>
      _post(AppConstants.sosTriggerEndpoint, data);

  Future<Response> resolveSOS(String eventId) =>
      _post(AppConstants.sosResolveEndpoint, {'event_id': eventId});

  Future<Response> getSosHistory({int page = 1}) =>
      _get(AppConstants.sosHistoryEndpoint, params: {
        'page': page,
        'limit': AppConstants.pageSize
      });

  // ── Contact Endpoints ──────────────────────────────────────────

  Future<Response> getContacts() => _get(AppConstants.contactsEndpoint);

  Future<Response> addContact(Map<String, dynamic> data) =>
      _post(AppConstants.contactsEndpoint, data);

  Future<Response> updateContact(String id, Map<String, dynamic> data) =>
      _put('${AppConstants.contactsEndpoint}/$id', data);

  Future<Response> deleteContact(String id) =>
      _delete('${AppConstants.contactsEndpoint}/$id');

  // ── Evidence Endpoints ─────────────────────────────────────────

  Future<Response> uploadEvidence(FormData formData) =>
      _postForm(AppConstants.evidenceUploadEndpoint, formData);

  // ── Private HTTP Methods ───────────────────────────────────────

  Future<Response> _get(String path, {Map<String, dynamic>? params}) async {
    try {
      return await _dio.get(path, queryParameters: params);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Response> _post(String path, Map<String, dynamic> data, {bool requiresAuth = true}) async {
    try {
      return await _dio.post(path, data: data, options: Options(extra: {'requiresAuth': requiresAuth}));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Response> _postForm(String path, FormData formData) async {
    try {
      return await _dio.post(path, data: formData, options: Options(contentType: 'multipart/form-data'));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Response> _put(String path, Map<String, dynamic> data) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Response> _delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// INTERCEPTORS
// ═════════════════════════════════════════════════════════════════════════════

class _AuthInterceptor extends Interceptor {
  final Dio _mainDio;
  final FlutterSecureStorage _storage;
  bool _isRefreshing = false;

  _AuthInterceptor(this._mainDio, this._storage);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final requiresAuth = options.extra['requiresAuth'] ?? true;
    if (requiresAuth) {
      final jwt = await _storage.read(key: AppConstants.jwtTokenKey);
      final apiKey = await _storage.read(key: AppConstants.apiKeyStorageKey);

      // ✅ FIXED: Hardcoded header strings to ensure it works even if Constants are missing
      if (jwt != null) options.headers['Authorization'] = 'Bearer $jwt';
      if (apiKey != null) options.headers['X-API-KEY'] = apiKey;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && err.requestOptions.path != AppConstants.refreshTokenEndpoint) {
      if (!_isRefreshing) {
        _isRefreshing = true;
        try {
          final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
          if (refreshToken != null) {
            final refreshDio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));
            final response = await refreshDio.post(AppConstants.refreshTokenEndpoint, data: {'refresh_token': refreshToken});

            final newJwt = response.data['access_token'];
            await _storage.write(key: AppConstants.jwtTokenKey, value: newJwt);

            err.requestOptions.headers['Authorization'] = 'Bearer $newJwt';

            final retryResponse = await _mainDio.fetch(err.requestOptions);
            _isRefreshing = false;
            return handler.resolve(retryResponse);
          }
        } catch (e) {
          _isRefreshing = false;
          await _storage.deleteAll();
          return handler.next(err);
        }
      }
    }
    handler.next(err);
  }
}

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) debugPrint('➡️ [API Request] ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) debugPrint('✅ [API Response] ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) debugPrint('❌ [API Error] ${err.response?.statusCode} ${err.requestOptions.path}');
    handler.next(err);
  }
}

class _RetryInterceptor extends Interceptor {
  final Dio _dio;
  static const int _maxRetries = 3;

  _RetryInterceptor(this._dio);

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = err.requestOptions.extra['retryCount'] ?? 0;
    final isNetworkError = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;

    if (isNetworkError && retryCount < _maxRetries) {
      await Future.delayed(Duration(seconds: retryCount + 1));
      err.requestOptions.extra['retryCount'] = retryCount + 1;
      try {
        final response = await _dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } catch (_) {}
    }
    handler.next(err);
  }
}