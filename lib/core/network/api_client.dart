import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final bool isNetworkError;

  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.isNetworkError = false,
  });

  @override
  String toString() => message;
}

class TokenStorage {
  static const _accessKey = 'wf_access_token';
  static const _refreshKey = 'wf_refresh_token';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await _secureStorage.write(key: _accessKey, value: accessToken);
      await _secureStorage.write(key: _refreshKey, value: refreshToken);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessKey, accessToken);
      await prefs.setString(_refreshKey, refreshToken);
    }
  }

  Future<String?> getAccessToken() async {
    try {
      final val = await _secureStorage.read(key: _accessKey);
      if (val != null) return val;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  Future<String?> getRefreshToken() async {
    try {
      final val = await _secureStorage.read(key: _refreshKey);
      if (val != null) return val;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshKey);
  }

  Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(key: _accessKey);
      await _secureStorage.delete(key: _refreshKey);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }
}

class ApiClient {
  late final Dio _dio;
  final TokenStorage tokenStorage;

  ApiClient({TokenStorage? storage})
    : tokenStorage = storage ?? TokenStorage() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.baseUrl = AppConfig.apiBaseUrl;
          final token = await tokenStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.response?.data is Map &&
              error.response?.data['code'] == 'TOKEN_EXPIRED' &&
              !error.requestOptions.path.contains('/auth/refresh')) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              final newToken = await tokenStorage.getAccessToken();
              error.requestOptions.headers['Authorization'] =
                  'Bearer $newToken';
              try {
                final retryResponse = await _dio.fetch(error.requestOptions);
                return handler.resolve(retryResponse);
              } catch (_) {}
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;
      final refreshDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
      final res = await refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      if (res.statusCode == 200 && res.data['success'] == true) {
        final newAccess = res.data['data']['accessToken'] as String;
        await tokenStorage.saveTokens(
          accessToken: newAccess,
          refreshToken: refreshToken,
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post(path, data: data);
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.put(path, data: data);
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.patch(path, data: data);
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<Map<String, dynamic>> delete(String path) async {
    try {
      final response = await _dio.delete(path);
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  ApiException testMapDioError(DioException e) => _mapDioError(e);

  ApiException _mapDioError(DioException e) {
    final messageLower = (e.message ?? '').toLowerCase();
    final errorLower = (e.error?.toString() ?? '').toLowerCase();
    final isBrowserFetchError =
        messageLower.contains('failed to fetch') ||
        errorLower.contains('failed to fetch') ||
        messageLower.contains('xmlhttprequest') ||
        errorLower.contains('xmlhttprequest') ||
        messageLower.contains('connection refused') ||
        errorLower.contains('connection refused');

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError ||
        isBrowserFetchError) {
      return ApiException(
        message:
            'Unable to connect to WaterFix server (${AppConfig.apiBaseUrl}). Please ensure the backend is running and reachable.',
        isNetworkError: true,
      );
    }
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    if (data is Map) {
      final msg = (data['message'] ?? 'Request failed').toString();
      final cleanMsg = msg.trim().toLowerCase() == 'fetch failed'
          ? 'Safepay gateway connection timed out or failed to respond. Please retry.'
          : msg;
      return ApiException(
        message: cleanMsg,
        statusCode: statusCode,
        code: data['code']?.toString(),
      );
    }
    return ApiException(
      message: e.message ?? 'An unexpected error occurred.',
      statusCode: statusCode,
    );
  }
}
