import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/utils/json_parse.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/job_model.dart';
import '../../../providers/application_provider.dart';
import 'completion_action.dart';

/*
    One applicant, as an employer sees them.

    Lifted out of ViewApplicantsScreen so the home screen can show the people
    who applied with the very same card - Accept, Reject, hired-before and
    all - instead of a second drawing that would drift from the first.

    A worker who has ever topped up arrives with their resume open: every
    skill, experience, licences and certificates. Everyone else arrives as
    the card always looked, in the same position, one tap from the profile.
    Ranking is free; only the presentation is bought.
*/
class ApplicantCard extends StatelessWidget {
  const ApplicantCard({
    super.key,
    required this.applicant,
    required this.showActions,
    required this.perWorkerActions,
    required this.onChanged,
    this.full = false,
    this.jobId,
    this.jobTitle = 'this job',
    this.jobStatus = '',
    this.job,
  });

  final Map<String, dynamic> applicant;
  final bool showActions;
  final bool perWorkerActions;
  final bool full;

  /// Refetches whatever list this card sits in, after a completion or review.
  final Future<void> Function() onChanged;

  final int? jobId;
  final String jobTitle;
  final String jobStatus;

  /// The job, when known, for the completion deadline. Null on the home
  /// screen, which only shows applicants still waiting on a decision.
  final Job? job;

  @override
  Widget build(BuildContext context) {
    final status = (applicant['application_status'] ?? 'pending').toString();
    final name = (applicant['worker_name'] ?? 'Worker').toString();
    // worker_rating comes from WorkerProfile.rating_avg, a Laravel decimal
    // cast — it arrives as the string "0.00", so a plain `as num?` threw and
    // took the whole applicants list down.
    final rating = asDouble(applicant['worker_rating']);
    final reviewCount = asInt(applicant['worker_rating_count']);
    final isVerified = applicant['is_verified'] as bool? ?? false;
    final skills = (applicant['skills'] as List?)
            ?.map((s) => s.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];
    final applicationId = applicant['application_id'] as int;
    final workerId = applicant['worker_id'] as int?;
    final photoUrl = (applicant['worker_photo_url'] ?? '').toString();
    final conversationId = applicant['conversation_id'] as int?;
    final premium = applicant['is_premium'] == true;

    // Rehire, the half that needs no new table: a completed application
    // already records that this worker did one of your jobs. An employer
    // choosing between five applicants wants to know which one they already
    // trust, and that fact was sitting in the database unused.
    final timesHiredBefore = asInt(applicant['times_hired_before']);

    // Dual review, employer's side — mirrors the worker's on the applications
    // screen. Both halves come down with the applicant list, so showing this
    // costs no extra request.
    final iReviewedThem = applicant['i_reviewed_them'] == true;
    final theyReviewedMe = applicant['they_reviewed_me'] == true;

    /*
        Two-sided completion, per hire.

        The employer's own card in My Activity handles the common single-hire
        job. This screen is the only place a job with two people on it can be
        finished, because there the card cannot say which of them you mean.

        Judged on this hire's status, not the job's — a job with two hires only
        reaches 'completed' once both are done, and the first pair should not
        wait on the second.
    */
    final workDone = status == 'completed';
    final iConfirmed = applicant['employer_completed_at'] != null;
    final theyConfirmed = applicant['worker_completed_at'] != null;

    /*
        Not before the work was due to finish.

        The same rule as the activity lists and the server: no Mark complete
        until the job's last day, and a line saying when it opens instead.
    */
    final dueNote = job?.deadlineNote;

    // See the note on the cards in My Activity: the control is there as
    // soon as somebody is hired, and asks the other side when it is early.
    final canConfirm = status == 'accepted' && !iConfirmed;
    final early = !(job?.completionHasOpened ?? true);

    final String? reviewNote = !workDone && status != 'accepted'
        ? null
        : !workDone
            ? (iConfirmed
                ? 'Waiting for $name to confirm'
                : theyConfirmed
                    ? '$name marked this done — confirm to finish it'
                    : dueNote)
            : iReviewedThem && theyReviewedMe
                ? 'You both reviewed each other'
                : iReviewedThem
                    ? 'Review sent · waiting for theirs'
                    : theyReviewedMe
                        ? 'They reviewed you — yours unlocks theirs'
                        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // The whole identity block opens the profile, so the card no longer
      // needs a full-width "View full profile" button under a divider. That
      // button, the divider and their padding were roughly a third of the
      // card's height for something a tap on the person's own name does more
      // naturally.
      child: InkWell(
        onTap: workerId == null
            ? null
            : () => AppRouter.push(context, '/worker-profile',
                arguments: {'workerId': workerId}),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage:
                        photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isNotEmpty
                        ? null
                        : Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.neutral900,
                                  )),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 5),
                              const Icon(Icons.verified,
                                  size: 15, color: AppColors.success),
                            ],
                            // Beside the name, because it is a fact about this
                            // person and it is the single most useful thing an
                            // employer can know when choosing between
                            // applicants: they have already done work for you.
                            if (timesHiredBefore > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.replay,
                                        size: 11, color: AppColors.success),
                                    const SizedBox(width: 3),
                                    Text(
                                      /*
                                          "Hired 2x" sat next to the Accept
                                          button and read as an instruction —
                                          hire them twice — rather than as
                                          history. The word "before" is what
                                          makes it past tense at a glance.
                                      */
                                      timesHiredBefore == 1
                                          ? 'Hired before'
                                          : 'Hired ${timesHiredBefore}x before',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.success),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Rating and applied-time share one line instead of
                        // stacking, and an unrated worker says so rather than
                        // leaving a gap that reads as missing data.
                        // The star is an icon, like everywhere else in the
                        // app. It used to be the character U+2605, which
                        // renders in whatever the device has for it - a
                        // different weight and size from the real one, and a
                        // box on a handset that has neither.
                        Row(
                          children: [
                            if (reviewCount > 0) ...[
                              const Icon(Icons.star,
                                  size: 13, color: AppColors.accent),
                              const SizedBox(width: 3),
                            ],
                            Flexible(
                              child: Text(
                                reviewCount > 0
                                    ? '${rating.toStringAsFixed(1)} · $reviewCount review'
                                        '${reviewCount == 1 ? '' : 's'}'
                                    : 'No reviews yet',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: reviewCount > 0
                                      ? AppColors.neutral600
                                      : AppColors.neutral400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (status != 'pending') _statusBadge(status),
                  if (workerId != null)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.chevron_right,
                          size: 20, color: AppColors.neutral400),
                    ),
                ],
              ),
              if (skills.isNotEmpty) ...[
                const SizedBox(height: 9),
                _skillChips(skills, limit: premium ? null : 3),
              ],
              // What a top-up buys a worker: their resume, open on the
              // employer's screen. Everybody else's is one tap away on
              // the profile, in the same place in the same list.
              if (premium) _ResumeBlock(applicant: applicant),
            if (showActions) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      // No spot left to accept into. The server refuses
                      // too; this just says so before the tap.
                      onPressed: full
                          ? null
                          : () => confirmRespondToApplicant(context, applicationId, name,
                              accept: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      child: Text(full ? 'Spots filled' : 'Accept'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => confirmRespondToApplicant(context, applicationId, name,
                          accept: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error.withValues(alpha: 0.1),
                        foregroundColor: AppColors.error,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
            if (status == 'accepted' && perWorkerActions) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        // Straight into this applicant's thread.
                        //
                        // This used to push '/messages', the whole inbox — so
                        // "Message Juan" fetched every conversation the
                        // employer has, then asked them to find Juan again by
                        // name. Two round trips and a search to reach a thread
                        // the applicant list already identifies. It also took
                        // the bottom navigation away, because the inbox is a
                        // tab being pushed on top of the shell.
                        //
                        // Null only if the conversation somehow does not exist
                        // for an accepted application; the button disables
                        // rather than pretending.
                        onPressed: conversationId == null
                            ? null
                            : () => AppRouter.push(context,
                                  '/chat',
                                  arguments: {
                                    'conversationId': conversationId,
                                    'name': name,
                                    'jobTitle': jobTitle,
                                    'jobId': jobId,
                                    'otherUserId': workerId,
                                    'isVerified': isVerified,
                                    'applicationId': applicationId,
                                    'jobStatus': jobStatus,
                                    'myRole': 'employer',
                                    'otherRole': 'worker',
                                  },
                                ),
                        icon: const Icon(Icons.message_outlined, size: 16),
                        label: const Text('Message'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    // The review screen and its route both existed, and the
                    // API worked — but nothing in the app ever opened it, so
                    // no review could be left by anyone. This is the employer's
                    // way in; the worker's is on the applications screen.
                    //
                    // Only once the job is completed, because the server
                    // refuses a review before that. Offering the button
                    // earlier would just produce a rejection the user can't
                    // act on.
                    // Complete first, then review. Never both — you cannot
                    // review work that is not finished — so one slot serves
                    // each in turn.
                    //
                    // The review button is hidden once used: the server refuses
                    // a second one, so leaving it there produced a rejection
                    // the employer could not act on.
                    if (canConfirm || (workDone && !iReviewedThem)) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: canConfirm
                              ? () => confirmCompletion(context, applicationId,
                                  'worker', onChanged,
                                  early: early)
                              // Awaited and refreshed on success, same reason
                              // as the two review sites in My Activity: this
                              // pushed and forgot, so a submitted review left
                              // the button live until the list was reloaded by
                              // some other means.
                              : () async {
                                  final done = await AppRouter.push(context,
                                    '/leave-review',
                                    arguments: {
                                      'revieweeId': workerId,
                                      'revieweeName': name,
                                      'revieweeRole': 'worker',
                                      'jobId': jobId,
                                      'jobTitle': jobTitle,
                                    },
                                  );
                                  if (done == true) await onChanged();
                                },
                          icon: Icon(
                              canConfirm
                                  ? Icons.check_circle_outline
                                  : Icons.star_outline,
                              size: 16),
                          label: Text(canConfirm ? 'Mark Complete' : 'Review'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.neutral900,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (reviewNote != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.rate_review_outlined,
                          size: 14, color: AppColors.neutral400),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(reviewNote,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.neutral600)),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Shows at most three skills, then how many are left.
  ///
  /// A worker with twelve skills used to wrap into four rows of chips, which
  /// pushed Accept and Reject off the bottom of a phone screen — the employer
  /// had to scroll past someone's entire skill list to act on them. Three is
  /// enough to judge relevance; the full set is a tap away on the profile.

  Widget _skillChips(List<String> skills, {int? limit = 3}) {
    final shown = limit == null ? skills : skills.take(limit).toList();
    final remaining = skills.length - shown.length;

    Widget chip(String label, {bool muted = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: muted
                ? AppColors.neutral100
                : AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: muted ? AppColors.neutral500 : AppColors.primary)),
        );

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...shown.map(chip),
        if (remaining > 0) chip('+$remaining more', muted: true),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'accepted':
        color = AppColors.success;
        label = 'Accepted';
        break;
      case 'rejected':
        color = AppColors.error;
        label = 'Rejected';
        break;
      default:
        color = AppColors.warning;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

}

/// Accept or reject one applicant, after asking. Shared by the Applicants
/// screen and the home screen, so both say the same thing and both report a
/// clash the hire cleared.
void confirmRespondToApplicant(
BuildContext context,
int applicationId,
String name, {
required bool accept,
}) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(accept ? 'Accept Applicant?' : 'Reject Applicant?'),
      content: Text(accept
          ? 'Accept $name? You can message each other after.'
          : 'Reject $name?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            final provider = context.read<ApplicationProvider>();
            final ok = await provider.respondToApplicant(applicationId,
                accept: accept);
            if (!context.mounted) return;

            // Say when the hire cleared the worker's clashing applications.
            // The employer is the one who caused it, so they are the one who
            // should hear about it rather than discovering it later.
            final cleared = provider.lastAcceptCancelledCount;
            final suffix = accept && cleared > 0
                ? '. $cleared clashing application'
                    '${cleared == 1 ? '' : 's'} cancelled'
                : '';

            AppToast.info(context, ok
                  ? '$name ${accept ? 'accepted' : 'rejected'}$suffix'
                  : provider.applicantsErrorMessage ?? 'Something went wrong');
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: accept ? AppColors.success : AppColors.error),
          child: Text(accept ? 'Accept' : 'Reject',
              style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

/*
    The open resume, for a worker who has topped up.

    The same facts the profile page holds, so nothing here is information a
    free worker's employer cannot reach - it is just already on screen.
    Licence and certificate names only; the scans carry a date of birth and
    an address and stay behind the profile's own access rule.
*/
class _ResumeBlock extends StatelessWidget {
  const _ResumeBlock({required this.applicant});

  final Map<String, dynamic> applicant;

  List<String> _names(String key) =>
      (applicant[key] as List?)
          ?.map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList() ??
      const [];

  @override
  Widget build(BuildContext context) {
    final experience = (applicant['experience_label'] ?? '').toString();
    final jobsDone = asInt(applicant['jobs_completed']);
    final licenses = _names('licenses');
    final certifications = _names('certifications');

    final rows = <(IconData, String)>[
      if (experience.isNotEmpty) (Icons.work_history_outlined, experience),
      if (jobsDone > 0)
        (Icons.task_alt, '$jobsDone job${jobsDone == 1 ? '' : 's'} done on KAYA'),
      for (final l in licenses) (Icons.badge_outlined, l),
      for (final c in certifications) (Icons.workspace_premium_outlined, c),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (icon, text) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 15, color: AppColors.neutral500),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.neutral700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
