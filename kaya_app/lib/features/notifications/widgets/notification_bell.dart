import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/notification_provider.dart';

/// The notification bell, with a live unread count.
///
/// The count is scoped to the active mode. A hybrid account acting as a worker
/// should not see a badge for applicants on jobs they posted — that number
/// belongs to the other side of their account and tapping through would show a
/// list that appears empty, which reads as a bug.
///
/// Updates without a refresh: NotificationProvider receives pushes over the
/// socket and the Consumer rebuilds. With the socket down the count is whatever
/// the last fetch said, which is the behaviour the app had before realtime.
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    this.iconSize = 20,
    this.color,
  });

  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AppModeProvider>().mode;
    final unread = context.watch<NotificationProvider>().unreadFor(mode);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, size: iconSize, color: color),
          tooltip: 'Notifications',
          onPressed: () => AppRouter.toNotifications(context),
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: IgnorePointer(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: unread > 9 ? 4 : 0,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(9),
                  // Separates the badge from whatever icon is behind it.
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    // Past 99 the exact number stops being useful and starts
                    // breaking the layout.
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
