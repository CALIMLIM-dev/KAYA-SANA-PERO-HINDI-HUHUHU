import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/offline_notice.dart';
import '../../../providers/invitation_provider.dart';
import '../../../providers/worker_browse_provider.dart';
import '../widgets/matched_worker_card.dart';

/*
    Workers who fit one job, best first.

    The server has scored and sorted this since the day it shipped and no
    screen ever called it - a capability with no way in, which is the
    no-inert-UI rule read from the other end.

    **A decision card, not a profile card.** A profile answers "who is this
    person"; a row here answers "should I invite them for *this* job", so it
    is organised around the job. The skills the job asked for and this worker
    has are filled chips; the ones they lack are outline chips. That line is
    the whole feature, and a public profile cannot show it at any size,
    because it does not know which job is being filled.

    No percentage anywhere. The score orders the list and is never printed:
    category is 0 or 40, location is one of five bands, and skills with three
    requirements can only land on four values - so the number repeats across a
    screenful of people and distinguishes nobody. The reasons say the same
    thing in words that can be checked.
*/
class MatchedWorkersScreen extends StatefulWidget {
  const MatchedWorkersScreen({
    super.key,
    required this.jobId,
    this.jobTitle,
  });

  final int jobId;
  final String? jobTitle;

  @override
  State<MatchedWorkersScreen> createState() => _MatchedWorkersScreenState();
}

class _MatchedWorkersScreenState extends State<MatchedWorkersScreen> {
  /// Workers already invited in this session, so the button settles rather
  /// than inviting twice while the list is still on screen.
  final Set<int> _invited = {};
  int? _inviting;

  @override
  void initState() {
    super.initState();

    /*
        After the frame: a provider write during build throws, and this
        screen is pushed from a card that is mid-build when it happens.

        And only when the rows in hand are not already this job's -
        opening the screen twice should not ask the server twice for a
        list that has not changed. Pull-to-refresh is the deliberate
        reload.
    */
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final provider = context.read<WorkerBrowseProvider>();

      if (provider.matchesJobId != widget.jobId) {
        provider.fetchMatches(widget.jobId);
      }
    });
  }

  Future<void> _invite(int workerId, String name) async {
    setState(() => _inviting = workerId);

    final provider = context.read<InvitationProvider>();
    final sent = await provider.sendInvitation(
      jobId: widget.jobId,
      workerId: workerId,
    );

    if (!mounted) return;

    setState(() {
      _inviting = null;
      if (sent) _invited.add(workerId);
    });

    if (sent) {
      AppToast.success(context, '$name has been invited.');
    } else {
      AppToast.error(context, provider.errorMessage ?? 'Could not invite them.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Matched workers'),
      ),
      body: Consumer<WorkerBrowseProvider>(
        builder: (context, provider, _) {
          if (provider.matchesLoading && provider.matches.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.matches.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => provider.fetchMatches(widget.jobId),
              child: ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: provider.matchesError != null
                        ? OfflineNotice(
                            what: 'suggested workers',
                            onRetry: () => provider.fetchMatches(widget.jobId),
                          )
                        : _empty(),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchMatches(widget.jobId),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: provider.matches.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) return _header(provider.matches.length);

                final row = provider.matches[index - 1];
                final workerId = (row['user_id'] as num?)?.toInt();

                return MatchedWorkerCard(
                  row: row,
                  onInvite: _invite,
                  inviting: workerId != null && _inviting == workerId,
                  alreadyInvited:
                      workerId != null && _invited.contains(workerId),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /*
      What the ranking was computed from.

      Without this the order is magic. The panel asked for a list that helps
      an employer decide, and an order nobody can account for does the
      opposite.
  */
  Widget _header(int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count worker${count == 1 ? '' : 's'} for '
            '${widget.jobTitle ?? 'this job'}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Ranked on the trade, the skills you asked for, and how near they are.',
            style: TextStyle(fontSize: 12.5, color: AppColors.neutral600),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_search_outlined,
                size: 44, color: AppColors.neutral400),
            const SizedBox(height: 16),
            const Text(
              'Nobody matches yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Workers appear here as they set up profiles in your area. '
              'Your post is still open and people can apply to it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5, height: 1.4, color: AppColors.neutral600),
            ),
          ],
        ),
      ),
    );
  }
}
