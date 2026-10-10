import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/offline_notice.dart';
import '../../../providers/invitation_provider.dart';
import '../../../providers/worker_browse_provider.dart';
import '../widgets/matched_worker_card.dart';

/*
    Workers who fit one job, best first.

    **A decision card, not a profile card.** A profile answers "who is this
    person"; a row here answers "should I invite them for *this* job", so it
    is organised around the job: the skills it asked for and this worker has
    are filled chips, the ones they lack are outline chips.

    No percentage anywhere. The order is the ranking, and the reasons say why
    in words that can be checked.

    **A Top-up benefit.** The panel's requirement: "a hirer who avails of
    i-Kaya Points automatically receives a list of job seekers whose profiles
    match". A hirer who has topped up gets the list; anyone else is told how
    many match and how to see them, never shown an empty screen that reads as
    "nobody fits".

    Shown two ways from one widget: this screen, from My Jobs, and a pop-up
    on the Applicants screen (showMatchedWorkersSheet).
*/
class MatchedWorkersScreen extends StatelessWidget {
  const MatchedWorkersScreen({
    super.key,
    required this.jobId,
    this.jobTitle,
  });

  final int jobId;
  final String? jobTitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Matched workers'),
      ),
      body: MatchedWorkersList(jobId: jobId, jobTitle: jobTitle),
    );
  }
}

/*
    The matched list as a pop-up over the Applicants screen.

    The header stays put while the list scrolls under it: which job this
    is for, how many fit, and what they are ranked on. It opens most of the
    way up and snaps to half or nearly full, so it can be peeked at over the
    applicants or read properly.
*/
Future<void> showMatchedWorkersSheet(
  BuildContext context, {
  required int jobId,
  String? jobTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      snap: true,
      snapSizes: const [0.5, 0.86],
      expand: false,
      builder: (sheetContext, controller) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: ColoredBox(
          color: AppColors.background,
          child: Column(
            children: [
              _SheetHeader(jobTitle: jobTitle, jobId: jobId),
              Expanded(
                child: MatchedWorkersList(
                  jobId: jobId,
                  jobTitle: jobTitle,
                  controller: controller,
                  showHeader: false,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.jobTitle, required this.jobId});

  final String? jobTitle;
  final int jobId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkerBrowseProvider>();
    final ready = provider.matchesJobId == jobId && !provider.matchesLoading;
    final count = provider.matchesLocked ? provider.matchCount : provider.matches.length;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.neutral200)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 8, 14),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.neutral300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Matched workers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral900,
                        ),
                      ),
                      if ((jobTitle ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          jobTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, color: AppColors.neutral600),
                        ),
                      ],
                      const SizedBox(height: 8),
                      // The count arrives with the list; until then the line
                      // keeps its place so nothing below it jumps.
                      AnimatedSwitcher(
                        duration: Motion.quick,
                        child: Text(
                          !ready
                              ? 'Finding who fits...'
                              : '$count ${count == 1 ? 'worker fits' : 'workers fit'}, best first',
                          key: ValueKey(ready ? count : -1),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Ranked on the skills you asked for, rate, days, distance and experience.',
                        style: TextStyle(fontSize: 12, color: AppColors.neutral500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  color: AppColors.neutral600,
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The list itself, with its invite handling and its locked state.
class MatchedWorkersList extends StatefulWidget {
  const MatchedWorkersList({
    super.key,
    required this.jobId,
    this.jobTitle,
    this.controller,
    this.showHeader = true,
  });

  final int jobId;
  final String? jobTitle;

  /// The sheet's scroll controller, so dragging the list drags the sheet.
  final ScrollController? controller;

  /// False in the pop-up, whose own header already says it.
  final bool showHeader;

  @override
  State<MatchedWorkersList> createState() => _MatchedWorkersListState();
}

class _MatchedWorkersListState extends State<MatchedWorkersList> {
  /// Workers already invited in this session, so the button settles rather
  /// than inviting twice while the list is still on screen.
  final Set<int> _invited = {};
  int? _inviting;

  @override
  void initState() {
    super.initState();

    // After the frame: a provider write during build throws. Only when the
    // rows in hand are not this job's - pull-to-refresh is the deliberate
    // reload.
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
    return Consumer<WorkerBrowseProvider>(
      builder: (context, provider, _) {
        final forThisJob = provider.matchesJobId == widget.jobId;

        if (!forThisJob || (provider.matchesLoading && provider.matches.isEmpty && !provider.matchesLocked)) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.matchesLocked) {
          return ListView(
            controller: widget.controller,
            children: [_locked(provider.matchCount)],
          );
        }

        if (provider.matches.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => provider.fetchMatches(widget.jobId),
            child: ListView(
              controller: widget.controller,
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: provider.matchesError != null
                      ? OfflineNotice(
                          what: 'matched workers',
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
            controller: widget.controller,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: provider.matches.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return widget.showHeader ? _header(provider.matches.length) : const SizedBox.shrink();
              }

              final row = provider.matches[index - 1];
              final workerId = (row['user_id'] as num?)?.toInt();

              // Best first, arriving in that order.
              return EntranceIn(
                key: ValueKey(workerId ?? index),
                index: index - 1,
                child: MatchedWorkerCard(
                  row: row,
                  onInvite: _invite,
                  inviting: workerId != null && _inviting == workerId,
                  alreadyInvited: workerId != null && _invited.contains(workerId),
                ),
              );
            },
          ),
        );
      },
    );
  }

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
            'Ranked on the skills you asked for, the trade, how near they are, '
            'and how strong their profile is.',
            style: TextStyle(fontSize: 12.5, color: AppColors.neutral600),
          ),
        ],
      ),
    );
  }

  /// A hirer who has not topped up: how many, and the way to see them.
  Widget _locked(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline, size: 30, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            count == 0
                ? 'Nobody matches this job yet'
                : '$count worker${count == 1 ? '' : 's'} match this job',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Top up any amount of Barya once to see who they are, ranked for '
            'this job. It never expires.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.neutral600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await AppRouter.push(context, AppRouter.wallet);
                if (!mounted) return;
                // Back from the wallet, possibly topped up: ask again.
                context.read<WorkerBrowseProvider>().fetchMatches(widget.jobId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              child: const Text('Top up'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_outlined, size: 44, color: AppColors.neutral400),
            SizedBox(height: 16),
            Text(
              'Nobody matches yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Workers appear here as they set up profiles in your area. '
              'Your post is still open and people can apply to it.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.neutral600),
            ),
          ],
        ),
      ),
    );
  }
}
