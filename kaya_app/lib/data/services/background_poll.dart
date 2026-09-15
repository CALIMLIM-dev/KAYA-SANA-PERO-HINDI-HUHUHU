import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'api_client.dart';
import 'local_alerts.dart';

/// One HTTP GET, as status and body. Swapped for a canned one in tests.
typedef Fetch = Future<(int, String)> Function(Uri uri, Map<String, String> headers);

/*
    Notifications for an app that has been closed.

    There is no push provider, by choice, so nothing on the outside can wake
    the app. What Android does offer is WorkManager: a job the system runs
    on its own schedule whether or not the app is open, including after it
    has been swiped out of recents. It is not instant. Android runs periodic
    work no more often than every fifteen minutes and defers it further when
    the phone is idle, so this is the floor under the other two paths, not a
    replacement for them: the app polls every eight seconds while it is up,
    and the foreground service every five during a hire. This one covers the
    rest of the day.

    It runs in its own isolate with nothing from the app in memory, so the
    token and the server address are left for it in shared preferences at
    sign-in and cleared at sign-out. The id of the newest notification the
    person has already seen is kept there too, written by the app's own poll,
    so the worker never re-announces something that was read on screen.
*/
class BackgroundPoll {
  BackgroundPoll._();

  static const String taskName = 'kaya.notifications';

  static const String tokenKey = 'kaya_bg_token';
  static const String baseUrlKey = 'kaya_bg_base_url';
  static const String lastSeenKey = 'kaya_last_notification_id';

  /// Called once at start-up, before runApp.
  static Future<void> configure() async {
    try {
      await Workmanager().initialize(backgroundPollDispatcher);
    } catch (e) {
      debugPrint('[bgpoll] initialize failed: $e');
    }
  }

  /// Registers the periodic job for the signed-in account. Idempotent.
  static Future<void> register() async {
    final token = await ApiClient.getToken();
    if (token == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(tokenKey, token);
      await prefs.setString(baseUrlKey, ApiClient.root);

      await Workmanager().registerPeriodicTask(
        taskName,
        taskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint('[bgpoll] register failed: $e');
    }
  }

  /// Stops the job and forgets the credential it was using.
  static Future<void> cancel() async {
    try {
      await Workmanager().cancelByUniqueName(taskName);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenKey);
      await prefs.remove(baseUrlKey);
      await prefs.remove(lastSeenKey);
    } catch (e) {
      debugPrint('[bgpoll] cancel failed: $e');
    }
  }

  /// The app's poll records the newest id it has shown, so nothing already
  /// seen on screen comes back later on the shade.
  static Future<void> rememberSeen(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id > (prefs.getInt(lastSeenKey) ?? 0)) {
        await prefs.setInt(lastSeenKey, id);
      }
    } catch (_) {
      // Preferences unavailable. The worker will show one extra at worst.
    }
  }

  /// One run of the job: anything newer than the last id, onto the shade.
  /// Split out from the dispatcher so it can be exercised without WorkManager.
  static Future<bool> runOnce(SharedPreferences prefs, {Fetch? fetch}) async {
    final token = prefs.getString(tokenKey);
    final baseUrl = prefs.getString(baseUrlKey);
    if (token == null || token.isEmpty || baseUrl == null) return true;

    final lastSeen = prefs.getInt(lastSeenKey) ?? 0;

    try {
      final (status, text) = await (fetch ?? _fetch)(
        Uri.parse('$baseUrl/api/v1/notifications?after_id=$lastSeen&per_page=20'),
        {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (status == 401 || status == 403) {
        // The session is gone. Stop polling with a dead credential.
        await prefs.remove(tokenKey);
        return true;
      }
      if (status >= 400) return false;
      if (text.isEmpty) return true;

      final body = jsonDecode(text);
      final data = body is Map ? body['data'] : null;
      final rows = (data is Map ? data['data'] : data) as List? ?? [];

      // The first run on a fresh sign-in has no high-water mark. Announcing
      // the whole backlog would be noise; the app's own poll sets the mark
      // the moment it opens, so only take the newest here.
      if (lastSeen == 0) {
        var newest = 0;
        for (final raw in rows) {
          if (raw is Map && raw['id'] is int && raw['id'] > newest) newest = raw['id'];
        }
        if (newest > 0) await prefs.setInt(lastSeenKey, newest);
        return true;
      }

      var newest = lastSeen;
      final ordered = rows.whereType<Map>().toList()
        ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

      for (final raw in ordered) {
        final id = raw['id'];
        if (id is! int || id <= lastSeen) continue;

        await LocalAlerts.show(
          id: id,
          title: '${raw['title'] ?? 'KAYA'}',
          body: '${raw['body'] ?? ''}',
          notification: Map<String, dynamic>.from(raw),
        );
        if (id > newest) newest = id;
      }

      if (newest > lastSeen) await prefs.setInt(lastSeenKey, newest);
      return true;
    } catch (e) {
      debugPrint('[bgpoll] run failed: $e');
      return false;
    }
  }

  static Future<(int, String)> _fetch(Uri uri, Map<String, String> headers) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      headers.forEach(request.headers.set);
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      return (response.statusCode, text);
    } finally {
      client.close(force: true);
    }
  }
}

/// The WorkManager entry point. Top-level and pinned for the VM, or a
/// release build tree-shakes it and the job starts into nothing.
@pragma('vm:entry-point')
void backgroundPollDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != BackgroundPoll.taskName) return true;
    final prefs = await SharedPreferences.getInstance();
    return BackgroundPoll.runOnce(prefs);
  });
}
