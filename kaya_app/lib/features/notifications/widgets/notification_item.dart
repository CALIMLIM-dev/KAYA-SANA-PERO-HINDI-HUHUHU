import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

enum NotificationType {
  application,
  message,
  verification,
  /// A review was left, or one is now possible.
  review,
  system,
}

class NotificationItem extends StatelessWidget {
  final NotificationType type;
  final String title;
  final String message;
  final String timestamp;
  final bool isRead;
  final VoidCallback onTap;

  const NotificationItem({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : AppColors.primary.withAlpha(13),
          border: Border(
            bottom: BorderSide(
              color: AppColors.neutral200,
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getIconColor().withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIcon(),
                color: _getIconColor(),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                            color: AppColors.neutral900,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.neutral700,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timestamp,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.neutral600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (type) {
      case NotificationType.application:
        return Icons.work_outline;
      case NotificationType.message:
        return Icons.message_outlined;
      case NotificationType.verification:
        return Icons.verified_outlined;
      case NotificationType.review:
        return Icons.star_outline;
      case NotificationType.system:
        return Icons.info_outline;
    }
  }

  Color _getIconColor() {
    switch (type) {
      case NotificationType.application:
        return AppColors.primary;
      case NotificationType.message:
        return AppColors.info;
      case NotificationType.verification:
        return AppColors.success;
      case NotificationType.review:
        return AppColors.warning;
      case NotificationType.system:
        return AppColors.warning;
    }
  }
}
