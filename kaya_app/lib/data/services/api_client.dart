import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';








/// Central Dio-based HTTP client for all API calls.
/// Base URL points to the Laravel backend at /api/v1/
class ApiClient {
  static const String _baseUrl = 'https://bullring-glorified-observing.ngrok-free.dev/api/v1';
static const String storageUrl = 'https://bullring-glorified-observing.ngrok-free.dev/storage';

  /// Build full URL for a stored file path (e.g. "worker_photos/abc.jpg")
  static String fileUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$storageUrl/$path';
  }

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';

  late final Dio _dio;

  
  
  
  
  
  
  
  
  ApiClient() {
  _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true', // ← ADD THIS LINE
    },
  ));

    // Inject auth token on every request
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        return handler.next(error);
      },
    ));
  }

  // ── Token management ────────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  static Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  // ── HTTP helpers ─────────────────────────────────────────────────────────────

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> patch(String path, {dynamic data}) async {
    try {
      return await _dio.patch(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> postMultipart(String path, FormData formData) async {
    try {
      return await _dio.post(
        path,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Error handling ────────────────────────────────────────────────────────────

  Exception _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return Exception('No internet connection. Please check your network.');
    }

    final status = e.response?.statusCode;
    final message = e.response?.data?['message'] as String?;

    switch (status) {
      case 401:
        return Exception(message ?? 'Incorrect email or password');
      case 403:
        return Exception(message ?? 'Your account has been suspended. Contact support.');
      case 404:
        return Exception(message ?? 'No account found with that email.');
      case 422:
        // Validation errors — extract first error message
        final errors = e.response?.data?['errors'];
        if (errors is Map) {
          final firstError = (errors.values.first as List).first.toString();
          return Exception(firstError);
        }
        return Exception(message ?? 'Validation error.');
      case 500:
        return Exception('Server error. Please try again later.');
      default:
        return Exception(message ?? 'Something went wrong.');
    }
  }
}
