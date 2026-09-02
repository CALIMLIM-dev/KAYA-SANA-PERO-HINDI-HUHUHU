import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_mode.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/navigation/app_router.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/notification_provider.dart';
import '../widgets/notification_item.dart';

/// The notification centre.
///
/// Live: new notifications arrive over the socket and appear without a refresh.
/// Pull-to-refresh still exists and still works — it is the fallback whenever
/// the connection is down, which on Philippine mobile data happens often enough
/// that removing it would be a mistake.
///
/// Filtered by the active mode, like the inbox is: a hybrid account acting as a
/// worker has no use for "new applicant" alerts about jobs they posted.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      /*
          force: opening the screen is a request for the current list.

          Without it the `_hasLoadedOnce` guard made every visit after the
          first a no-op, so the inbox showed whatever existed the first time it
          was opened — usually nothing — and only a realtime push could ever
          change that. Realtime is not guaranteed, so this cannot depend on it.
      */
      context.read<NotificationProvider>().load(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AppModeProvider>().mode;
    final provider = context.watch<NotificationProvider>();
    final items = provider.itemsFor(mode);
    final hasUnread = provider.unreadFor(mode) > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: () => provider.markAllRead(mode),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        child: _body(provider, items),
      ),
    );
  }

  Widget _body(NotificationProvider provider, List<AppNotification> items) {
    if (provider.isLoading && !provider.hasLoadedOnce) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      // Must still scroll, or pull-to-refresh is unreachable on an empty list —
      // which is exactly the state a user most wants to retry from.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Icon(
            provider.error != null
                ? Icons.cloud_off_rounded
                : Icons.notifications_none_rounded,
            size: 56,
            color: AppColors.neutral400,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              provider.error ?? 'No notifications yet',
              style: TextStyle(color: AppColors.neutral600, fontSize: 15),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              provider.error != null
                  ? 'Pull down to try again'
                  : "We'll let you know when something happens",
              style: TextStyle(color: AppColors.neutral400, fontSize: 13.5),
            ),
          ),
        ],
      );
    }

    final rows = _group(items);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final entry = rows[index];
        if (entry is _Header) return _SectionHeader(title: entry.title);

        final n = (entry as _Row).notification;
        return NotificationItem(
          type: _typeOf(n.type),
          title: n.title,
          message: n.body ?? '',
          timestamp: n.age ?? '',
          isRead: n.isRead,
          onTap: () => _open(n),
        );
      },
    );
  }

  /*
      A notification is a route only if this account can actually open it.

      _open read the notification's own fields and pushed, full stop. Nothing
      asked whether the person tapping had the profile the destination belongs
      to — so "someone applied to your job" sent whoever tapped it to
      /view-applicants, an employer screen, and an account with no employer
      profile landed on a screen the server answers with 403. It looked like
      the app was throwing people at a random screen, which is what it was
      doing.

      The list on this screen is filtered by the active mode, and that filter
      was doing just enough work to hide the problem: it is a display filter,
      and a notification that arrives while the mode is elsewhere, or an
      account whose profiles changed since, walks straight past it. The guard
      belongs on the tap, where the destination is actually known.

      For a hybrid the answer is not to refuse but to follow: they hold both
      profiles, so switch to the side the notification belongs to and then go.
      Landing on the employer's applicant list while the rest of the app still
      says "worker" is the other half of what made hybrid accounts feel broken.
  */
  bool _allow({required bool employerSide}) {
    final mode = context.read<AppModeProvider>();

    if (employerSide ? !mode.hasEmployerProfile : !mode.hasWorkerProfile) {
      AppToast.info(
        context,
        employerSide
            ? 'That is about a job post. Set up an employer profile to see applicants.'
            : 'That is about applying for work. Set up a worker profile to open it.',
      );
      return false;
    }

    final target = employerSide ? AppMode.employer : AppMode.worker;
    final showing = employerSide
        ? mode.effectiveMode.showsEmployerSide
        : mode.effectiveMode.showsWorkerSide;

    if (!showing && mode.canActivate(target)) mode.setMode(target);

    return true;
  }
  /// Marks read, then jumps to whatever the notification is about.
  ///
  /// `reference_type`/`reference_id` are set by the server precisely so the app
  /// never has to parse message text to work out where to go.
  void _open(AppNotification n) {
    context.read<NotificationProvider>().markRead(n.id);

    /*
        Two notifications can point at the same thing and still belong on
        different screens, so type is checked before reference_type.

        "Someone applied to your job" carries reference_type 'job', because the
        job is what it is about. Following that literally sent the employer to
        the public job page — their own listing, as a worker sees it, with no
        applicant on it anywhere. The thing they actually want is one tap
        further in, and the notification already carries the id needed to get
        there.
    */
    if (n.type == 'application.received' && n.referenceId != null) {
      if (!_allow(employerSide: true)) return;

      /*
          A notification outlives the applicant it announced.

          It stays in the list after the person withdraws, or after the
          employer accepts or declines them, and tapping it then opened an
          applicant list with nobody on it — which reads as the screen
          failing to load rather than as nothing being there.

          Only refused when the jobs list is actually loaded and says this
          job has nobody pending. With no data the tap goes through, because
          guessing 'empty' from a list that was never fetched would block a
          real applicant.
      */
      final jobs = context.read<JobProvider>().jobs;
      final job = jobs.where((j) => j['id'] == n.referenceId).firstOrNull;
      final pending = job?['pending_application_count'];

      if (job != null && pending is int && pending == 0) {
        AppToast.info(context,
            'Nobody is waiting on that job any more — they withdrew, or you already answered them.');
        return;
      }
      Navigator.pushNamed(
        context,
        AppRouter.viewApplicants,
        arguments: {'jobId': n.referenceId},
      );
      return;
    }

    switch (n.referenceType) {
      case 'job':
        if (n.referenceId != null) {
          Navigator.pushNamed(
            context,
            AppRouter.jobDetails,
            arguments: {'jobId': n.referenceId},
          );
        }
      case 'application':
        if (!_allow(employerSide: false)) return;
        Navigator.pushNamed(context, AppRouter.applications);
      case 'invitation':
        if (!_allow(employerSide: false)) return;
        Navigator.pushNamed(context, '/my-invitations');
      /*
          Open the thread, not the inbox.

          reference_id is the conversation the message arrived in, and the
          banner has always used it to push straight into the chat. This branch
          dropped it and pushed the list instead, so tapping "New message" left
          the reader to find the conversation themselves — and on a busy inbox
          that is worse than not linking at all, because it looks like the tap
          failed.
      */
      case 'conversation':
        if (n.referenceId != null) {
          Navigator.pushNamed(
            context,
            AppRouter.chat,
            arguments: {'conversationId': n.referenceId},
          );
        } else {
          Navigator.pushNamed(context, AppRouter.messages);
        }
      // Approved or rejected identity check. It carries no id — there is one
      // verification screen and it shows the current state, including the
      // admin's rejection reason.
      case 'verification':
        Navigator.pushNamed(context, '/verification');
    }
  }

  static NotificationType _typeOf(String type) {
    if (type.startsWith('message.')) return NotificationType.message;
    if (type.startsWith('application.') || type.startsWith('invitation.')) {
      return NotificationType.application;
    }
    if (type.startsWith('verification.')) return NotificationType.verification;
    if (type.startsWith('review.')) return NotificationType.review;
    // Job matches and completions read as work, not as a system message.
    if (type.startsWith('job.')) return NotificationType.application;
    return NotificationType.system;
  }

  /// Today / Yesterday / Earlier — cheap orientation that makes a long list
  /// readable without needing a date on every row.
  static List<Object> _group(List<AppNotification> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final buckets = <String, List<AppNotification>>{
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };

    for (final n in items) {
      final at = n.createdAt?.toLocal();
      if (at == null) {
        buckets['Earlier']!.add(n);
        continue;
      }
      final day = DateTime(at.year, at.month, at.day);
      if (day == today) {
        buckets['Today']!.add(n);
      } else if (day == yesterday) {
        buckets['Yesterday']!.add(n);
      } else {
        buckets['Earlier']!.add(n);
      }
    }

    final out = <Object>[];
    buckets.forEach((title, group) {
      if (group.isEmpty) return;
      out.add(_Header(title));
      out.addAll(group.map(_Row.new));
    });
    return out;
  }
}

class _Header {
  const _Header(this.title);
  final String title;
}

class _Row {
  const _Row(this.notification);
  final AppNotification notification;
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
