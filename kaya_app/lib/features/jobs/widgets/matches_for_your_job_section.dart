import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../providers/invitation_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/worker_browse_provider.dart';
import '../../employer/widgets/matched_worker_card.dart';

/*
    Workers who fit your job, on the home screen.

    The scoring has existed since the matches endpoint shipped and the only
    way in was Manage Jobs, a job card, then a button - which is three taps
    past the screen an employer actually opens. The panel asked for the list;
    the user asked for it here.

    The newest running job, because that is the one being staffed. An
    employer with five open posts does not want their home screen to become
    Manage Jobs, so this is the top two and a way through to the rest.
*/
class MatchesForYourJobSection extends StatefulWidget {
  const MatchesForYourJobSection({super.key, this.maxRows = 2});

  final int maxRows;

  @override
  State<MatchesForYourJobSection> createState() =>
      _MatchesForYourJobSectionState();
}

class _MatchesForYourJobSectionState extends State<MatchesForYourJobSection> {
  final Set<int> _invited = {};
  int? _inviting;

  /// The job this section last asked about, so it does not refetch per build.
  int? _asked;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final job = _newestRunningJob(context.read<JobProvider>());
    final jobId = job == null ? null : (job['id'] as num?)?.toInt();

    if (jobId == null || jobId == _asked) return;

    _asked = jobId;

    /*
        After the frame: a provider write during build throws, and this is
        built inside the home screen's own build. Only when the shortlist is
        not already this job's - see fetchMatches.
    */
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final directory = context.read<WorkerBrowseProvider>();
      if (directory.matchesJobId != jobId) {
        directory.fetchMatches(jobId);
      }
    });
  }

  /// The most recent job still taking applicants.
  Map<String, dynamic>? _newestRunningJob(JobProvider jobs) {
    for (final job in jobs.jobs) {
      if (JobProvider.jobIsActive(job)) return job;
    }
    return null;
  }

  Future<void> _invite(int workerId, String name) async {
    setState(() => _inviting = workerId);

    final jobId = _asked;
    final invitations = context.read<InvitationProvider>();

    final sent = jobId == null
        ? false
        : await invitations.sendInvitation(jobId: jobId, workerId: workerId);

    if (!mounted) return;

    setState(() {
      _inviting = null;
      if (sent) _invited.add(workerId);
    });

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(
      content: Text(sent
          ? '$name has been invited.'
          : invitations.errorMessage ?? 'Could not invite them.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final jobs = context.watch<JobProvider>();
    final directory = context.watch<WorkerBrowseProvider>();

    final job = _newestRunningJob(jobs);
    if (job == null) return const SizedBox.shrink();

    final jobId = (job['id'] as num?)?.toInt();
    final title = (job['title'] ?? 'your job').toString();

    // Only this job's rows. Another job's shortlist under this job's title
    // would be worse than showing nothing.
    if (jobId == null || directory.matchesJobId != jobId) {
      return const SizedBox.shrink();
    }

    final rows = directory.matches;
    if (rows.isEmpty) return const SizedBox.shrink();

    final shown = rows.take(widget.maxRows).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Workers for your job',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900,
                  ),
                ),
              ),
              if (rows.length > shown.length)
                TextButton(
                  onPressed: () => AppRouter.push(
                    context,
                    AppRouter.matchedWorkers,
                    arguments: {'jobId': jobId, 'jobTitle': title},
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: Text('See all ${rows.length}'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            // Which job these are for. Without it an employer running two
            // posts cannot tell whose shortlist this is.
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: AppColors.neutral600),
          ),
        ),
        for (final row in shown)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: MatchedWorkerCard(
              row: row,
              onInvite: _invite,
              inviting: _inviting == (row['user_id'] as num?)?.toInt(),
              alreadyInvited:
                  _invited.contains((row['user_id'] as num?)?.toInt()),
            ),
          ),
      ],
    );
  }
}
