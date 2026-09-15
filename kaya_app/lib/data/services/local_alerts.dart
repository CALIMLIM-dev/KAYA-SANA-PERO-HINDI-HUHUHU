import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/*
    Notifications on the phone's shade, from whichever isolate has one to
    show.

    Three things raise them: the app itself when it is open but not on
    screen, the periodic worker when the app has been closed, and the
    foreground service during an active hire. All three post into the same
    channel so the phone treats them the same way, and the channel is a
    loud one. The service's own persistent notice lives on a quiet channel;
    alerts used to be posted there too, which is why a message during a
    hire arrived without a sound or a pop-up.
*/
class LocalAlerts {
  LocalAlerts._();

  static const String channelId = 'kaya_alerts';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _ready = false;

  /// Set by the app to open what a tapped notification is about. The
  /// payload is the notification row as JSON.
  static void Function(Map<String, dynamic> notification)? onTap;

  /// Idempotent. Every isolate calls it before showing anything.
  static Future<void> init() async {
    if (_ready) return;
    _ready = true;

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final map = jsonDecode(payload);
          if (map is Map) onTap?.call(Map<String, dynamic>.from(map));
        } catch (_) {
          // A payload this code did not write. Opening the app is enough.
        }
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          channelId,
          'Alerts',
          description: 'Messages, applicants, hires and job matches',
          importance: Importance.high,
        ));
  }

  /// Android 13 and up ask before an app may post at all. Asked once a
  /// session; the system remembers the answer.
  static Future<void> requestPermission() async {
    try {
      await init();
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('[alerts] permission request failed: $e');
    }
  }

  /// Tests record what would have been shown instead of reaching the plugin.
  @visibleForTesting
  static void Function(int id, String title, String body)? testSink;

  static Future<void> show({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? notification,
  }) async {
    if (testSink != null) {
      testSink!(id, title, body);
      return;
    }
    try {
      await init();
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: notification == null ? null : jsonEncode(notification),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Alerts',
            channelDescription: 'Messages, applicants, hires and job matches',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[alerts] show failed: $e');
    }
  }
}
