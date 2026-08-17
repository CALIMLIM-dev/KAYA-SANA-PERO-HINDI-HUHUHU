import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

/*
    Work that outlives the app.

    Android kills the process when the app is swiped out of recents, and every
    timer, socket and isolate goes with it. Geolocator's own
    foregroundNotificationConfig survives backgrounding and screen-lock but not
    that, because it still runs inside the app's engine — which is exactly the
    gap that made location sharing stop the moment a worker cleared their
    recents.

    A foreground service is different. It runs in its own isolate under
    START_STICKY, so Android restarts it if it is killed and swiping the task
    away does not take it down. That is the only mechanism available here for
    keeping anything alive without a third-party push service.

    It does two jobs while it runs, and it only runs during an active hire:

      - reports the worker's position, which is the feature it exists for
      - polls for new notifications and raises them on the phone's shade

    The second is close to free. The service is already awake for the first, so
    a small request every twenty seconds is what gives a closed app a working
    notification during the window where coordination actually matters. Outside
    an active job the service does not run, because a permanent background
    poller is a battery and policy problem rather than a feature.

    Everything here runs in a *separate isolate* with no access to the app's
    providers, so configuration is handed over at start-up and HTTP is done
    with a plain client rather than the app's ApiClient.
*/

const String _kNotificationChannelId = 'kaya_default';

/// Keys for the values the app hands the service when it starts.
class BackgroundKeys {
  static const token = 'bg_token';
  static const baseUrl = 'bg_base_url';
  static const applicationId = 'bg_application_id';
  static const lastNotificationId = 'bg_last_notification_id';
}

/// The isolate entry point. Must be top-level and marked for the VM, or it is
/// tree-shaken out of a release build and the service starts into nothing.
@pragma('vm:entry-point')
void startBackgroundCallback() {
  FlutterForegroundTask.setTaskHandler(_KayaTaskHandler());
}

class _KayaTaskHandler extends TaskHandler {
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  String? _token;
  String? _baseUrl;
  int? _applicationId;
  int _lastNotificationId = 0;

  /// Position is reported once a minute; notifications are checked more often,
  /// since a message is worth less the later it arrives.
  DateTime _lastPing = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _pingEvery = Duration(minutes: 1);

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _token = await FlutterForegroundTask.getData<String>(key: BackgroundKeys.token);
    _baseUrl = await FlutterForegroundTask.getData<String>(key: BackgroundKeys.baseUrl);
    _applicationId =
        await FlutterForegroundTask.getData<int>(key: BackgroundKeys.applicationId);
    _lastNotificationId = await FlutterForegroundTask.getData<int>(
            key: BackgroundKeys.lastNotificationId) ??
        0;

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    if (_token == null || _baseUrl == null) return;

    if (DateTime.now().difference(_lastPing) >= _pingEvery) {
      _lastPing = DateTime.now();
      await _sendPosition();
    }

    await _pollNotifications();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Nothing to tear down. The app stops sharing server-side when it stops
    // the service, and the trail is deleted there rather than here.
  }

  /// Reads the current position and reports it.
  Future<void> _sendPosition() async {
    final applicationId = _applicationId;
    if (applicationId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );

      await _post('/applications/$applicationId/tracking/ping', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy_m': position.accuracy,
      });
    } catch (e) {
      // A denied permission, no fix, or no signal. The next tick tries again;
      // a failed ping must never stop the service.
      debugPrint('[bg] position failed: $e');
    }
  }

  /// Asks for anything newer than the last notification already shown, and
  /// raises each on the notification shade.
  Future<void> _pollNotifications() async {
    try {
      final body = await _get('/notifications?after_id=$_lastNotificationId');
      if (body == null) return;

      final data = body['data'];
      final list = (data is Map ? data['data'] : data) as List?;
      if (list == null || list.isEmpty) return;

      for (final raw in list) {
        if (raw is! Map) continue;

        final id = raw['id'];
        if (id is! int) continue;

        await _show(
          id: id,
          title: '${raw['title'] ?? 'KAYA'}',
          body: '${raw['body'] ?? ''}',
        );

        if (id > _lastNotificationId) _lastNotificationId = id;
      }

      // Persisted so a restarted service does not replay what it already
      // showed — START_STICKY means onStart can run again at any time.
      await FlutterForegroundTask.saveData(
        key: BackgroundKeys.lastNotificationId,
        value: _lastNotificationId,
      );
    } catch (e) {
      debugPrint('[bg] notification poll failed: $e');
    }
  }

  Future<void> _show({required int id, required String title, required String body}) async {
    await _local.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _kNotificationChannelId,
          'KAYA',
          channelDescription: 'Messages, hires and job matches',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  // ── plain HTTP, because ApiClient lives in the other isolate ───────────────

  Future<Map<String, dynamic>?> _get(String path) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('$_baseUrl/api/v1$path'));
      _decorate(request);

      final response = await request.close();
      if (response.statusCode >= 400) return null;

      final text = await response.transform(utf8.decoder).join();

      return text.isEmpty ? null : jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$_baseUrl/api/v1$path'));
      _decorate(request);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));

      final response = await request.close();
      await response.drain<void>();
    } finally {
      client.close(force: true);
    }
  }

  void _decorate(HttpClientRequest request) {
    request.headers.set('Accept', 'application/json');
    request.headers.set('Authorization', 'Bearer $_token');
    // The tunnel serves an interstitial to anything it thinks is a browser.
    request.headers.set('ngrok-skip-browser-warning', '1');
  }
}
