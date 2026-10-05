import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/job_provider.dart';
import '../../applications/widgets/completion_action.dart';

/*
    Active work, on the home screen.

    This is My Activity's Active tab moved, which is what was asked for and
    not what the first version did. That one listed only hires that already
    existed, so an employer with an open post and nobody hired yet saw
    nothing, and a worker whose application was still unanswered saw nothing.
    Both of those are active work and both belong here.

    Compact on purpose. It sits above the feed on the screen people open
    first, so a row is one line of what it is, one line of where it stands,
    and a button only when there is something to press.

    Mark as complete is the reason it exists: it was three taps deep in My
    Activity, and kaya:close-unconfirmed-hires closes a hire a week past its
    deadline as unsuccessful - so a confirmation nobody can find costs
    somebody their completion.
*/
class WorkInProgressSection extends StatelessWidget {
  const WorkInProgressSection({
    super.key,
    required this.onChanged,
    this.maxRows = 3,
  });

  /// Refetches whatever the host screen shows, after a confirmation.
  final Future<void> Function() onChanged;

  /// A prompt, not a list. The rest stay in My Activity.
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ..._workerRows(context.watch<ApplicationProvider>()),
      ..._employerRows(context.watch<JobProvider>()),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    final shown = rows.take(maxRows).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    AppRouter.push(context, AppRouter.applications),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: Text(rows.length > shown.length
                    ? 'See all ${rows.length}'
                    : 'See all'),
              ),
            ],
          ),
        ),
        for (final row in shown)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _card(context, row),
          ),
      ],
    );
  }

  /*
      The worker's side: everything in flight.

      ApplicationProvider.active is pending plus accepted, the same
      definition My Activity's Active tab uses - so the two cannot disagree
      about what counts as active.
  */
  List<_ActiveRow> _workerRows(ApplicationProvider applications) {
    return applications.active.map((application) {
      final job = application['job'];
      final jobMap = job is Map<String, dynamic> ? job : null;
      final employer = jobMap?['employer'];

      final accepted = application['status'] == 'accepted';

      return _ActiveRow(
        title: '${jobMap?['title'] ?? 'A job'}',
        otherParty: '${jobMap?['company'] ?? (employer is Map ? employer['name'] : null) ?? 'the employer'}',
        job: jobMap,
        applicationId: accepted ? (application['id'] as num?)?.toInt() : null,
        iConfirmed: application['worker_completed_at'] != null,
        theyConfirmed: application['employer_completed_at'] != null,
        notHiredYet: !accepted,
      );
    }).toList();
  }

  /*
      The employer's side: their own posts that are still running.

      JobProvider.activeJobs is the one definition of that, and it answers to
      is_live from the server rather than the status column - the expiry sweep
      runs once a day, so a post past its date still reads open until it does.
  */
  List<_ActiveRow> _employerRows(JobProvider jobs) {
    return jobs.activeJobs.map((job) {
      final hire = job['hire'];
      final hireMap = hire is Map<String, dynamic> ? hire : null;
      final hired = hireMap?['status'] == 'accepted';

      return _ActiveRow(
        title: '${job['title'] ?? 'A job'}',
        otherParty: '${hireMap?['worker_name'] ?? 'the worker'}',
        job: job,
        /*
            Only a live hire can be completed.

            Null here when nobody is hired yet or it is already confirmed,
            which is what keeps the button off a row where pressing it would
            do nothing - the same inert control that turned up in History.
        */
        applicationId:
            hired ? (hireMap?['application_id'] as num?)?.toInt() : null,
        // From this side, my stamp is the employer's and theirs is the
        // worker's.
        iConfirmed: hireMap?['employer_completed_at'] != null,
        theyConfirmed: hireMap?['worker_completed_at'] != null,
        notHiredYet: !hired,
        applicants: (job['application_count'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Widget _card(BuildContext context, _ActiveRow row) {
    final early = !completionHasOpened(row.job);
    final waitNote = completionWaitNote(row.job);

    /*
        One line saying where this stands.

        The half-state is what people get stuck in: one side has confirmed
        and the other has no idea they are being waited on. Saying it here is
        most of why this section earns the room.
    */
    final String standing = row.notHiredYet
        ? row.applicants == null
            ? 'Waiting for a reply'
            : row.applicants == 0
                ? 'No applicants yet'
                : '${row.applicants} applicant${row.applicants == 1 ? '' : 's'} waiting on you'
        : row.iConfirmed
            ? 'You marked this done. Waiting for ${row.otherParty}.'
            : row.theyConfirmed
                ? '${row.otherParty} marked this done. Confirm to finish it.'
                : waitNote ?? 'In progress with ${row.otherParty}';

    final canConfirm = row.applicationId != null && !row.iConfirmed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                row.notHiredYet
                    ? Icons.hourglass_empty
                    : Icons.handyman_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 25),
            child: Text(
              standing,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.3,
                color: AppColors.neutral600,
              ),
            ),
          ),
          if (canConfirm) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => confirmCompletion(
                  context,
                  row.applicationId!,
                  row.otherParty,
                  onChanged,
                  early: early,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: Text(row.theyConfirmed
                    ? 'Confirm it is done'
                    : early
                        ? 'Finished early?'
                        : 'Mark as complete'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One active thing, from either side, in the shape this card draws.
class _ActiveRow {
  const _ActiveRow({
    required this.title,
    required this.otherParty,
    required this.job,
    required this.applicationId,
    required this.iConfirmed,
    required this.theyConfirmed,
    required this.notHiredYet,
    this.applicants,
  });

  final String title;
  final String otherParty;

  /// The raw job map, which completionHasOpened and completionWaitNote read.
  final Map<String, dynamic>? job;

  /// Null when there is nothing to complete - nobody hired, or already done.
  final int? applicationId;

  final bool iConfirmed;
  final bool theyConfirmed;

  /// Nobody hired yet, so this is waiting rather than working.
  final bool notHiredYet;

  /// Employer side only: how many people are waiting on a decision.
  final int? applicants;
}
