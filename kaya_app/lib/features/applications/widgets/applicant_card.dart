import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/utils/json_parse.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/verification_badge_widget.dart';
import '../../../data/models/job_model.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/job_provider.dart';
import 'completion_action.dart';
import 'hire_controls.dart';
import 'fit_facts.dart';
import '../../jobs/widgets/fit_line.dart';
import '../../../core/utils/job_summary.dart';

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
    this.rank,
  });

  final Map<String, dynamic> applicant;

  /// Place in the best-fit order, 1 first. Null where the list is not a
  /// ranking (accepted and rejected).
  final int? rank;
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
    final hireControls = HireControls.maybe(
      actions: applicant['hire_actions'],
      applicationId: applicant['application_id'],
      otherName: (applicant['worker_name'] ?? 'the worker').toString(),
      otherId: applicant['worker_id'],
      onChanged: onChanged,
    );
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

    // Accept and Reject, then Message and Mark complete or Review once
    // hired. The same rows under either layout.
    final actions = <Widget>[
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
                      child: Text(full ? 'Spots Filled' : 'Accept'),
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
            // Finished hires too: on a job for several people this is the
            // only place the employer can review each one.
            if ((status == 'accepted' || workDone) && perWorkerActions) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Not once the work is done: the thread closes with it.
                    if (!workDone)
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
                                    'verificationState': applicant['verification_state'],
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
                      if (!workDone) const SizedBox(width: 8),
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
                          label: Text(canConfirm ? 'Mark as Complete' : 'Review'),
                          // Finishing in green and rating in the primary
                          // blue, the same as the Active and History cards.
                          // Both were a yellow fill here.
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                canConfirm ? AppColors.success : AppColors.primary,
                            foregroundColor: Colors.white,
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
                if (hireControls != null) ...[
                  const SizedBox(height: 4),
                  hireControls,
                ],
              ],
      ];

    final openProfile = workerId == null
        ? null
        : () => AppRouter.push(context, '/worker-profile',
            arguments: {'workerId': workerId});

    /*
        A topped-up worker's application arrives as the full card; a free
        one as their name.

        Being read in full is what a top-up buys a worker. The free row is
        the same person at the same rank, with the same buttons and one tap
        from the same profile - it just does not lay their case out for
        them. The verification mark stays on both: the panel asked that
        verified and unverified accounts be told apart everywhere.
    */
    if (premium) {
      return _FullCard(
        applicant: applicant,
        name: name,
        photoUrl: photoUrl,
        rating: rating,
        reviewCount: reviewCount,
        timesHiredBefore: timesHiredBefore,
        skills: skills,
        statusBadge: status != 'pending' ? _statusBadge(status) : null,
        rank: rank,
        onOpen: openProfile,
        actions: actions,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: openProfile,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  if (rank != null) RankNumber(rank: rank!),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.neutral900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        VerificationChip(state: VerificationState.of(applicant), size: 10),
                      ],
                    ),
                  ),
                  if (status != 'pending') _statusBadge(status),
                  if (openProfile != null)
                    const Icon(Icons.chevron_right, size: 20, color: AppColors.neutral400),
                ],
              ),
            ),
          ),
          ...actions,
        ],
      ),
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

            // The job's state just changed - a hire puts it in progress -
            // and home's Active list reads the employer's jobs. Without this
            // the hire did not appear there until something else refetched.
            if (ok) await context.read<JobProvider>().fetchMyJobs();
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
    A topped-up worker's application, in full.

    The facts a hirer weighs, as plain lines: who and where and when they
    applied, how they fit this job, experience, finished jobs and rating,
    whether you have hired them before, every skill, then the licence and
    certificate names. White, like every other card in the app: the blue
    header and the pills it had read as a template rather than a person.

    Licence and certificate names only; the scans carry a date of birth and
    an address and stay behind the profile's own access rule.
*/
class _FullCard extends StatelessWidget {
  const _FullCard({
    required this.applicant,
    required this.name,
    required this.photoUrl,
    required this.rating,
    required this.reviewCount,
    required this.timesHiredBefore,
    required this.skills,
    required this.statusBadge,
    required this.onOpen,
    required this.actions,
    this.rank,
  });

  final int? rank;
  final Map<String, dynamic> applicant;
  final String name;
  final String photoUrl;
  final double rating;
  final int reviewCount;
  final int timesHiredBefore;
  final List<String> skills;
  final Widget? statusBadge;
  final VoidCallback? onOpen;
  final List<Widget> actions;

  List<String> _names(String key) =>
      (applicant[key] as List?)
          ?.map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList() ??
      const [];

  @override
  Widget build(BuildContext context) {
    final where = [
      (applicant['category'] ?? '').toString(),
      (applicant['location'] ?? '').toString(),
    ].where((s) => s.isNotEmpty).join(' · ');
    final applied = timeAgo(applicant['applied_at']?.toString());
    final experience = (applicant['experience_label'] ?? '').toString();
    final jobsDone = asInt(applicant['jobs_completed']);
    final licenses = _names('licenses');
    final certifications = _names('certifications');
    final fit = employerFitLine(applicant);

    const muted = TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.neutral600);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rank != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: RankNumber(rank: rank!),
                  ),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.neutral100,
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isNotEmpty
                      ? null
                      : Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.neutral600,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.neutral900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          VerificationChip(state: VerificationState.of(applicant), size: 10),
                        ],
                      ),
                      if (where.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(where, maxLines: 2, overflow: TextOverflow.ellipsis, style: muted),
                      ],
                      if (applied != null) ...[
                        const SizedBox(height: 1),
                        Text('Applied $applied',
                            style: const TextStyle(fontSize: 12, color: AppColors.neutral500)),
                      ],
                    ],
                  ),
                ),
                ?statusBadge,
                if (onOpen != null)
                  const Icon(Icons.chevron_right, size: 20, color: AppColors.neutral400),
              ],
            ),
          ),
          if (fit != null) ...[
            const SizedBox(height: 10),
            FitLine(text: fit, strong: meetsRequirements(applicant)),
          ],
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.neutral800),
              children: [
                TextSpan(text: experience.isNotEmpty ? '$experience experience' : 'No experience listed'),
                TextSpan(text: '  ·  $jobsDone job${jobsDone == 1 ? '' : 's'} done  ·  '),
                if (reviewCount > 0) ...[
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(Icons.star, size: 14, color: AppColors.accent),
                  ),
                  TextSpan(
                      text: ' ${rating.toStringAsFixed(1)} ($reviewCount review${reviewCount == 1 ? '' : 's'})'),
                ] else
                  TextSpan(
                      text: applicant['is_new'] == true ? 'New on KAYA' : 'No reviews yet'),
              ],
            ),
          ),
          if (timesHiredBefore > 0) ...[
            const SizedBox(height: 4),
            Text(
              timesHiredBefore == 1
                  ? 'Hired by you before'
                  : 'Hired by you $timesHiredBefore times',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.neutral800),
            ),
          ],
          if (skills.isNotEmpty) _detail('Skills', skills.join(', ')),
          if (licenses.isNotEmpty) _detail('Licences', licenses.join(', ')),
          if (certifications.isNotEmpty) _detail('Certificates', certifications.join(', ')),
          const SizedBox(height: 4),
          ...actions,
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.neutral500)),
            const SizedBox(height: 1),
            Text(value, style: const TextStyle(fontSize: 13.5, height: 1.35, color: AppColors.neutral900)),
          ],
        ),
      );
}

/*
    Where an applicant stands in the best-fit order.

    The Applicants list was already sorted by fit - trade, skills, distance -
    with nothing on screen saying so, so it read as arrival order. The place
    is shown instead of a score: a percentage invites arguing about the
    number, and the order is the useful part.
*/
class RankNumber extends StatelessWidget {
  const RankNumber({super.key, required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(right: 8),
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.neutral100, shape: BoxShape.circle),
      child: Text(
        '$rank',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.neutral700),
      ),
    );
  }
}
