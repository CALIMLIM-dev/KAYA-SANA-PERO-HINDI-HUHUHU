import 'package:flutter/widgets.dart';

import '../../data/services/realtime_service.dart';

/// Makes a list screen refresh itself when something relevant happens.
///
/// Most screens don't need their own channel. The user's notification feed
/// already carries every domain event — an applicant applied, an application
/// was accepted, an invitation arrived — so a screen can listen to that one
/// stream and reload when a type it cares about lands. Giving each list its own
/// channel would multiply subscriptions to learn the same facts.
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
  bool _bound = false;

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
  }

  void _onNotification(Map<String, dynamic> data) {
    final notification = data['notification'];
    if (notification is! Map) return;

    final type = '${notification['type'] ?? ''}';
    if (!refreshOn.any(type.startsWith)) return;

    if (!mounted) return;
    onRealtimeRefresh();
  }

  @override
  void dispose() {
    _disposeListener?.call();
    _detachConnection?.call();
    super.dispose();
  }
}
