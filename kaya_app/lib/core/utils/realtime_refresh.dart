import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../data/services/realtime_service.dart';
import '../../providers/notification_provider.dart';

/// Makes a list screen refresh itself when something relevant happens.
///
/// Most screens don't need their own channel. The user's notification feed
/// already carries every domain event — an applicant applied, an application
/// was accepted, an invitation arrived — so a screen can listen to that one
/// stream and reload when a type it cares about lands. Giving each list its own
/// channel would multiply subscriptions to learn the same facts.
///
/// The stream has two sources and the screen does not care which. The socket,
/// when Reverb is running; and the notification poll, which is what actually
/// runs on the server today. This mixin used to listen to the socket alone,
/// and with Reverb switched off no screen ever refreshed: people restarted the
/// app to see an applicant who had applied a minute ago. The poll fires the
/// same notification a few seconds later, so listening to both means the
/// screens work either way.
///
/// It also refreshes when the app comes back to the foreground. A screen left
/// open overnight is the same problem in a different shape.
///
/// It re-fetches rather than patching state from the payload. A notification
/// says *that* something changed, not the full new shape of the row, and
/// re-deriving list state from a notification body is how lists drift out of
/// sync with the server. One extra request is worth being correct.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with RealtimeRefresh {
///   @override
///   List<String> get refreshOn => ['application.received'];
///
///   @override
///   void onRealtimeRefresh() => context.read<X>().reload();
/// }
/// ```
mixin RealtimeRefresh<T extends StatefulWidget> on State<T> {
  VoidCallback? _disposeListener;
  VoidCallback? _detachConnection;
  VoidCallback? _detachPoll;
  AppLifecycleListener? _lifecycle;
  bool _bound = false;
  bool _queued = false;

  /// Notification types that should trigger a refresh.
  ///
  /// Matched as prefixes, so `'application.'` catches received, accepted and
  /// rejected without listing each.
  List<String> get refreshOn;

  /// What to do when one arrives. Called on the widget tree's thread with
  /// [mounted] already checked.
  void onRealtimeRefresh();

  /// Call from `initState` (inside a post-frame callback if you also fetch).
  void bindRealtimeRefresh() {
    if (_bound) return;
    _bound = true;

    final realtime = RealtimeService.instance;

    void attach() {
      final userId = realtime.userId;
      // The user id only exists once the socket has fetched its config, so
      // binding may have to wait for the connection rather than happening at
      // initState.
      if (!realtime.connected.value || userId == null) return;
      if (_disposeListener != null) return;

      _disposeListener = realtime.on(
        'user.$userId',
        'notification.created',
        _onNotification,
      );
    }

    realtime.connected.addListener(attach);
    _detachConnection = () => realtime.connected.removeListener(attach);
    attach();

    // The poll. Absent in a widget test that mounts the screen bare, which
    // is fine: the screen still fetches on its own.
    try {
      final notifications = context.read<NotificationProvider>();
      void onArrived() {
        final n = notifications.arrived.value;
        if (n != null) _refreshIfRelevant(n.type);
      }

      notifications.arrived.addListener(onArrived);
      _detachPoll = () => notifications.arrived.removeListener(onArrived);
    } on ProviderNotFoundException {
      // No provider above this screen, so no poll to listen to.
    }

    _lifecycle = AppLifecycleListener(onResume: () {
      if (mounted) onRealtimeRefresh();
    });
  }

  void _onNotification(Map<String, dynamic> data) {
    final notification = data['notification'];
    if (notification is! Map) return;

    _refreshIfRelevant('${notification['type'] ?? ''}');
  }

  /// One refresh per burst. A poll can hand over several notifications at
  /// once and the screen should reload once for all of them, not once each.
  void _refreshIfRelevant(String type) {
    if (!refreshOn.any(type.startsWith)) return;
    if (_queued) return;

    _queued = true;
    scheduleMicrotask(() {
      _queued = false;
      if (mounted) onRealtimeRefresh();
    });
  }

  @override
  void dispose() {
    _disposeListener?.call();
    _detachConnection?.call();
    _detachPoll?.call();
    _lifecycle?.dispose();
    super.dispose();
  }
}
