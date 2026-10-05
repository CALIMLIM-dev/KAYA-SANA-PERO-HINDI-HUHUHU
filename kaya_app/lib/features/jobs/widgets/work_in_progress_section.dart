import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../data/models/job_model.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/job_provider.dart';
import '../../applications/widgets/completion_action.dart';

/*
    The job you are actually doing, on the home screen.

    Confirming a finished job lived three taps in - home, My Activity, the
    right tab, then the card - and the panel asked for it on the home page.
    It is the one action in the app with a deadline attached, so burying it
    behind navigation is how a job sits unconfirmed for a week and then gets
    closed as unsuccessful by kaya:close-unconfirmed-hires.

    Reuses confirmCompletion and completionHasOpened rather than carrying its
    own copy: three surfaces already offer this and a fourth rule would be
    the fourth chance for them to disagree about whose turn it is.
*/
class WorkInProgressSection extends StatelessWidget {
  const WorkInProgressSection({
    super.key,
    required this.onChanged,
    this.maxRows = 2,
  });

  /// Refetches whatever the host screen is showing, after a confirmation.
  final Future<void> Function() onChanged;

  /*
      How many to show here.

      This is a prompt, not a list. An employer running five jobs at once
      should not have the home screen become Manage Jobs - so the rest sit
      behind "See all" where they always were.
  */
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    /*
        Both sides, because both sides have to confirm.

        liveWork is the worker's accepted applications. Reading only
        that meant an employer - who confirms the same job from the
        other end - saw nothing here at all, and had to go back to My
        Activity for the one action this section exists to surface.

        The employer's half comes from their own posts: a job still
        running with a hire on it. Normalised into the same shape as an
        application so one card draws both.
    */
    final live = [
      ...context.watch<ApplicationProvider>().liveWork,
      ..._employerHires(context.watch<JobProvider>()),
    ];

    if (live.isEmpty) return const SizedBox.shrink();

    final shown = live.take(maxRows).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Work in progress',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900,
                  ),
                ),
              ),
              if (live.length > shown.length)
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
                  child: Text('See all ${live.length}'),
                ),
            ],
          ),
        ),
        for (final application in shown)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _card(context, application),
          ),
      ],
    );
  }

  /*
      The employer's unfinished hires, shaped like applications.

      myJobs returns the hire nested on the job; this flips it so the
      card can read one shape. Only a job still running: a closed or
      swept job cannot be completed - JobCompletionService refuses it -
      and offering it would be the same inert button that was reported
      in History.
  */
  List<Map<String, dynamic>> _employerHires(JobProvider jobs) {
    final out = <Map<String, dynamic>>[];

    for (final job in jobs.jobs) {
      final hire = job['hire'];

      if (hire is! Map<String, dynamic>) continue;
      if (hire['status'] != 'accepted') continue;
      if (!JobProvider.jobIsActive(job)) continue;

      out.add({
        'id': hire['application_id'],
        'status': 'accepted',
        'worker_completed_at': hire['employer_completed_at'],
        'employer_completed_at': hire['worker_completed_at'],
        // Whose name to put on the card: for an employer it is the
        // worker they hired, not their own company.
        '_other': hire['worker_name'] ?? 'the worker',
        'job': job,
      });
    }

    return out;
  }

  Widget _card(BuildContext context, Map<String, dynamic> application) {
    final applicationId = (application['id'] as num?)?.toInt();
    final jobMap = application['job'];
    final job = jobMap is Map<String, dynamic> ? Job.fromJson(jobMap) : null;

    final title = job?.title ?? '${jobMap is Map ? jobMap['title'] ?? 'A job' : 'A job'}';
    /*
        The other party, whichever side this is.

        _other is set when the row came from the employer's own jobs;
        otherwise the worker is looking at it and the other party is
        the company that posted it.
    */
    final employer = (application['_other'] as String?)
        ?? job?.company
        ?? 'the other side';

    final iConfirmed = application['worker_completed_at'] != null;
    final theyConfirmed = application['employer_completed_at'] != null;

    // Same rule as My Activity: the control is always there once hired, and
    // the deadline only decides whether it reads as finishing the job or as
    // asking the other side whether it is finished.
    // These take the raw job map, the same shape My Activity passes them.
    final rawJob = jobMap is Map<String, dynamic> ? jobMap : null;
    final early = !completionHasOpened(rawJob);
    final waitNote = completionWaitNote(rawJob);

    return Container(
      padding: const EdgeInsets.all(13),
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
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.handyman_outlined,
                    size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      employer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.neutral600),
                    ),
                  ],
                ),
              ),
            ],
          ),

          /*
              What the two of you are waiting on.

              The half-state is the thing people get stuck in: one side has
              confirmed and the other has no idea they are being waited on.
              Saying it here is most of why this section is worth the room.
          */
          if (iConfirmed || theyConfirmed || waitNote != null) ...[
            const SizedBox(height: 9),
            Text(
              iConfirmed
                  ? 'You marked this done. Waiting for $employer to confirm.'
                  : theyConfirmed
                      ? '$employer marked this done. Confirm to finish it.'
                      : waitNote!,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.neutral600,
              ),
            ),
          ],

          if (applicationId != null && !iConfirmed) ...[
            const SizedBox(height: 11),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => confirmCompletion(
                  context,
                  applicationId,
                  employer,
                  onChanged,
                  early: early,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                child: Text(theyConfirmed
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
