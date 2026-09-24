import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/realtime_refresh.dart';

import '../../../core/navigation/app_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/job_summary.dart';
import '../../../providers/job_provider.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/constants/credits.dart';
import '../../invitations/widgets/invite_to_job.dart';
import 'roster_screen.dart';

/// Manage Jobs Screen — employer's posted jobs, on real data from JobProvider.
///
/// This is the screen the home screen's "Active Jobs" card and the bottom-nav
/// entry point to /manage-jobs both land on. It used to render a hardcoded list
/// of five fake jobs regardless of what the employer actually posted — a real
/// job created via Post a Job never appeared here.
///
/// Two tabs: Active (open + in_progress) | History (completed + closed)
class ManageJobsScreen extends StatefulWidget {
  const ManageJobsScreen({super.key});

  @override
  State<ManageJobsScreen> createState() => _ManageJobsScreenState();
}

class _ManageJobsScreenState extends State<ManageJobsScreen>
    with SingleTickerProviderStateMixin, RealtimeRefresh {
  late TabController _tabController;

  /// Keeps the applicant counts on each job card honest while the employer is
  /// looking at them.
  @override
  List<String> get refreshOn => const ['application.', 'invitation.'];

  @override
  void onRealtimeRefresh() => context.read<JobProvider>().fetchMyJobs();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<JobProvider>().fetchMyJobs();
      bindRealtimeRefresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _statusOf(Map<String, dynamic> job) => (job['status'] ?? '').toString();

  List<Map<String, dynamic>> _activeJobs(List<Map<String, dynamic>> jobs) =>
      jobs.where((j) {
        final s = _statusOf(j);
        return s == 'open' || s == 'in_progress';
      }).toList();

  List<Map<String, dynamic>> _historyJobs(List<Map<String, dynamic>> jobs) =>
      jobs.where((j) {
        final s = _statusOf(j);
        return s == 'completed' || s == 'closed';
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Consumer<JobProvider>(
      builder: (context, jobProvider, _) {
        final jobs = jobProvider.jobs;
        final active = _activeJobs(jobs);
        final history = _historyJobs(jobs);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text('My Jobs',
                style: TextStyle(fontWeight: FontWeight.w600)),
            /*
                No "worked with before" screen any more.

                It was a second list of the same people this screen's History
                tab already holds, reached by an icon most employers never
                pressed, and it split one decision across two places: the job
                you remember is in History, the person you want to hire again
                was somewhere else. Reinvite now sits on the finished job's
                own card, which is where somebody thinking "they were good"
                is already looking.
            */
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accent,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: [
                Tab(text: 'Active (${active.length})'),
                Tab(text: 'History (${history.length})'),
              ],
            ),
          ),
          body: jobProvider.isLoading && jobs.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : jobProvider.errorMessage != null && jobs.isEmpty
                  ? _errorState(jobProvider.errorMessage!)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(active, isHistory: false),
                        _buildList(history, isHistory: true),
                      ],
                    ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => AppRouter.push(context, '/post-job'),
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Post a Job',
                style: TextStyle(fontWeight: FontWeight.w600)),
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
            const Text('Could not load your jobs',
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
              onPressed: () => context.read<JobProvider>().fetchMyJobs(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> jobs, {required bool isHistory}) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline, size: 56, color: AppColors.neutral300),
            const SizedBox(height: 16),
            Text(
              isHistory ? 'No past jobs yet' : 'No active jobs',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral600),
            ),
            const SizedBox(height: 8),
            if (!isHistory)
              const Text('Post a job to start hiring workers',
                  style: TextStyle(fontSize: 14, color: AppColors.neutral400)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<JobProvider>().fetchMyJobs(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: jobs.length,
        itemBuilder: (context, i) => _buildCard(jobs[i]),
      ),
    );
  }

  /*
      When the post comes down.

      Said only when it matters: inside the warning window, or once it has
      already lapsed. A date on a post with three weeks left is noise on a card
      that already carries a category, a location, a budget, an applicant count
      and an age.
  */
  /*
      When the post comes down.

      The end date the employer chose, said plainly: "Ends Sep 27", "Ends
      today", or "Ended". There used to be a countdown here against a
      thirty-day timer that ran beside the dates, with an Extend button to
      buy blocks against it. One clock now, and it is theirs.
  */
  Future<void> _openRoster(int jobId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RosterScreen(jobId: jobId)),
    );
    // Completions may have moved while the roster was open.
    if (mounted) context.read<JobProvider>().fetchMyJobs();
  }

  Widget _endLine(Map<String, dynamic> job, String status) {
    if (status != 'open' && status != 'expired') return const SizedBox.shrink();

    final raw = job['expires_at'];
    final at = raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();

    if (at == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(at.year, at.month, at.day);

    final text = status == 'expired' || endDay.isBefore(today)
        ? 'Ended ${_short(endDay)}. Applicants were told and their Barya returned.'
        : endDay == today
            ? 'Ends today'
            : 'Ends ${_short(endDay)}';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 13, color: AppColors.neutral500),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
            ),
          ),
        ],
      ),
    );
  }

  static String _short(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  Widget _buildCard(Map<String, dynamic> job) {
    final status = _statusOf(job);
    final jobId = job['id'] as int;
    final title = (job['title'] ?? '').toString();

    // The single hire on this job, when there is exactly one. Null on a job
    // with two people on it, where a card cannot say which of them you mean —
    // those keep going through the applicant list.
    final hire = job['hire'] as Map<String, dynamic>?;
    final conversationId = hire?['conversation_id'] as int?;

    /*
        Whether this employer still has a confirmation to give.

        The Mark Complete button was rendered unconditionally and only the
        note above it was gated, so after confirming you got "waiting for
        them" and the button together. Tapping again looked like it worked:
        the server is idempotent - JobCompletionService::confirm only writes
        the timestamp when it is null - but it returned the same 200 and the
        same message either way, so the app said "Marked complete" over a
        job it had not changed.

        My Activity's job card has always computed this correctly. Two
        screens, one card, and only one of them fixed - the same drift that
        lost the Message button and the button colours here.
    */
    final canConfirmCompletion = hire != null &&
        hire['status'] != 'completed' &&
        hire['employer_completed_at'] == null;
    final category = (job['category'] as Map<String, dynamic>?)?['name']?.toString();
    final location = (job['city'] ?? job['location'] ?? '').toString();
    final applicants = (job['application_count'] as num?)?.toInt() ?? 0;
    // A job for more than one person is run from its roster, not from the
    // single-hire buttons below, which cannot say which person they mean.
    final workersNeeded = (job['workers_needed'] as num?)?.toInt() ?? 1;
    final workersFilled = (job['workers_filled'] as num?)?.toInt() ??
        (job['hire_count'] as num?)?.toInt() ?? 0;
    final isCrew = workersNeeded > 1 || workersFilled > 1;
    final budget = formatBudget(job);
    final postedAgo = timeAgo(job['created_at'] as String?);

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
      child: InkWell(
        onTap: () => AppRouter.push(context, '/job-details',
            arguments: {'jobId': jobId}),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.neutral900)),
                  ),
                  const SizedBox(width: 8),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (category != null) ...[
                    const Icon(Icons.category_outlined,
                        size: 13, color: AppColors.neutral400),
                    const SizedBox(width: 4),
                    Text(category,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.neutral500)),
                    const SizedBox(width: 12),
                  ],
                  if (location.isNotEmpty) ...[
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: AppColors.neutral400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(location,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.neutral500)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              // Budget on the left, counts on the right. Both give way
              // rather than push past the edge: a salary range beside "9
              // applicants" and "2 days ago" is wider than a small phone
              // at a large text size.
              Row(
                children: [
                  if (budget != null)
                    Flexible(
                      child: Text(budget,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                  const SizedBox(width: 8),
                  const Spacer(),
                  if (status != 'closed') ...[
                    const Icon(Icons.people_outline,
                        size: 14, color: AppColors.neutral400),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                          '$applicants applicant${applicants == 1 ? '' : 's'}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.neutral500)),
                    ),
                  ],
                  if (postedAgo != null) ...[
                    const SizedBox(width: 8),
                    Text(postedAgo,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.neutral400)),
                  ],
                ],
              ),

              _endLine(job, status),

              if (isCrew && status != 'completed') ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.group_outlined, size: 14, color: AppColors.neutral500),
                    const SizedBox(width: 6),
                    Text(
                      '$workersFilled of $workersNeeded hired',
                      style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
                    ),
                  ],
                ),
              ],

              // ── Actions ──
              if (status == 'open') ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => AppRouter.push(context, '/view-applicants',
                            arguments: {'jobId': jobId}),
                        icon: const Icon(Icons.people, size: 16),
                        label: Text('Applicants ($applicants)'),
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
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => _showManageSheet(job),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.neutral600,
                        side: const BorderSide(color: AppColors.neutral300),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Manage', style: TextStyle(fontSize: 13.5)),
                    ),
                  ],
                ),
                // Its own row: three buttons across do not fit a small
                // phone at a large text size.
                if (isCrew && workersFilled > 0) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openRoster(jobId),
                      icon: const Icon(Icons.group_outlined, size: 16),
                      label: Text('Roster ($workersFilled hired)'),
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
                ],
              ] else if (status == 'in_progress' && isCrew) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                // One button for the whole crew. Message and Mark Complete
                // below are for a single hire and cannot say which of
                // several people they mean.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openRoster(jobId),
                    icon: const Icon(Icons.group_outlined, size: 16),
                    label: Text('Roster ($workersFilled)'),
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
              ] else if (status == 'in_progress') ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                /*
                    Completion state, so the button is not a dead end.

                    The employer taps "Mark Complete", the server records their
                    half and correctly leaves the job in progress — and this card
                    then looked exactly as it did before, so it read as though
                    nothing happened and invited another tap. This says who is
                    still to confirm.
                */
                if (hire != null && hire['employer_completed_at'] != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.hourglass_empty,
                          size: 14, color: AppColors.neutral500),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'You marked this done — waiting for '
                          '${hire['worker_name'] ?? 'the worker'} to confirm',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.neutral600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        // Straight to the thread. This pushed '/messages', the
                        // whole inbox — the same fault fixed on the applicant
                        // list, still living here because this screen is a
                        // second copy of that one.
                        onPressed: conversationId == null
                            ? null
                            : () => AppRouter.push(context,
                                  '/chat',
                                  arguments: {
                                    'conversationId': conversationId,
                                    'name': hire?['worker_name'] ?? 'Worker',
                                    'jobTitle': title,
                                    'jobId': jobId,
                                    'otherUserId': hire?['worker_id'],
                                    'applicationId': hire?['application_id'],
                                    'jobStatus': status,
                                    'myRole': 'employer',
                                    'otherRole': 'worker',
                                  },
                                ),
                        icon: const Icon(Icons.message_outlined, size: 16),
                        label: const Text('Message Worker'),
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
                    if (canConfirmCompletion) ...[
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _confirmMarkComplete(jobId, title),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Mark Complete',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ),
                    ],
                  ],
                ),
              ] else if (status == 'completed') ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                /*
                    Straight to the review when one person was hired.

                    This said "View Applicants & Leave a Review" and sent you to
                    the applicant list to find the button — the same burial that
                    was fixed on the My Activity card. With one hire the card
                    knows who you mean, so it just opens the review.
                */
                if (hire != null && hire['i_reviewed_them'] == true)
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 15, color: AppColors.success),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'You reviewed ${hire['worker_name'] ?? 'the worker'}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.neutral600),
                        ),
                      ),
                    ],
                  )
                else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    /*
                        Awaited, and refreshed on a real submit.

                        This pushed and forgot, so coming back from a review
                        left the Review button exactly where it was - the
                        submit had gone through and nothing here asked the
                        server again. It could be pressed a second time, which
                        the server refuses, so the only way out was restarting
                        the app.
                    */
                    onPressed: () async {
                      if (hire == null) {
                        await AppRouter.push(context, '/view-applicants',
                            arguments: {'jobId': jobId});
                        if (mounted) {
                          await context.read<JobProvider>().fetchMyJobs();
                        }
                        return;
                      }

                      final done = await AppRouter.push(context,
                        '/leave-review',
                        arguments: {
                          'revieweeId': hire['worker_id'],
                          'revieweeName':
                              (hire['worker_name'] ?? 'Worker').toString(),
                          'revieweeRole': 'worker',
                          'jobId': jobId,
                          'jobTitle': title,
                        },
                      );

                      if (done == true && mounted) {
                        await context.read<JobProvider>().fetchMyJobs();
                      }
                    },
                    icon: const Icon(Icons.star_outline, size: 18),
                    label: Text(hire == null
                        ? 'View applicants to review'
                        : 'Review ${hire['worker_name'] ?? 'worker'}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                /*
                    Work with them again, from the job that proved it.

                    This is what the "worked with before" screen was for. It
                    sat behind an icon in the app bar and listed the same
                    people whose finished jobs are on this tab, so the person
                    and the job they did were in two different places. The
                    reduced price comes down with the hire rather than being
                    worked out here, so the number read and the number charged
                    are the same one.
                */
                if (hire != null && hire['rehire_cost'] != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => showInviteToJobSheet(
                        context,
                        workerId: (hire['worker_id'] as num).toInt(),
                        workerName:
                            (hire['worker_name'] ?? 'this worker').toString(),
                        costOverride: (hire['rehire_cost'] as num).toInt(),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                      label: Text(
                        'Reinvite ${hire['worker_name'] ?? 'worker'}'
                        ' · ${Credits.amount((hire['rehire_cost'] as num).toInt())}',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// "₱1,500 - ₱2,500/day" or "₱1,500/day" when there is no max, or null when
  /// nothing was set. Fields come back from the API as numeric strings.
  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'open':
        color = AppColors.success;
        label = 'Open';
        break;
      case 'in_progress':
        color = AppColors.warning;
        label = 'In Progress';
        break;
      case 'completed':
        color = AppColors.primary;
        label = 'Completed';
        break;
      case 'expired':
        // Its own badge, not "Closed": closed is a decision the
        // employer made, this one is the end date arriving.
        color = AppColors.neutral500;
        label = 'Ended';
        break;
      default:
        color = AppColors.neutral400;
        label = 'Closed';
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

  void _showManageSheet(Map<String, dynamic> job) {
    final jobId = job['id'] as int;
    final category = job['category'] as Map<String, dynamic>?;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((job['title'] ?? '').toString(),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral900)),
            const SizedBox(height: 4),
            const Text('Choose an action',
                style: TextStyle(fontSize: 13.5, color: AppColors.neutral600)),
            const SizedBox(height: 20),
            _actionTile(Icons.edit_outlined, 'Edit Job', AppColors.primary, () {
              Navigator.pop(context);
              /*
                  Everything the edit form can change has to arrive here.

                  Only half of it used to. The form opened with its own
                  defaults for the rest — not urgent, Daily, no maximum — so an
                  urgent job displayed as ordinary, and saving would have
                  written those defaults back over the real values.
              */
              AppRouter.push(context, '/edit-job', arguments: {
                'id': jobId,
                'title': job['title'],
                'category': category?['name'],
                'category_id': category?['id'],
                'description': job['description'],
                'budget_min': job['budget_min'],
                'budget_max': job['budget_max'],
                'budget_period': job['budget_period'],
                'is_urgent': job['is_urgent'],
                // Same reason as the fields above: the edit form sends these
                // back, so omitting them here would hand it nulls and wipe the
                // job's schedule on the first save.
                'start_date': job['start_date'],
                'end_date': job['end_date'],
                'skill_ids': (job['skills'] as List?)
                    ?.map((s) => (s as Map)['id'])
                    .whereType<int>()
                    .toList(),
                'location': job['city'] ?? job['location'],
                'location_id': job['location_id'],
              });
            }),
            _actionTile(Icons.close, 'Close Job', AppColors.error, () {
              Navigator.pop(context);
              _confirmClose(jobId, (job['title'] ?? '').toString());
            }),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: color)),
      onTap: onTap,
    );
  }

  void _confirmMarkComplete(int jobId, String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark as Completed?'),
        // Says what actually happens. Completion is two-sided now: this records
        // the employer's half and the worker still has to confirm.
        content: Text(
          'The worker has to confirm as well.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not yet')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider = context.read<JobProvider>();
              final ok = await provider.changeStatus(jobId, 'completed');

              /*
                  Refetched, or the button stays.

                  changeStatus records the employer's half and leaves the job
                  in progress, which is correct - but the card decides whether
                  to draw Mark Complete from hire['employer_completed_at'],
                  and nothing here asked the server for the new value. So the
                  toast said "waiting for the worker to confirm" while the
                  button that had just been pressed sat underneath it,
                  unchanged, until the app was restarted.

                  My Activity's copy of this card refreshes; this one never
                  did. Same two-screens-one-card drift that lost the Message
                  button and the button colours here.
              */
              if (ok) await provider.fetchMyJobs();

              if (!mounted) return;

              /*
                  The server's own wording, not a fixed string.

                  This said "Job marked as completed" whenever the call
                  succeeded. Since completion became two-sided that call
                  succeeds while leaving the job in progress — so the employer
                  was told the job was finished, then found no review button and
                  a job still listed as active. The screen was reporting an
                  outcome it had not checked.
              */
              AppToast.info(
                context,
                ok
                    ? (provider.lastStatusMessage ??
                        'Marked complete. Waiting for the worker to confirm.')
                    : provider.errorMessage ?? 'Failed to update job',
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Mark Complete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmClose(int jobId, String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Close Job?'),
        content: Text('Close "$title"? Workers can no longer apply.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok =
                  await context.read<JobProvider>().changeStatus(jobId, 'closed');
              if (!mounted) return;
              AppToast.info(context, ok
                    ? 'Job closed'
                    : context.read<JobProvider>().errorMessage ??
                        'Failed to close job');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child:
                const Text('Close Job', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
