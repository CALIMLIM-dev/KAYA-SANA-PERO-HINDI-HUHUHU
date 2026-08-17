import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'api_client.dart';
import 'background_service.dart';

/*
    Starting and stopping the foreground service, from the app side.

    Kept apart from the handler itself because the two run in different
    isolates: this half has the app's token and configuration and can show a
    permission prompt, the other half has neither and only receives what is
    handed to it here.
*/
class BackgroundController {
  BackgroundController._();

  static final BackgroundController instance = BackgroundController._();

  /// Declares the notification channel and how often the service wakes.
  ///
  /// Called once at start-up. Cheap, and doing it here rather than at start
  /// time means the channel exists before anything tries to post to it —
  /// Android silently drops a notification aimed at a channel that does not
  /// exist yet.
  void configure() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'kaya_default',
        channelName: 'KAYA',
        channelDescription: 'Shown while KAYA is sharing your location',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Ticks every five seconds; the handler decides what is actually due,
        // so position stays on its once-a-minute schedule while notifications
        // are checked far more often.
        eventAction: ForegroundTaskEventAction.repeat(5000),
        // The point of the whole exercise: Android restarts the service if it
        // is killed, so swiping the app out of recents no longer ends it.
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Whether the service is currently up.
  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  /*
      Asks for what the service needs to survive.

      Two separate things, and the second is the one that decides whether this
      works on the phones most KAYA users actually own. Notification permission
      is required from Android 13 to show the persistent notification at all.
      Battery-optimisation exemption is what stops the manufacturer's own power
      manager killing the service anyway — Xiaomi, Oppo, Vivo and Realme are
      aggressive about this, and between them that is most of the Philippine
      market. Without the exemption a worker's location silently stops
      reporting after a few minutes and nothing explains why.
  */
  Future<bool> requestPermissions() async {
    final notification = await FlutterForegroundTask.checkNotificationPermission();
    if (notification != NotificationPermission.granted) {
      final result = await FlutterForegroundTask.requestNotificationPermission();
      if (result != NotificationPermission.granted) return false;
    }

    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      // Opens the system dialog. Declining is allowed — the service still runs,
      // it is just more likely to be killed on an aggressive device.
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    return true;
  }

  /// Starts reporting position for an active hire, and watching for
  /// notifications while it does.
  Future<bool> start({required int applicationId}) async {
    if (await isRunning) {
      await stop();
    }

    final token = await ApiClient.getToken();
    if (token == null) return false;

    // Handed over rather than looked up: the service isolate has no access to
    // secure storage set up by the app, nor to the compile-time base URL.
    await FlutterForegroundTask.saveData(
        key: BackgroundKeys.token, value: token);
    await FlutterForegroundTask.saveData(
        key: BackgroundKeys.baseUrl, value: ApiClient.root);
    await FlutterForegroundTask.saveData(
        key: BackgroundKeys.applicationId, value: applicationId);

    try {
      await FlutterForegroundTask.startService(
        notificationTitle: 'KAYA is sharing your location',
        notificationText: 'Tap to open. Stop sharing any time.',
        callback: startBackgroundCallback,
      );

      return true;
    } catch (e) {
      debugPrint('[bg] start failed: $e');

      return false;
    }
  }

  Future<void> stop() async {
    try {
      await FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint('[bg] stop failed: $e');
    }
  }
}
