import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/realtime_refresh.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/worker_browse_provider.dart';
import '../../employer/screens/matched_workers_screen.dart';
import '../widgets/applicant_card.dart';

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

  /*
      Jobs whose matched workers have already popped up this session.

      The panel asked that a hirer who avails of points "automatically
      receives" the list, so it opens by itself the first time a job's
      applicants are viewed - once, not every visit. The banner above the
      tabs opens it again whenever it is wanted.
  */
  static final Set<int> _matchesShown = {};

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
        bindRealtimeRefresh();
        // The job (status, title) and its matched workers together.
        _loadJobAndMatches(_jobId!);
      });
    }
  }

  Future<void> _loadJobAndMatches(int jobId) async {
    final jobs = context.read<JobProvider>();
    final browse = context.read<WorkerBrowseProvider>();

    await Future.wait([jobs.fetchJobDetail(jobId), browse.fetchMatches(jobId)]);
    if (!mounted) return;

    // Only while the job is still looking for people, and only once.
    final open = jobs.selectedJob?.status == 'open';
    if (open && browse.matchCount > 0 && _matchesShown.add(jobId)) {
      showMatchedWorkersSheet(context, jobId: jobId, jobTitle: jobs.selectedJob?.title);
    }
  }

  /// "8 workers match this job", above the tabs, while the job is open.
  Widget _matchesBanner() {
    final browse = context.watch<WorkerBrowseProvider>();
    final open = context.watch<JobProvider>().selectedJob?.status == 'open';

    if (!open || browse.matchesJobId != _jobId || browse.matchCount == 0) {
      return const SizedBox.shrink();
    }

    final count = browse.matchCount;
    final locked = browse.matchesLocked;

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => showMatchedWorkersSheet(context, jobId: _jobId!, jobTitle: _jobTitle),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.neutral200)),
          ),
          child: Row(
            children: [
              Icon(locked ? Icons.lock_outline : Icons.person_search_outlined,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  locked
                      ? '$count worker${count == 1 ? '' : 's'} match this job. Top up to see them.'
                      : '$count worker${count == 1 ? '' : 's'} match this job',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900,
                  ),
                ),
              ),
              const Text(
                'See',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
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

        /*
            Message and Mark complete belong on the job, not on each row.

            The job card in My Jobs already carries both for a hire, so
            every accepted applicant here repeated the two buttons the
            employer had just used one screen back — two places to finish
            the same job, and no way to tell which one was the real one.

            They stay for the one case the card genuinely cannot express:
            more than one person hired on a single job. The server sends
            `hire` as null then, precisely because the card cannot say who
            you mean, so this list is the only place those actions exist.
        */
        final hiredCount = all
            .where((a) => const {'accepted', 'completed'}
                .contains((a['application_status'] ?? '').toString()))
            .length;
        final perWorkerActions = hiredCount > 1;

        // Spots on the job, and whether any are left. Counted from the
        // list rather than the job so it is right the moment one is taken.
        final spots = context.watch<JobProvider>().selectedJob?.workersNeeded ?? 1;
        final full = hiredCount >= spots;

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
                  : Column(
                      children: [
                        _matchesBanner(),
                        Expanded(
                          child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(pending,
                            showActions: true,
                            perWorkerActions: perWorkerActions,
                            spots: spots,
                            hired: hiredCount,
                            full: full),
                        _buildList(accepted,
                            showActions: false,
                            perWorkerActions: perWorkerActions),
                        _buildList(rejected,
                            showActions: false,
                            perWorkerActions: perWorkerActions),
                      ],
                    ),
                        ),
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
      {required bool showActions,
      required bool perWorkerActions,
      int spots = 1,
      int hired = 0,
      bool full = false}) {
    if (applicants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 56, color: AppColors.neutral300),
            const SizedBox(height: 16),
            const Text('No applicants yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral600)),
            const SizedBox(height: 8),
            /*
                Says why it is empty.

                A notification about an applicant stays in the list after the
                applicant is gone — withdrawn, or already accepted or
                declined — so tapping an old one lands here. "No applicants
                here" over a job the employer knows had applicants reads as
                the screen having failed to load them.
            */
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Anyone who applied has either been answered already or '
                'withdrawn their application.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.neutral400),
              ),
            ),
          ],
        ),
      );
    }

    // A job for several people says how many are still open above the
    // pending list, and Accept stops once they are all taken.
    final spotsLine = showActions && spots > 1
        ? Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(full ? Icons.group : Icons.group_outlined,
                    size: 16, color: full ? AppColors.success : AppColors.neutral600),
                const SizedBox(width: 6),
                Text(
                  full
                      ? 'All $spots spots filled.'
                      : '$hired of $spots hired. ${spots - hired} more to accept.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: full ? AppColors.success : AppColors.neutral700,
                  ),
                ),
              ],
            ),
          )
        : null;

    /*
        The pending list is a ranking - the server sorts it by fit - so it
        says so, and each card carries its place.
    */
    final header = showActions
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ?spotsLine,
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.leaderboard_outlined, size: 17, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ranked by best fit for this job: the trade, the skills it needs, and how close they are.',
                        style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.neutral700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        : null;

    return RefreshIndicator(
      onRefresh: () =>
          context.read<ApplicationProvider>().fetchApplicants(_jobId!),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: applicants.length + (header == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (header != null && index == 0) return header;
          final position = index - (header == null ? 0 : 1);
          return ApplicantCard(
            applicant: applicants[position],
            rank: showActions ? position + 1 : null,
            showActions: showActions,
            perWorkerActions: perWorkerActions,
            full: full,
            jobId: _jobId,
            jobTitle: _jobTitle,
            jobStatus: _jobStatus,
            job: context.watch<JobProvider>().selectedJob,
            onChanged: () =>
                context.read<ApplicationProvider>().fetchApplicants(_jobId!),
          );
        },
      ),
    );
  }
}
