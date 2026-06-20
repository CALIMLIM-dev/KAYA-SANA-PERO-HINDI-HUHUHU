import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../widgets/notification_item.dart';

/// Notifications Screen - Grouped by type
/// Groups: Applications, Messages, Verification, System
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Mark all as read
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
        child: ListView(
          children: [
            // Today Section
            _SectionHeader(title: 'Today'),
            NotificationItem(
              type: NotificationType.application,
              title: 'Application Accepted',
              message: 'Your application for "Emergency Pipe Repair" has been accepted!',
              timestamp: '2 minutes ago',
              isRead: false,
              onTap: () {},
            ),
            NotificationItem(
              type: NotificationType.message,
              title: 'New Message',
              message: 'Plumbing Services Inc. sent you a message',
              timestamp: '15 minutes ago',
              isRead: false,
              onTap: () {},
            ),
            NotificationItem(
              type: NotificationType.application,
              title: 'New Applicant',
              message: 'John Doe applied for your job "Carpenter Needed"',
              timestamp: '1 hour ago',
              isRead: true,
              onTap: () {},
            ),

            const SizedBox(height: 16),

            // Yesterday Section
            _SectionHeader(title: 'Yesterday'),
            NotificationItem(
              type: NotificationType.verification,
              title: 'Verification Approved',
              message: 'Your plumbing certification has been verified',
              timestamp: 'Yesterday, 3:45 PM',
              isRead: true,
              onTap: () {},
            ),
            NotificationItem(
              type: NotificationType.message,
              title: 'New Message',
              message: 'Tech Solutions Inc. sent you a message',
              timestamp: 'Yesterday, 2:30 PM',
              isRead: true,
              onTap: () {},
            ),
            NotificationItem(
              type: NotificationType.application,
              title: 'Application Status',
              message: 'Your application for "Electrician Needed" is under review',
              timestamp: 'Yesterday, 10:20 AM',
              isRead: true,
              onTap: () {},
            ),

            const SizedBox(height: 16),

            // Earlier This Week Section
            _SectionHeader(title: 'Earlier This Week'),
            NotificationItem(
              type: NotificationType.system,
              title: 'Profile Update',
              message: 'Your profile has been updated successfully',
              timestamp: '2 days ago',
              isRead: true,
              onTap: () {},
            ),
            NotificationItem(
              type: NotificationType.application,
              title: 'Job Invitation',
              message: 'Baliwag Construction invited you to apply for a job',
              timestamp: '3 days ago',
              isRead: true,
              onTap: () {},
            ),
            NotificationItem(
              type: NotificationType.message,
              title: 'New Message',
              message: 'Cool Air Services sent you a message',
              timestamp: '4 days ago',
              isRead: true,
              onTap: () {},
            ),
            NotificationItem(
              type: NotificationType.system,
              title: 'New Features',
              message: 'Check out the new messaging features in KAYA!',
              timestamp: '5 days ago',
              isRead: true,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.neutral100,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.neutral700,
        ),
      ),
    );
  }
}
