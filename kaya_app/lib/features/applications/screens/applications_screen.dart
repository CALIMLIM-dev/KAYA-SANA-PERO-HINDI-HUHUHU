import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/realtime_refresh.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/invitation_provider.dart';
import '../../../providers/job_provider.dart';
import '../widgets/completion_action.dart';

/// My Activity.
///
/// A worker's two incoming lists — Applications (jobs you applied to) and
/// Invitations (offers sent to you) — are buttons at the top, each opening its
/// own sheet. They used to be tabs, where "Applications" sat beside the
/// employer's "Active Jobs" and read as the same thing though they are opposite
/// sides of the marketplace.
///
/// The tabs are the job lifecycle everyone shares:
///   worker only   → Completed | History
///   employer only → Active Jobs | Completed | History
///   both          → Active Jobs | Completed | History
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
      // Invitations were only reachable by tapping a notification, so a worker
      // who missed it had no way back to them. They belong on the worker's
      // activity beside their applications.
      if (appMode.hasWorkerProfile)
        context.read<InvitationProvider>().fetchMyInvitations(),
      if (appMode.hasEmployerProfile) context.read<JobProvider>().fetchMyJobs(),
    ];

    await Future.wait(futures);
  }

  /// Pending or accepted — the applications a worker is still living with,
  /// which is what the Applications button counts and lists.
  static bool _isActiveApplication(Map<String, dynamic> a) {
    final s = (a['status'] ?? '').toString();
    return s == 'pending' || s == 'accepted';
  }

  /// The worker's applications, in a sheet rather than a tab.
  void _openApplications(BuildContext context, ApplicationProvider provider) {
    final items =
        provider.applications.where(_isActiveApplication).toList();
    _showListSheet(
      context,
      title: 'My Applications',
      emptyTitle: 'No active applications',
      emptyBody: 'Jobs you apply to appear here until they finish.',
      children: [
        for (final a in items) _ApplicationCard(application: a, onChanged: _load),
      ],
    );
  }

  /// The worker's pending invitations, in a sheet.
  void _openInvitations(BuildContext context, InvitationProvider provider) {
    final items = provider.invitations
        .where((i) => (i['status'] ?? '') == 'pending')
        .toList();
    _showListSheet(
      context,
      title: 'Invitations',
      emptyTitle: 'No invitations',
      emptyBody: 'Employers who invite you to a job will show up here.',
      children: [
        for (final i in items) _InvitationCard(invitation: i),
      ],
    );
  }

  /// One sheet shape for both, so they read as the same kind of thing.
  void _showListSheet(
    BuildContext context, {
    required String title,
    required String emptyTitle,
    required String emptyBody,
    required List<Widget> children,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Row(
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: children.isEmpty
                    ? _EmptyState(title: emptyTitle, body: emptyBody)
                    : ListView(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: children,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<AppModeProvider, ApplicationProvider, JobProvider,
        InvitationProvider>(
      builder: (context, appMode, applications, jobs, invitations, _) {
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
            body: Column(
              children: [
                // Worker's incoming lists, as buttons that open their own
                // sheet — see the note in _buildTabs for why they are not tabs.
                if (appMode.hasWorkerProfile)
                  _WorkerInboxButtons(
                    applicationCount: applications.applications
                        .where((a) => _isActiveApplication(a))
                        .length,
                    invitationCount: invitations.invitations
                        .where((i) => (i['status'] ?? '') == 'pending')
                        .length,
                    onApplications: () => _openApplications(context, applications),
                    onInvitations: () => _openInvitations(context, invitations),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final t in tabs)
                        _TabBody(
                          tab: t,
                          isLoading: t.isJobTab
                              ? jobs.isLoading
                              : applications.isLoading,
                          error: t.isJobTab
                              ? jobs.errorMessage
                              : applications.errorMessage,
                          onRefresh: _load,
                        ),
                    ],
                  ),
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

    /*
        Applications and Invitations are not tabs any more.

        A hybrid account had five tabs across the top — Invitations,
        Applications, Active Jobs, Completed, History — and "Applications" (the
        jobs you applied to) sat one along from "Active Jobs" (the jobs you
        posted), which read as the same thing and were opposite sides of the
        marketplace. Both of the worker's incoming lists are buttons above the
        tabs now, each opening its own sheet, so the tabs are left to the job
        lifecycle everyone shares.
    */
    return [
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
          /*
              Everything that is not active and not completed.

              Named 'closed' alone, which left a hole: the jobs_posts enum
              also has 'flagged', and a flagged job then belonged to no tab at
              all — an employer whose post was pulled for moderation would
              find it simply gone from their own list, with nothing to say
              where it went or why.

              Nothing sets 'flagged' today, so this is a hole waiting rather
              than one anyone has fallen in. Written as "not shown elsewhere"
              so a new terminal status lands here on its own instead of
              vanishing.
          */
          if (hasEmployer)
            ...myJobs.where((j) => !const {
                  'open',
                  'in_progress',
                  'completed',
                }.contains(statusOf(j))),
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
    this.isJobTab = false,
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
            : _ApplicationCard(
                application: tab.items[i], onChanged: onRefresh),
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
/// A pending invitation on the worker's activity.
///
/// The accept and decline flow, with its confirmations and the message button
/// that appears after accepting, already lives in full on the invitations
/// screen. Rather than build a second copy of it here, this card carries the
/// job and employer and opens that screen on tap - so the invitation is
/// discoverable from activity, which is the whole point, and acted on where
/// the logic already is.
class _InvitationCard extends StatelessWidget {
  const _InvitationCard({required this.invitation});

  final Map<String, dynamic> invitation;

  @override
  Widget build(BuildContext context) {
    final job = invitation['job'] as Map<String, dynamic>?;
    final employer = invitation['employer'] as Map<String, dynamic>?;
    final jobTitle = (job?['title'] ?? 'Job').toString();
    final employerName = (employer?['name'] ?? 'An employer').toString();

    return _cardShell(
      title: jobTitle,
      subtitle: '$employerName invited you to apply',
      status: 'pending',
      trailing: 'Tap to accept or decline',
      onTap: () => Navigator.pushNamed(context, '/my-invitations'),
    );
  }
}

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

    /*
        The worker's side of the confirmation, which this card never read.

        The worker's own card has always had both halves — it says "waiting for
        the employer" after they confirm, and "the employer marked this done"
        when the employer goes first. This one only ever had the first half, so
        an employer whose worker had already finished saw a bare Mark as
        complete button with nothing explaining that somebody was waiting on
        them. The information was in the payload the whole time and simply was
        not being looked at.
    */
    final theyConfirmed = hire?['worker_completed_at'] != null;
    final workerName = (hire?['worker_name'] ?? 'the worker').toString();

    final workDone = hire?['status'] == 'completed';
    final canConfirm = hire != null && !workDone && !iConfirmed;
    final canReview = hire != null && workDone && hire['i_reviewed_them'] != true;

    final String? note = hire == null
        ? null
        : !workDone
            ? (iConfirmed
                ? 'Marked done · waiting for $workerName to confirm'
                : theyConfirmed
                    ? '$workerName marked this done — confirm to finish it'
                    : null)
            : hire['i_reviewed_them'] == true
                ? 'You reviewed $workerName'
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
                  /*
                      Says the row opens the applicants.

                      The whole card has always been tappable to the applicant
                      list, but nothing showed it, so the only place people
                      found their applicants was the separate manage-jobs
                      screen. A label and a chevron make the tap target look
                      like one.
                  */
                  if (onTap != null) ...[
                    const Spacer(),
                    const Text('View',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                    const Icon(Icons.chevron_right,
                        size: 18, color: AppColors.primary),
                  ],
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

/// The two worker inbox buttons above the activity tabs.
///
/// Applications and Invitations were tabs, sitting next to the employer's
/// "Active Jobs" tab where they read as the same thing. They are the worker's
/// own incoming lists, so they are buttons here, each opening its own sheet,
/// with the count on the face so there is a reason to open it.
class _WorkerInboxButtons extends StatelessWidget {
  const _WorkerInboxButtons({
    required this.applicationCount,
    required this.invitationCount,
    required this.onApplications,
    required this.onInvitations,
  });

  final int applicationCount;
  final int invitationCount;
  final VoidCallback onApplications;
  final VoidCallback onInvitations;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _InboxButton(
              icon: Icons.description_outlined,
              label: 'Applications',
              count: applicationCount,
              onTap: onApplications,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _InboxButton(
              icon: Icons.mail_outline,
              label: 'Invitations',
              count: invitationCount,
              onTap: onInvitations,
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxButton extends StatelessWidget {
  const _InboxButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              // A count badge, and only when there is something to count, so an
              // empty inbox does not wear a "0".
              if (count > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$count',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                )
              else
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.neutral400),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined,
                size: 48, color: AppColors.neutral300),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral600)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.neutral400)),
          ],
        ),
      ),
    );
  }
}
