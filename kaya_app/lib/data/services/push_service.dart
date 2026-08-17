import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

/*
    Notifications that arrive when the app is not running.

    The websocket — Reverb or Pusher — only reaches this app while its process
    is alive and holding a connection. Android suspends that process when the
    app is backgrounded and kills it outright when it is swiped out of recents,
    and from that moment nothing the server broadcasts can arrive. FCM is the
    only route left, because the connection is held by Google Play Services
    rather than by us.

    The two do not compete. The socket serves an app in the foreground and
    drives the in-app banner; FCM serves one that is closed and is drawn by
    Android itself.

    Everything here is optional at runtime. Without android/app/google-services.json
    the Firebase plugin is never applied, initialisation throws, and this reports
    unavailable — the app then behaves exactly as it did before push existed.
    That is deliberate: push must be an addition, never a startup dependency.
*/
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  final ApiClient _api = ApiClient();

  bool _available = false;
  String? _token;

  /// Whether Firebase actually came up on this device.
  bool get isAvailable => _available;

  /// The current FCM token, once one exists.
  String? get token => _token;

  /// Brings Firebase up, if it is configured at all.
  ///
  /// Called at start-up, before anyone is signed in — registering the token
  /// with the server is a separate step, because a token is only useful once
  /// we know whose device this is.
  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (e) {
      // No google-services.json, or a build without the plugin. Not an error
      // condition — just no push on this build.
      _available = false;
      debugPrint('[push] unavailable: $e');

      return;
    }

    // A rotated token is a new address for this device. Without re-registering,
    // notifications keep being sent to an address that no longer exists and
    // simply stop arriving, with nothing to show why.
    FirebaseMessaging.instance.onTokenRefresh.listen((refreshed) {
      _token = refreshed;
      registerWithServer();
    });
  }

  /// Asks for permission and registers this device against the signed-in user.
  ///
  /// Android 13 and above will not show a notification until the user grants
  /// it, and the request has to come from the app. On Android 12 and below the
  /// permission is granted implicitly and this returns immediately, so the same
  /// call is correct on every version.
  Future<bool> requestPermissionAndRegister() async {
    if (!_available) return false;

    final settings = await FirebaseMessaging.instance.requestPermission();
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!granted) {
      debugPrint('[push] permission declined');

      return false;
    }

    _token = await FirebaseMessaging.instance.getToken();

    return registerWithServer();
  }

  /// Tells the server where to reach this handset.
  Future<bool> registerWithServer() async {
    final token = _token;
    if (token == null) return false;

    try {
      await _api.post('/device-tokens', data: {
        'token': token,
        'platform': 'android',
      });

      return true;
    } catch (e) {
      debugPrint('[push] register failed: $e');

      return false;
    }
  }

  /// Detaches this device on sign-out.
  ///
  /// Not tidiness. Left registered, the next person to sign in on this handset
  /// keeps receiving the previous account's messages on their lock screen.
  Future<void> unregister() async {
    final token = _token;
    if (token == null) return;

    try {
      // As a query parameter rather than a body: ApiClient.delete carries no
      // payload, and Laravel's validator reads query input just the same.
      await _api.delete('/device-tokens?token=${Uri.encodeComponent(token)}');
    } catch (e) {
      debugPrint('[push] unregister failed: $e');
    }
  }
}
