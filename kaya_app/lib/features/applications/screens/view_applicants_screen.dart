import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/realtime_refresh.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/json_parse.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../core/widgets/app_toast.dart';
import '../widgets/completion_action.dart';

/// View Applicants Screen — employer sees everyone who actually applied to a
/// job, via GET /jobs/{job}/applicants.
///
/// This used to render five hardcoded applicants (Juan Dela Cruz, Pedro
/// Santos, Mario Reyes...) on every job regardless of who applied, and Accept/
/// Reject only flipped local state — nothing was sent to the server.
class ViewApplicantsScreen extends StatefulWidget {
  const ViewApplicantsScreen({super.key});

  @override
  State<ViewApplicantsScreen> createState() => _ViewApplicantsScreenState();
}

class _ViewApplicantsScreenState extends State<ViewApplicantsScreen>
    with SingleTickerProviderStateMixin, RealtimeRefresh {
  late TabController _tabController;
  int? _jobId;
  bool _initialized = false;

  /// Job status and title, needed to decide whether reviewing is possible.
  ///
  /// Read from JobProvider rather than route arguments: four different screens
  /// push here and all of them pass only `jobId`. Requiring every caller to
  /// also pass status and title would mean the Review button silently fails to
  /// appear wherever someone forgot.
  String get _jobStatus =>
      context.watch<JobProvider>().selectedJob?.status ?? '';
  String get _jobTitle =>
      context.watch<JobProvider>().selectedJob?.title ?? 'this job';

  // Completion and reviewing are now judged per hire rather than per job — a
  // job with two people on it only finishes once both are done, and the first
  // pair should not have to wait on the second. See _buildApplicantCard.

  /// An employer watching this screen sees a new applicant appear without
  /// touching anything — which is the moment they most want to act on.
  @override
  List<String> get refreshOn => const ['application.'];

  @override
  void onRealtimeRefresh() {
    if (_jobId == null) return;
    context.read<ApplicationProvider>().fetchApplicants(_jobId!);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    _jobId = args is Map ? args['jobId'] as int? : args as int?;

    if (_jobId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ApplicationProvider>().fetchApplicants(_jobId!);
        // Needed for the job's status and title — callers only pass the id.
        context.read<JobProvider>().fetchJobDetail(_jobId!);
        bindRealtimeRefresh();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _byStatus(
          List<Map<String, dynamic>> applicants, String status) =>
      applicants.where((a) => a['application_status'] == status).toList();

  @override
  Widget build(BuildContext context) {
    if (_jobId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Applicants')),
        body: const Center(child: Text('No job specified.')),
      );
    }

    return Consumer<ApplicationProvider>(
      builder: (context, provider, _) {
        final all = provider.applicants;
        final pending = _byStatus(all, 'pending');
        final accepted = _byStatus(all, 'accepted');
        final rejected = _byStatus(all, 'rejected');

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text('Applicants',
                style: TextStyle(fontWeight: FontWeight.w600)),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accent,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              tabs: [
                Tab(text: 'Pending (${pending.length})'),
                Tab(text: 'Accepted (${accepted.length})'),
                Tab(text: 'Rejected (${rejected.length})'),
              ],
            ),
          ),
          body: provider.isApplicantsLoading && all.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : provider.applicantsErrorMessage != null && all.isEmpty
                  ? _errorState(provider.applicantsErrorMessage!)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(pending, showActions: true),
                        _buildList(accepted, showActions: false),
                        _buildList(rejected, showActions: false),
                      ],
                    ),
        );
      },
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: AppColors.neutral300),
            const SizedBox(height: 16),
            const Text('Could not load applicants',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral600)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: AppColors.neutral400)),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () =>
                  context.read<ApplicationProvider>().fetchApplicants(_jobId!),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> applicants,
      {required bool showActions}) {
    if (applicants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 56, color: AppColors.neutral300),
            const SizedBox(height: 16),
            const Text('No applicants here',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          context.read<ApplicationProvider>().fetchApplicants(_jobId!),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: applicants.length,
        itemBuilder: (context, index) =>
            _buildApplicantCard(applicants[index], showActions: showActions),
      ),
    );
  }

  Widget _buildApplicantCard(Map<String, dynamic> applicant,
      {required bool showActions}) {
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

    final canConfirm = status == 'accepted' && !iConfirmed;

    final String? reviewNote = !workDone && status != 'accepted'
        ? null
        : !workDone
            ? (iConfirmed
                ? 'Waiting for $name to confirm'
                : theyConfirmed
                    ? '$name marked this done — confirm to finish it'
                    : null)
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
            : () => Navigator.pushNamed(context, '/worker-profile',
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
                                      timesHiredBefore == 1
                                          ? 'Hired before'
                                          : 'Hired ${timesHiredBefore}x',
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
                        Text(
                          reviewCount > 0
                              ? '★ ${rating.toStringAsFixed(1)} · $reviewCount review'
                                  '${reviewCount == 1 ? '' : 's'}'
                              : 'No reviews yet',
                          style: TextStyle(
                            fontSize: 12,
                            color: reviewCount > 0
                                ? AppColors.neutral600
                                : AppColors.neutral400,
                          ),
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
            if (showActions) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _confirmRespond(applicationId, name,
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
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _confirmRespond(applicationId, name,
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
            if (status == 'accepted') ...[
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
                            : () => Navigator.pushNamed(
                                  context,
                                  '/chat',
                                  arguments: {
                                    'conversationId': conversationId,
                                    'name': name,
                                    'jobTitle': _jobTitle,
                                    'jobId': _jobId,
                                    'otherUserId': workerId,
                                    'isVerified': isVerified,
                                    'applicationId': applicationId,
                                    'jobStatus': _jobStatus,
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
                                  'worker', () => context
                                      .read<ApplicationProvider>()
                                      .fetchApplicants(_jobId!))
                              : () => Navigator.pushNamed(
                                    context,
                                    '/leave-review',
                                    arguments: {
                                      'revieweeId': workerId,
                                      'revieweeName': name,
                                      'revieweeRole': 'worker',
                                      'jobId': _jobId,
                                      'jobTitle': _jobTitle,
                                    },
                                  ),
                          icon: Icon(
                              canConfirm
                                  ? Icons.check_circle_outline
                                  : Icons.star_outline,
                              size: 16),
                          label: Text(canConfirm ? 'Mark complete' : 'Review'),
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
  Widget _skillChips(List<String> skills) {
    const limit = 3;
    final shown = skills.take(limit).toList();
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

  void _confirmRespond(int applicationId, String name, {required bool accept}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(accept ? 'Accept Applicant?' : 'Reject Applicant?'),
        content: Text(accept
            ? 'Accept $name? Messaging will be unlocked between you.'
            : 'Reject $name?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider = context.read<ApplicationProvider>();
              final ok = await provider.respondToApplicant(applicationId,
                  accept: accept);
              if (!mounted) return;

              // Say when the hire cleared the worker's clashing applications.
              // The employer is the one who caused it, so they are the one who
              // should hear about it rather than discovering it later.
              final cleared = provider.lastAcceptCancelledCount;
              final suffix = accept && cleared > 0
                  ? ' — $cleared clashing application'
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
}
