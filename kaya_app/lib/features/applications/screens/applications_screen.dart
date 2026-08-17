import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/realtime_refresh.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/job_provider.dart';
import '../widgets/completion_action.dart';

/// My Activity.
///
/// The tab set follows which profiles the account holds:
///   worker only   → Applications | Completed | History
///   employer only → Active Jobs  | Completed | History
///   both          → Applications | Active Jobs | Completed | History
///
/// "Applications" are jobs you applied to (worker side). "Active Jobs" are jobs
/// you posted (employer side). They are different records from different
/// endpoints and were previously conflated into one "Active" tab.
class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen>
    with RealtimeRefresh {
  /// A worker sitting on this screen sees "accepted" land the moment the
  /// employer taps it — the single most important status change in the app.
  /// Invitations are included because accepting one creates an application.
  @override
  List<String> get refreshOn => const ['application.', 'invitation.', 'job.'];

  @override
  void onRealtimeRefresh() => _load();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      bindRealtimeRefresh();
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    final appMode = context.read<AppModeProvider>();

    // Only fetch the side(s) the account actually has.
    final futures = <Future<void>>[
      if (appMode.hasWorkerProfile)
        context.read<ApplicationProvider>().fetchMyApplications(),
      if (appMode.hasEmployerProfile) context.read<JobProvider>().fetchMyJobs(),
    ];

    await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AppModeProvider, ApplicationProvider, JobProvider>(
      builder: (context, appMode, applications, jobs, _) {
        final tabs = _buildTabs(appMode, applications, jobs);

        if (tabs.isEmpty) return _noProfileState();

        return DefaultTabController(
          // Keyed on the tab set so the controller is rebuilt if the user
          // creates their second profile while this screen is alive.
          key: ValueKey(tabs.map((t) => t.label).join('|')),
          length: tabs.length,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text('My Activity',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              bottom: TabBar(
                isScrollable: tabs.length > 3,
                tabAlignment:
                    tabs.length > 3 ? TabAlignment.start : TabAlignment.fill,
                indicatorColor: AppColors.accent,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
                tabs: [
                  for (final t in tabs) Tab(text: '${t.label} (${t.items.length})'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                for (final t in tabs)
                  _TabBody(
                    tab: t,
                    isLoading: t.isJobTab ? jobs.isLoading : applications.isLoading,
                    error: t.isJobTab ? jobs.errorMessage : applications.errorMessage,
                    onRefresh: _load,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_ActivityTab> _buildTabs(
    AppModeProvider appMode,
    ApplicationProvider applications,
    JobProvider jobs,
  ) {
    final hasWorker = appMode.hasWorkerProfile;
    final hasEmployer = appMode.hasEmployerProfile;

    final myApplications = applications.applications;
    final myJobs = jobs.jobs;

    String statusOf(Map<String, dynamic> m) => (m['status'] ?? '').toString();

    return [
      // Worker side: applications you sent that have no answer yet.
      if (hasWorker)
        _ActivityTab(
          label: 'Applications',
          isJobTab: false,
          emptyTitle: 'No applications yet',
          emptyBody: 'Browse jobs and start applying',
          /*
              Pending AND accepted.

              This listed pending only, and 'accepted' appears in no other tab
              either — Completed wants 'completed' and History wants rejected,
              withdrawn or cancelled. So the moment a worker was hired, the job
              disappeared from My Activity entirely, taking the Message button
              and Mark as complete with it. The one state where a worker has
              actual work to do was the one state with nowhere to show it.

              Found by mounting this screen against a real hire rather than by
              reading the filters.
          */
          items: myApplications
              .where((a) =>
                  statusOf(a) == 'pending' || statusOf(a) == 'accepted')
              .toList(),
        ),

      // Employer side: jobs you posted that are still running.
      if (hasEmployer)
        _ActivityTab(
          label: 'Active Jobs',
          isJobTab: true,
          emptyTitle: 'No active job posts',
          emptyBody: 'Post a job to start receiving applicants',
          items: myJobs
              .where((j) =>
                  statusOf(j) == 'open' || statusOf(j) == 'in_progress')
              .toList(),
        ),

      _ActivityTab(
        label: 'Completed',
        isJobTab: !hasWorker,
        emptyTitle: 'Nothing completed yet',
        emptyBody: 'Finished work will appear here',
        items: [
          if (hasWorker)
            ...myApplications.where((a) => statusOf(a) == 'completed'),
          if (hasEmployer) ...myJobs.where((j) => statusOf(j) == 'completed'),
        ],
      ),

      _ActivityTab(
        label: 'History',
        isJobTab: !hasWorker,
        emptyTitle: 'No history yet',
        emptyBody: 'Past activity will appear here',
        items: [
          if (hasWorker)
            ...myApplications.where((a) => const {
                  'rejected',
                  'withdrawn',
                  'cancelled',
                }.contains(statusOf(a))),
          if (hasEmployer)
            ...myJobs.where((j) => statusOf(j) == 'closed'),
        ],
      ),
    ];
  }

  Widget _noProfileState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('My Activity',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inbox_outlined,
                  size: 56, color: AppColors.neutral300),
              const SizedBox(height: 16),
              const Text('Nothing to show yet',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral600)),
              const SizedBox(height: 8),
              const Text(
                'Set up a worker profile to track applications, or an employer '
                'profile to track the jobs you post.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.neutral400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tab's definition and its rows.
class _ActivityTab {
  const _ActivityTab({
    required this.label,
    required this.items,
    required this.isJobTab,
    required this.emptyTitle,
    required this.emptyBody,
  });

  final String label;
  final List<Map<String, dynamic>> items;

  /// Job posts render differently from applications (applicant count vs status
  /// against an employer).
  final bool isJobTab;

  final String emptyTitle;
  final String emptyBody;
}

class _TabBody extends StatelessWidget {
  const _TabBody({
    required this.tab,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
  });

  final _ActivityTab tab;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isLoading && tab.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && tab.items.isEmpty) {
      return _message(
        icon: Icons.cloud_off,
        title: 'Could not load',
        body: error!,
        actionLabel: 'Retry',
        onAction: onRefresh,
      );
    }

    if (tab.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
            _message(icon: Icons.inbox_outlined, title: tab.emptyTitle, body: tab.emptyBody),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tab.items.length,
        itemBuilder: (_, i) => tab.isJobTab
            ? _JobPostCard(job: tab.items[i], onChanged: onRefresh)
            : _ApplicationCard(application: tab.items[i], onChanged: onRefresh),
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    String? actionLabel,
    Future<void> Function()? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.neutral300),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral600)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.neutral400)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(actionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Worker side — a job you applied to.
class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, required this.onChanged});

  final Map<String, dynamic> application;

  /// Called after a completion is recorded, so the list reloads and both cards
  /// pick up the new timestamps.
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final job = application['job'] as Map<String, dynamic>?;
    final employer = job?['employer'] as Map<String, dynamic>?;
    final status = (application['status'] ?? '').toString();

    /*
        Two-sided completion, worker's side.

        The employer used to decide alone and this application flipped to
        completed underneath the worker with no say in it. Now each side
        confirms, and the work is only done when both have.
    */
    final iConfirmed = application['worker_completed_at'] != null;
    final theyConfirmed = application['employer_completed_at'] != null;
    final isHired = status == 'accepted' || status == 'completed';
    final workDone = status == 'completed';

    final canConfirm = isHired && !workDone && !iConfirmed;

    /*
        Dual review, from the worker's side.

        The button used to appear on every completed job whether or not a
        review had already been left, so a second tap produced a 422 the user
        could do nothing about. And nothing ever said the employer had reviewed
        them — which is the half that makes people finish theirs.

        What their review actually says stays hidden until this side writes one.
        Reading it first and answering in kind is how a rating system turns into
        a negotiation.
    */
    final iReviewed = application['i_reviewed_them'] == true;
    final theyReviewed = application['they_reviewed_me'] == true;

    final canReview = workDone && employer != null && !iReviewed;

    final String? reviewNote = !isHired
        ? null
        : !workDone
            // Completion first — the review note would be noise before there is
            // anything to review.
            ? (iConfirmed
                ? 'Marked done · waiting for the employer to confirm'
                : theyConfirmed
                    ? 'The employer marked this done — confirm to finish it'
                    : null)
            : iReviewed && theyReviewed
                ? 'You both reviewed each other'
                : iReviewed
                    ? 'Review sent · waiting for theirs'
                    : theyReviewed
                        ? 'They reviewed you — yours unlocks theirs'
                        : null;

    // The worker's way into the thread, matching the employer's on the
    // applicant list. Before this the only route was the Messages tab, so one
    // direction of the same conversation was a tap and the other was a hunt.
    //
    // Null until the application is accepted — messaging unlocks on hire, so
    // there is genuinely nothing to open before that.
    final conversationId = application['conversation_id'] as int?;
    final canMessage = conversationId != null && employer != null;

    return _cardShell(
      title: (job?['title'] ?? 'Job').toString(),
      subtitle: (employer?['name'] ?? 'Employer').toString(),
      status: status,
      trailing: null,
      note: reviewNote,
      // Completion comes before reviewing, and they never both apply — you
      // cannot review work that is not finished — so one slot serves both.
      actionIcon: canConfirm ? Icons.check_circle_outline : Icons.star_outline,
      onMessage: !canMessage
          ? null
          : () => Navigator.pushNamed(
                context,
                '/chat',
                arguments: {
                  'conversationId': conversationId,
                  'name': (employer['name'] ?? 'Employer').toString(),
                  'jobTitle': (job?['title'] ?? 'Job').toString(),
                  'jobId': job?['id'],
                  'otherUserId': employer['id'],
                  'isVerified': (employer['is_verified'] as bool?) ?? false,
                  'applicationId': application['id'],
                  'jobStatus': job?['status'],
                  'myRole': 'worker',
                  'otherRole': 'employer',
                },
              ),
      actionLabel: canConfirm
          ? 'Mark as complete'
          : canReview
              ? 'Review employer'
              : null,
      onAction: canConfirm
          ? () => confirmCompletion(
                context, application['id'] as int, 'employer', onChanged)
          : !canReview
              ? null
              : () => Navigator.pushNamed(
                    context,
                    '/leave-review',
                    arguments: {
                      'revieweeId': employer['id'],
                      'revieweeName':
                          (employer['name'] ?? 'Employer').toString(),
                      'revieweeRole': 'employer',
                      'jobId': job!['id'],
                      'jobTitle': (job['title'] ?? 'this job').toString(),
                    },
                  ),
      onTap: job == null
          ? null
          : () => Navigator.pushNamed(context, '/job-details',
              arguments: {'jobId': job['id']}),
    );
  }
}

/// Employer side — a job you posted.
class _JobPostCard extends StatelessWidget {
  const _JobPostCard({required this.job, required this.onChanged});

  final Map<String, dynamic> job;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final applicants = job['application_count'] ?? 0;
    final status = (job['status'] ?? '').toString();

    /*
        Complete and review, on the job card itself.

        Both used to live three taps in — My Jobs, then Manage, then Applicants,
        and only then a Review button — which is why nobody found them. This
        card is where an employer looks when they think "that job is done", so
        this is where the buttons belong.

        Only when exactly one person was hired: with two, the card cannot say
        who you mean, so those still go through the applicants list. The server
        sends `hire` as null in that case rather than picking one.
    */
    final hire = job['hire'] as Map<String, dynamic>?;

    final iConfirmed = hire?['employer_completed_at'] != null;
    final workDone = hire?['status'] == 'completed';
    final canConfirm = hire != null && !workDone && !iConfirmed;
    final canReview = hire != null && workDone && hire['i_reviewed_them'] != true;

    final String? note = hire == null
        ? null
        : !workDone
            ? (iConfirmed ? 'Waiting for ${hire['worker_name']} to confirm' : null)
            : hire['i_reviewed_them'] == true
                ? 'You reviewed ${hire['worker_name']}'
                : null;

    return _cardShell(
      title: (job['title'] ?? 'Job').toString(),
      subtitle: (job['location'] ?? '').toString(),
      status: status,
      trailing: '$applicants applicant${applicants == 1 ? '' : 's'}',
      note: note,
      actionIcon: canConfirm ? Icons.check_circle_outline : Icons.star_outline,
      actionLabel: canConfirm
          ? 'Mark as complete'
          : canReview
              ? 'Review ${hire['worker_name'] ?? 'worker'}'
              : null,
      onAction: canConfirm
          ? () => confirmCompletion(
                context, hire['application_id'] as int, 'worker', onChanged)
          : !canReview
              ? null
              : () => Navigator.pushNamed(
                    context,
                    '/leave-review',
                    arguments: {
                      'revieweeId': hire['worker_id'],
                      'revieweeName': (hire['worker_name'] ?? 'Worker').toString(),
                      'revieweeRole': 'worker',
                      'jobId': job['id'],
                      'jobTitle': (job['title'] ?? 'this job').toString(),
                    },
                  ),
      onTap: () => Navigator.pushNamed(context, '/view-applicants',
          arguments: {'jobId': job['id']}),
    );
  }
}

Widget _cardShell({
  required String title,
  required String subtitle,
  required String status,
  required String? trailing,
  VoidCallback? onTap,
  /// Optional call to action shown under the card — currently "Review
  /// employer", offered only once a job is completed.
  String? actionLabel,
  VoidCallback? onAction,
  /// Icon on the action button. Defaults to the review star; completion uses a
  /// tick, because a star on "Mark as complete" reads like a rating.
  IconData actionIcon = Icons.star_outline,
  /// Optional "Message" button, shown once a conversation exists. Sits beside
  /// the action when both are present rather than stacking, so an accepted and
  /// completed job does not grow two full-width buttons.
  VoidCallback? onMessage,
  /// Optional one-line state under the buttons — currently where the mutual
  /// review stands. A sentence, because a badge cannot say "waiting for theirs".
  String? note,
}) {
  final (bg, fg, label) = _statusStyle(status);

  return Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: AppColors.neutral200),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: fg)),
                ),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 13.5, color: AppColors.neutral600)),
            ],
            if (onMessage != null || (actionLabel != null && onAction != null)) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onMessage != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onMessage,
                        icon: const Icon(Icons.message_outlined, size: 16),
                        label: const Text('Message'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  if (onMessage != null && actionLabel != null && onAction != null)
                    const SizedBox(width: 8),
                  if (actionLabel != null && onAction != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onAction,
                        icon: Icon(actionIcon, size: 16),
                        label: Text(actionLabel, overflow: TextOverflow.ellipsis),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.neutral900,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (note != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.rate_review_outlined,
                      size: 14, color: AppColors.neutral400),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(note,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.neutral600)),
                  ),
                ],
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.people_outline,
                      size: 15, color: AppColors.neutral400),
                  const SizedBox(width: 6),
                  Text(trailing,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.neutral600)),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

(Color, Color, String) _statusStyle(String status) => switch (status) {
      'pending' => (
          AppColors.warning.withValues(alpha: 0.12),
          AppColors.warning,
          'Pending'
        ),
      'accepted' => (
          AppColors.success.withValues(alpha: 0.12),
          AppColors.success,
          'Accepted'
        ),
      'open' => (
          AppColors.success.withValues(alpha: 0.12),
          AppColors.success,
          'Open'
        ),
      'in_progress' => (
          AppColors.primary.withValues(alpha: 0.12),
          AppColors.primary,
          'In Progress'
        ),
      'completed' => (
          AppColors.primary.withValues(alpha: 0.12),
          AppColors.primary,
          'Completed'
        ),
      'rejected' => (
          AppColors.error.withValues(alpha: 0.12),
          AppColors.error,
          'Rejected'
        ),
      'withdrawn' => (
          AppColors.neutral200,
          AppColors.neutral600,
          'Withdrawn'
        ),
      'cancelled' => (
          AppColors.neutral200,
          AppColors.neutral600,
          'Cancelled'
        ),
      'closed' => (AppColors.neutral200, AppColors.neutral600, 'Closed'),
      _ => (AppColors.neutral200, AppColors.neutral600, status),
    };
