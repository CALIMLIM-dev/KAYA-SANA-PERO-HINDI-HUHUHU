import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';








/// Central Dio-based HTTP client for all API calls.
/// Base URL points to the Laravel backend at /api/v1/
class ApiClient {
  /*
      Where the backend lives, supplied at build time:

        flutter build apk --dart-define=API_BASE_URL=https://your-host

      This was a hardcoded ngrok URL, which meant every APK was welded to one
      tunnel. Restarting ngrok — or moving to real hosting — broke every copy
      already installed on a tester's phone, with no way to fix it except
      building and distributing a new APK.

      The old tunnel stays as the default so existing build commands keep
      working. Pass the flag and nothing else has to change.
  */
  static const String _host = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://bullring-glorified-observing.ngrok-free.dev',
  );

  /// Trailing slashes are easy to paste in and would produce `//api/v1`.
  static String get _root =>
      _host.endsWith('/') ? _host.substring(0, _host.length - 1) : _host;

  static String get _baseUrl => '$_root/api/v1';
  static String get storageUrl => '$_root/storage';

  /// The server root, for code that cannot use this client.
  ///
  /// The background service runs in its own isolate with a plain HttpClient —
  /// it has no Dio instance and no access to the compile-time define, so the
  /// address has to be handed to it.
  static String get root => _root;

  /// ngrok serves an interstitial warning page to unknown browsers, and that
  /// HTML arrives where JSON is expected. Only needed while a tunnel is the
  /// host — harmless elsewhere, so it is sent when the host looks like ngrok
  /// rather than always.
  static bool get _isTunnel => _root.contains('ngrok');

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
      if (_isTunnel) 'ngrok-skip-browser-warning': 'true',
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
        if (error.response?.statusCode == 401 &&
            !_isAuthPath(error.requestOptions.path)) {
          /*
              The token is dead. Nothing this session does will work again.

              This used to do nothing at all, so the app stayed "logged in"
              while every authenticated request quietly failed. The location
              picker was where people noticed — you type and no suggestions
              appear — but saved jobs, applications and messages were equally
              broken, and the only cure anyone found was clearing app data,
              which wipes the token and forces a fresh login.

              Auth endpoints are excluded: a 401 from /login means the password
              was wrong, not that the session expired.
          */
          onUnauthorized?.call();
        }
        return handler.next(error);
      },
    ));
  }

  /// Called once when a request fails because the session is no longer valid.
  ///
  /// A plain callback rather than a navigator key, so this file stays free of
  /// Flutter navigation and can be used from tests and providers alike.
  static void Function()? onUnauthorized;

  /// Paths where a 401 is a legitimate answer rather than an expired session.
  static bool _isAuthPath(String path) {
    const authPaths = [
      '/login',
      '/register',
      '/google-login',
      '/forgot-password',
      '/verify-reset-code',
      '/reset-password',
      /*
          Logout belongs here even though it is an authenticated route.

          logout() deletes the token locally first — that part must not depend
          on the network — and only then fires the server revoke. That request
          therefore goes out with no token and comes back 401, which is the
          expected outcome, not an expired session.

          Treated as a session expiry it fired the redirect below while the
          profile screen was already navigating to login, so two page
          transitions ran over each other. That was the glitch on sign-out.
      */
      '/logout',
    ];
    return authPaths.any(path.endsWith);
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

  // ── Realtime ────────────────────────────────────────────────────────────────

  /// Where the WebSocket server lives.
  ///
  /// Fetched rather than compiled in: the Reverb host and port differ between
  /// local XAMPP, ngrok and production, and baking them into the binary would
  /// make a deployment detail require a store release.
  Future<Map<String, dynamic>?> getRealtimeConfig() async {
    final response = await get('/realtime/config');
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    return null;
  }

  /// Asks the server to sign a private-channel subscription.
  ///
  /// Returns null when the server refuses — which is a normal outcome, not an
  /// error: it is exactly what happens when a worker revokes location sharing
  /// while the employer still has the map open.
  ///
  /// Note the path: broadcasting auth sits at `/api/broadcasting/auth`, outside
  /// the `/api/v1` prefix this client is built around, so it is addressed
  /// absolutely.
  Future<String?> authorizeChannel({
    required String channelName,
    required String socketId,
  }) async {
    final base = _baseUrl.replaceFirst(RegExp(r'/v1/?$'), '');

    try {
      final response = await _dio.post(
        '$base/broadcasting/auth',
        data: {'socket_id': socketId, 'channel_name': channelName},
      );

      final data = response.data;
      if (data is Map && data['auth'] is String) return data['auth'] as String;
      return null;
    } on DioException catch (e) {
      // 403 means "you may not listen to this", which the caller handles by
      // simply not subscribing.
      if (e.response?.statusCode == 403) return null;
      rethrow;
    }
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

    final path = e.requestOptions.path;

    switch (status) {
      // Only a sign-in attempt can be answered with "wrong password". Every
      // other 401 means the session died, and saying "Incorrect email or
      // password" while someone types into a location field is nonsense.
      case 401:
        return Exception(message ??
            (_isAuthPath(path)
                ? 'Incorrect email or password'
                : 'Your session has expired. Please sign in again.'));
      case 403:
        return Exception(message ?? 'Your account has been suspended. Contact support.');
      // Likewise: a 404 is only about an account on the auth paths.
      case 404:
        return Exception(message ??
            (_isAuthPath(path)
                ? 'No account found with that email.'
                : 'Not found.'));
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
