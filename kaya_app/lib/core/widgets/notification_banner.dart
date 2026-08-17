import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/realtime_service.dart';
import '../../providers/messaging_provider.dart';
import '../../providers/notification_provider.dart';
import '../constants/app_colors.dart';
import '../navigation/app_router.dart';

/*
    Notifications you can actually see arrive.

    Everything needed for this already existed: the server pushes every domain
    event to `user.{id}` as `notification.created`, and screens listen to that
    stream to refresh themselves. What was missing was any indication to the
    person holding the phone. A hire landed, a message arrived, and the only
    evidence was a number on a tab they were not looking at — so the app felt
    silent even while it was working.

    This wraps the app and shows an arriving notification the way a phone does:
    a card that slides in over whatever is on screen, says what happened, and
    goes away on its own. Tapping it opens the thing it is about.
*/
class NotificationBannerHost extends StatefulWidget {
  const NotificationBannerHost({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<NotificationBannerHost> createState() => _NotificationBannerHostState();
}

class _NotificationBannerHostState extends State<NotificationBannerHost> {
  VoidCallback? _disposeListener;
  VoidCallback? _detachConnection;
  OverlayEntry? _entry;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  /// The user id only exists once the socket has fetched its config, so this
  /// may have to wait for the connection rather than binding at start-up.
  void _bind() {
    final realtime = RealtimeService.instance;

    void attach() {
      final userId = realtime.userId;
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
    if (!mounted) return;

    final raw = data['notification'];
    if (raw is! Map) return;

    final notification = Map<String, dynamic>.from(raw);
    final type = '${notification['type'] ?? ''}';
    final referenceType = '${notification['reference_type'] ?? ''}';
    final referenceId = notification['reference_id'] as int?;

    /*
        Don't announce what the user is already reading.

        A message for the open thread arrives on screen by itself a moment
        later. Putting a banner over the top of it says the same thing twice
        and covers the message it is announcing.
    */
    if (type.startsWith('message.') &&
        referenceType == 'conversation' &&
        referenceId != null) {
      final messaging = widget.navigatorKey.currentContext?.read<MessagingProvider>();
      if (messaging?.activeConversationId == referenceId) return;
    }

    _show(notification);
  }

  void _show(Map<String, dynamic> notification) {
    final overlay = widget.navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    // One at a time. A second arrival replaces the first rather than stacking,
    // which keeps a burst of notifications from covering the screen.
    _remove();

    _entry = OverlayEntry(
      builder: (_) => _Banner(
        notification: notification,
        onTap: () {
          _remove();
          _openTarget(notification);
        },
        onDismiss: _remove,
      ),
    );

    overlay.insert(_entry!);
    _dismissTimer = Timer(const Duration(seconds: 4), _remove);
  }

  void _remove() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _entry?.remove();
    _entry = null;
  }

  /// Opens whatever the notification is about.
  void _openTarget(Map<String, dynamic> notification) {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;

    final referenceType = '${notification['reference_type'] ?? ''}';
    final referenceId = notification['reference_id'] as int?;

    // Read, since the user has now acted on it.
    final id = notification['id'] as int?;
    final context = widget.navigatorKey.currentContext;
    if (id != null && context != null) {
      context.read<NotificationProvider>().markRead(id);
    }

    if (referenceType == 'conversation' && referenceId != null) {
      navigator.pushNamed(
        AppRouter.chat,
        arguments: {'conversationId': referenceId},
      );
      return;
    }

    // Everything else lands on the notification centre, which can explain
    // itself better than a guess at the right screen would.
    navigator.pushNamed(AppRouter.notifications);
  }

  @override
  void dispose() {
    _remove();
    _disposeListener?.call();
    _detachConnection?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The card itself.
class _Banner extends StatefulWidget {
  const _Banner({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The icon carries the category, so the kind of event is readable before
  /// the words are.
  ({IconData icon, Color colour}) get _look {
    final type = '${widget.notification['type'] ?? ''}';

    if (type.startsWith('message.')) {
      return (icon: Icons.chat_bubble, colour: AppColors.primary);
    }
    if (type == 'application.accepted' || type.startsWith('invitation.accep')) {
      return (icon: Icons.celebration, colour: AppColors.success);
    }
    if (type.startsWith('application.')) {
      return (icon: Icons.person_add_alt_1, colour: AppColors.primary);
    }
    if (type.startsWith('invitation.')) {
      return (icon: Icons.mail, colour: AppColors.primary);
    }
    if (type.startsWith('job.')) {
      return (icon: Icons.work, colour: AppColors.primary);
    }
    return (icon: Icons.notifications, colour: AppColors.primary);
  }

  @override
  Widget build(BuildContext context) {
    final look = _look;
    final title = '${widget.notification['title'] ?? 'KAYA'}';
    final body = '${widget.notification['body'] ?? ''}';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Material(
              color: Colors.transparent,
              // Swipe it away upward, the way a real heads-up notification goes.
              child: Dismissible(
                key: ValueKey(widget.notification['id'] ?? title),
                direction: DismissDirection.up,
                onDismissed: (_) => widget.onDismiss(),
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: look.colour.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(look.icon, size: 19, color: look.colour),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.neutral900,
                                ),
                              ),
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.neutral600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
