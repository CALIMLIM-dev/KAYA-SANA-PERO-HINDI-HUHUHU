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
import 'fit_facts.dart';
import '../../jobs/widgets/fit_line.dart';

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
              ],
      ];

    if (premium) {
      return _ResumeCard(
        applicant: applicant,
        name: name,
        photoUrl: photoUrl,
        rating: rating,
        reviewCount: reviewCount,
        timesHiredBefore: timesHiredBefore,
        skills: skills,
        statusBadge: status != 'pending' ? _statusBadge(status) : null,
        rank: rank,
        onOpen: workerId == null
            ? null
            : () => AppRouter.push(context, '/worker-profile',
                arguments: {'workerId': workerId}),
        actions: actions,
      );
    }

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
              if (rank != null || applicant['is_new'] == true) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (rank != null) RankPill(rank: rank!),
                    if (applicant['is_new'] == true) const NewOnKayaTag(),
                  ],
                ),
                const SizedBox(height: 8),
              ],
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
                            const SizedBox(width: 6),
                            VerificationChip(state: VerificationState.of(applicant), size: 10),
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
                _skillChips(skills),
              ],
              // Why they sit where they do, in checkable words.
              if (employerFitLine(applicant) != null) ...[
                const SizedBox(height: 9),
                FitLine(
                  text: employerFitLine(applicant)!,
                  strong: meetsRequirements(applicant),
                ),
              ],
              // The job's hiring criteria, met or not.
              if (CriteriaFacts.hasAny(applicant)) ...[
                const SizedBox(height: 6),
                CriteriaFacts(row: applicant),
              ],
              ...actions,
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
    A worker who has topped up, as a resume.

    Ranking is free; this is what a top-up buys a worker. Their card arrives
    as a resume in the app's primary blue: who they are and where, the three
    numbers an employer weighs first, every skill, then licences and
    certificates as their own sections. A free worker's card stays as it was,
    in the same place in the list, one tap from the same profile - premium
    adds, it never removes.

    Licence and certificate names only; the scans carry a date of birth and
    an address and stay behind the profile's own access rule.
*/
class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
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
    final category = (applicant['category'] ?? '').toString();
    final location = (applicant['location'] ?? '').toString();
    final experience = (applicant['experience_label'] ?? '').toString();
    final jobsDone = asInt(applicant['jobs_completed']);
    final licenses = _names('licenses');
    final certifications = _names('certifications');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpen,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      backgroundImage:
                          photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isNotEmpty
                          ? null
                          : Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            VerificationChip(
                              state: VerificationState.of(applicant),
                              size: 10.5,
                              onDark: true,
                            ),
                          ],
                        ),
                        if (category.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ],
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.place_outlined,
                                  size: 13, color: Colors.white.withValues(alpha: 0.8)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (rank != null) RankPill(rank: rank!, onDark: true),
                            _pill(Icons.workspace_premium_outlined, 'Full profile'),
                            if (applicant['is_new'] == true) const NewOnKayaTag(onDark: true),
                            if (timesHiredBefore > 0)
                              _pill(
                                Icons.replay,
                                timesHiredBefore == 1
                                    ? 'Hired before'
                                    : 'Hired ${timesHiredBefore}x before',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (statusBadge != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: statusBadge,
                      ),
                    ),
                  if (onOpen != null)
                    Icon(Icons.chevron_right,
                        size: 22, color: Colors.white.withValues(alpha: 0.85)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (employerFitLine(applicant) != null) ...[
                  FitLine(
                    text: employerFitLine(applicant)!,
                    strong: meetsRequirements(applicant),
                  ),
                  const SizedBox(height: 8),
                ],
                if (CriteriaFacts.hasAny(applicant)) ...[
                  CriteriaFacts(row: applicant),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _stat(
                        experience.isNotEmpty ? experience : 'Not listed',
                        'Experience',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _stat('$jobsDone', 'Jobs done')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _stat(
                        reviewCount > 0 ? rating.toStringAsFixed(1) : 'New',
                        reviewCount > 0
                            ? '$reviewCount review${reviewCount == 1 ? '' : 's'}'
                            : 'No reviews',
                        star: reviewCount > 0,
                      ),
                    ),
                  ],
                ),
                if (skills.isNotEmpty) ...[
                  _sectionLabel('Skills'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in skills)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (licenses.isNotEmpty) ...[
                  _sectionLabel('Licences'),
                  for (final l in licenses) _line(Icons.badge_outlined, l),
                ],
                if (certifications.isNotEmpty) ...[
                  _sectionLabel('Certificates'),
                  for (final c in certifications)
                    _line(Icons.workspace_premium_outlined, c),
                ],
                const SizedBox(height: 4),
                ...actions,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );

  Widget _stat(String value, String label, {bool star = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.neutral50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (star) ...[
                    const Icon(Icons.star, size: 14, color: AppColors.accent),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.neutral900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.neutral500),
            ),
          ],
        ),
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 7),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.neutral500,
          ),
        ),
      );

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 13, color: AppColors.neutral800),
              ),
            ),
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
class RankPill extends StatelessWidget {
  const RankPill({super.key, required this.rank, this.onDark = false});

  final int rank;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final best = rank == 1;
    final Color fg = onDark ? (best ? AppColors.primary : Colors.white) : (best ? Colors.white : AppColors.primary);
    final Color bg = onDark
        ? (best ? Colors.white : Colors.white.withValues(alpha: 0.18))
        : (best ? AppColors.primary : AppColors.primary.withValues(alpha: 0.08));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: onDark && !best ? Border.all(color: Colors.white.withValues(alpha: 0.35)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(best ? Icons.emoji_events_outlined : Icons.leaderboard_outlined, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            best ? '#1 Best fit' : '#$rank',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg),
          ),
        ],
      ),
    );
  }
}