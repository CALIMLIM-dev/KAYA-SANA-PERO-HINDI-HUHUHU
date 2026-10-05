import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/offline_notice.dart';
import '../../../providers/invitation_provider.dart';
import '../../../providers/worker_browse_provider.dart';

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
        title: const Text('Suggested workers'),
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

                return _card(provider.matches[index - 1]);
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

  Widget _card(Map<String, dynamic> row) {
    final workerId = (row['user_id'] as num?)?.toInt();
    final name = '${row['name'] ?? 'Worker'}';
    final verified = row['is_verified'] == true;

    final skills = ((row['skills'] as List?) ?? const [])
        .map((s) => s.toString())
        .toList();
    final matchedSkills = ((row['matched_skills'] as List?) ?? const [])
        .map((s) => s.toString().toLowerCase())
        .toSet();
    final reasons = ((row['match_reasons'] as List?) ?? const [])
        .map((s) => s.toString())
        .toList();

    final licenses = ((row['licenses'] as List?) ?? const [])
        .map((s) => s.toString())
        .toList();
    final certs = ((row['certifications'] as List?) ?? const [])
        .map((s) => s.toString())
        .toList();

    final hiredBefore = (row['times_hired_before'] as num?)?.toInt() ?? 0;
    final jobsDone = (row['jobs_completed'] as num?)?.toInt() ?? 0;
    final experience = row['experience_label'] as String?;

    final busy = _inviting == workerId;
    final invited = workerId != null && _invited.contains(workerId);

    // The same shell as job_list_card: radius 12, no elevation, one soft
    // shadow. A second card language on one app is the inconsistency to
    // avoid.
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Who ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.neutral200,
                backgroundImage: (row['avatar'] as String?)?.isNotEmpty == true
                    ? NetworkImage(row['avatar'] as String)
                    : null,
                child: (row['avatar'] as String?)?.isNotEmpty == true
                    ? null
                    : const Icon(Icons.person,
                        size: 22, color: AppColors.neutral500),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.neutral900,
                            ),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 5),
                          const Icon(Icons.verified,
                              size: 15, color: AppColors.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if ((row['category'] as String?)?.isNotEmpty == true)
                          row['category'] as String,
                        if (distanceText(row['distance_label'] as String?,
                                (row['distance_km'] as num?)?.toDouble()) !=
                            null)
                          distanceText(row['distance_label'] as String?,
                              (row['distance_km'] as num?)?.toDouble())!,
                      ].join('  ·  '),
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.neutral600),
                    ),
                    if ((row['rating_count'] as num?) != null &&
                        (row['rating_count'] as num) > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 13, color: AppColors.warning),
                          const SizedBox(width: 3),
                          Text(
                            '${double.tryParse('${row['rating_avg']}')?.toStringAsFixed(1) ?? '-'}'
                            '  (${row['rating_count']})',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.neutral600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          /*
              The skills, against this job.

              Filled is held, outline is asked for and missing. This is the
              line the screen exists for - it is the only place in the app a
              worker is described relative to a particular job.
          */
          if (skills.isNotEmpty || matchedSkills.isNotEmpty) ...[
            const SizedBox(height: 11),
            _skillChips(skills, matchedSkills),
          ],

          // ── Why it is here ──
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              reasons.join('  ·  '),
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.neutral600,
              ),
            ),
          ],

          // ── Evidence: the licence leads ──
          if (licenses.isNotEmpty ||
              certs.isNotEmpty ||
              experience != null ||
              jobsDone > 0 ||
              hiredBefore > 0) ...[
            const SizedBox(height: 9),
            _evidence(licenses, certs, experience, jobsDone, hiredBefore),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: workerId == null || busy || invited
                      ? null
                      : () => _invite(workerId, name),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(invited ? 'Invited' : 'Invite'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: workerId == null
                    ? null
                    : () => AppRouter.push(context, '/worker-profile',
                        arguments: {'workerId': workerId}),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.neutral700,
                  textStyle: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                child: const Text('Profile'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Held skills filled, asked-for-and-missing outlined.
  Widget _skillChips(List<String> held, Set<String> matched) {
    // Everything the job wanted and they do not have. matched_skills is what
    // the job asked for *and* they hold, so anything in it that is not in
    // their own list is a name the matcher connected rather than a literal
    // one - still theirs, so it is shown as held.
    final heldLower = held.map((s) => s.toLowerCase()).toSet();
    final inferred = matched.where((m) => !heldLower.contains(m)).toList();

    /*
        LayoutBuilder, because Wrap gives each child unbounded width.

        A real skill name runs to forty characters, which is wider than
        the card on a 320px phone - so without a ceiling the chip's own
        Row overflows rather than the Wrap moving it to the next line.
    */
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxChip = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : double.infinity;

        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final skill in held)
              _chip(
                skill,
                filled: matched.contains(skill.toLowerCase()),
                maxWidth: maxChip,
              ),
            for (final skill in inferred)
              _chip(skill, filled: true, maxWidth: maxChip),
          ],
        );
      },
    );
  }

  Widget _chip(String label, {required bool filled, double? maxWidth}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: filled
            ? AppColors.primary.withValues(alpha: 0.09)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: filled
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.neutral300,
        ),
      ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (filled) ...[
              const Icon(Icons.check, size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
            ],
            // Flexible, so a long trade name truncates instead of
            // pushing the tick off the chip.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
                  color: filled ? AppColors.primary : AppColors.neutral600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /*
      The licence first, ahead of the counts.

      For a trade it is the strongest single signal an employer has - a
      licensed electrician is a different proposition from somebody who listed
      electrical work - and it is the only line on this card that was checked
      by anybody other than the worker.

      Names only. The scan stays behind the rule that releases it to the owner
      and an employer with a live application.
  */
  Widget _evidence(
    List<String> licenses,
    List<String> certs,
    String? experience,
    int jobsDone,
    int hiredBefore,
  ) {
    final credentials = [...licenses, ...certs];

    final facts = <String>[
      ?experience,
      if (jobsDone > 0) '$jobsDone job${jobsDone == 1 ? '' : 's'} done',
      if (hiredBefore > 0)
        hiredBefore == 1 ? 'Hired before' : 'Hired ${hiredBefore}x before',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (credentials.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.workspace_premium_outlined,
                  size: 14, color: AppColors.neutral500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  credentials.join(', '),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral700,
                  ),
                ),
              ),
            ],
          ),
        if (credentials.isNotEmpty && facts.isNotEmpty)
          const SizedBox(height: 4),
        if (facts.isNotEmpty)
          Row(
            children: [
              const Icon(Icons.history, size: 14, color: AppColors.neutral500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  facts.join('  ·  '),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.neutral600),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
