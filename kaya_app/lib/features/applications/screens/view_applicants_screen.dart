import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/realtime_refresh.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/kaya_popup.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/worker_browse_provider.dart';
import '../../employer/screens/matched_workers_screen.dart';
import '../../employer/widgets/matched_worker_card.dart';
import '../widgets/applicant_card.dart';

/// View Applicants Screen — employer sees everyone who actually applied to a
/// job, via GET /jobs/{job}/applicants.
///
/// This used to render five hardcoded applicants (Juan Dela Cruz, Pedro
/// Santos, Mario Reyes...) on every job regardless of who applied, and Accept/
/// Reject only flipped local state — nothing was sent to the server.
/// The applicants of one job, over the screen they were asked for from
/// rather than as a screen of their own. The route stays for links from
/// notifications.
Future<void> showApplicantsPopup(BuildContext context, int jobId) {
  return showKayaPopup<void>(
    context,
    tall: true,
    arguments: {'jobId': jobId},
    builder: (_) => const ViewApplicantsScreen(),
  );
}

/*
    One list for one job: who applied, ranked by fit; who is hired; then
    the other workers who fit and have not applied; and, folded away, who
    was declined.

    It was three tabs, a banner above them, and a second pop-up of matches
    that opened itself on top - four ways into what is one question: who
    could do this job. The matches are the panel's "list of job seekers
    whose profiles match" for a hirer who has topped up; a hirer who has
    not sees how many, and the way to see who.
*/
class ViewApplicantsScreen extends StatefulWidget {
  const ViewApplicantsScreen({super.key});

  @override
  State<ViewApplicantsScreen> createState() => _ViewApplicantsScreenState();
}

class _ViewApplicantsScreenState extends State<ViewApplicantsScreen>
    with RealtimeRefresh {
  int? _jobId;
  bool _initialized = false;
  bool _showDeclined = false;

  /// Matched workers invited from this list, and the one being invited now.
  final Set<int> _invited = {};
  int? _inviting;

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
        context.read<JobProvider>().fetchJobDetail(_jobId!);
        context.read<WorkerBrowseProvider>().fetchMatches(_jobId!);
      });
    }
  }

  Future<void> _refresh() => Future.wait([
        context.read<ApplicationProvider>().fetchApplicants(_jobId!),
        context.read<WorkerBrowseProvider>().fetchMatches(_jobId!),
      ]);

  Future<void> _invite(int workerId, String name) async {
    setState(() => _inviting = workerId);
    final sent = await inviteMatchedWorker(context, jobId: _jobId!, workerId: workerId, name: name);
    if (!mounted) return;
    setState(() {
      _inviting = null;
      if (sent) _invited.add(workerId);
    });
  }

  bool _isStatus(Map<String, dynamic> a, Set<String> statuses) =>
      statuses.contains((a['application_status'] ?? '').toString());

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
        final pending = all.where((a) => _isStatus(a, const {'pending'})).toList();
        // Hired, finished or not: a finished hire on a crew job has to stay
        // reachable, or it could not be reviewed.
        final hired = all.where((a) => _isStatus(a, const {'accepted', 'completed'})).toList();
        final declined = all.where((a) => _isStatus(a, const {'rejected'})).toList();

        /*
            Message and Mark complete belong on the job, not on each row.

            The job card already carries both for a single hire. They stay
            here for the one case the card cannot express: more than one
            person hired on one job.
        */
        final perWorkerActions = hired.length > 1;

        // Spots on the job, and whether any are left. Counted from the
        // list rather than the job so it is right the moment one is taken.
        final spots = context.watch<JobProvider>().selectedJob?.workersNeeded ?? 1;
        final full = hired.length >= spots;
        final job = context.watch<JobProvider>().selectedJob;

        Widget card(Map<String, dynamic> a, {int? rank, bool actions = false}) => ApplicantCard(
              applicant: a,
              rank: rank,
              showActions: actions,
              perWorkerActions: perWorkerActions,
              full: full,
              jobId: _jobId,
              jobTitle: _jobTitle,
              jobStatus: _jobStatus,
              job: job,
              onChanged: () => context.read<ApplicationProvider>().fetchApplicants(_jobId!),
            );

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(_jobTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          body: provider.isApplicantsLoading && all.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : provider.applicantsErrorMessage != null && all.isEmpty
                  ? _errorState(provider.applicantsErrorMessage!)
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          if (spots > 1) _spots(spots, hired.length, full),
                          _title('Applicants', pending.length, note: pending.length > 1 ? 'Best match first' : null),
                          if (pending.isEmpty)
                            _quiet(all.isEmpty
                                ? 'Nobody has applied yet.'
                                : 'No applicants waiting.')
                          else
                            for (final (i, a) in pending.indexed) card(a, rank: i + 1, actions: true),
                          if (hired.isNotEmpty) ...[
                            _title('Hired', hired.length),
                            for (final a in hired) card(a),
                          ],
                          if (job?.status == 'open') _matches(all),
                          if (declined.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: () => setState(() => _showDeclined = !_showDeclined),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.neutral600,
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerLeft,
                              ),
                              child: Text('${_showDeclined ? 'Hide' : 'Show'} Rejected (${declined.length})'),
                            ),
                            if (_showDeclined)
                              for (final a in declined) card(a),
                          ],
                        ],
                      ),
                    ),
        );
      },
    );
  }

  /// Workers who fit and have not applied. Names for a hirer who has topped
  /// up; for one who has not, how many and the way to see who.
  Widget _matches(List<Map<String, dynamic>> applicants) {
    final browse = context.watch<WorkerBrowseProvider>();
    if (browse.matchesJobId != _jobId) return const SizedBox.shrink();

    if (browse.matchesLocked) {
      final count = browse.matchCount;
      if (count == 0) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Suggested Workers', count),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count ${count == 1 ? 'worker matches' : 'workers match'} this job. Top up any amount to see and invite them.',
                  style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.neutral800),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    await AppRouter.push(context, AppRouter.wallet);
                    if (!mounted) return;
                    context.read<WorkerBrowseProvider>().fetchMatches(_jobId!);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text('Top Up to View'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Somebody who already applied is above, not here again.
    final applied = applicants.map((a) => (a['worker_id'] as num?)?.toInt()).toSet();
    final rows = browse.matches
        .where((m) => !applied.contains((m['user_id'] as num?)?.toInt()))
        .toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Suggested Workers', rows.length),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MatchedWorkerCard(
              row: row,
              onInvite: _invite,
              inviting: _inviting != null && _inviting == (row['user_id'] as num?)?.toInt(),
              alreadyInvited: _invited.contains((row['user_id'] as num?)?.toInt()),
            ),
          ),
      ],
    );
  }

  Widget _title(String text, int count, {String? note}) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
        child: Row(
          children: [
            Text('$text ($count)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.neutral900)),
            if (note != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.neutral500)),
              ),
            ],
          ],
        ),
      );

  Widget _quiet(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
        child: Text(text, style: const TextStyle(fontSize: 13.5, color: AppColors.neutral600)),
      );

  // A job for several people says how many are still open, and Accept stops
  // once they are all taken.
  Widget _spots(int spots, int hired, bool full) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(full ? Icons.group : Icons.group_outlined,
                size: 16, color: full ? AppColors.success : AppColors.neutral600),
            const SizedBox(width: 6),
            Text(
              full ? 'All $spots spots filled.' : '$hired of $spots hired. ${spots - hired} more to accept.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: full ? AppColors.success : AppColors.neutral700,
              ),
            ),
          ],
        ),
      );

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: AppColors.neutral300),
            const SizedBox(height: 16),
            const Text('Could Not Load Applicants',
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
}
