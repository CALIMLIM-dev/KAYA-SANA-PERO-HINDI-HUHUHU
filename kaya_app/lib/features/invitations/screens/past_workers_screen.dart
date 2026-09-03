import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/credits.dart';
import '../../../providers/invitation_provider.dart';
import '../widgets/invite_to_job.dart';

/*
    People this employer has already finished a job with.

    The list is derived on the server from completed applications, because a
    completed application IS the record of having worked together - there is no
    saved shortlist to fall out of step with the real history, and nothing to
    backfill for employers who were hiring before this screen existed.

    The point of the screen is the second hire. Finding somebody good once and
    then having to search for them again is the friction this removes, and the
    reduced price is what makes it the cheapest thing an employer can do.
*/
class PastWorkersScreen extends StatefulWidget {
  const PastWorkersScreen({super.key});

  @override
  State<PastWorkersScreen> createState() => _PastWorkersScreenState();
}

class _PastWorkersScreenState extends State<PastWorkersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<InvitationProvider>().fetchPastWorkers();
    });
  }

  Future<void> _inviteAgain(Map<String, dynamic> worker) async {
    final provider = context.read<InvitationProvider>();

    await showInviteToJobSheet(
      context,
      workerId: (worker['worker_id'] as num).toInt(),
      workerName: (worker['name'] ?? 'this worker').toString(),
      /*
          The reduced price, taken from the same response as the list.

          Not read from the wallet's standard invite cost, which is the full
          one - showing 2 and charging 1 would be a mismatch in the employer's
          favour, and a balance that moves by a different number than the
          screen promised is how people stop trusting it.
      */
      costOverride: provider.rehireCost,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Worked with before',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Consumer<InvitationProvider>(
        builder: (context, provider, _) {
          // Only before the first list arrives. Gating on loading alone would
          // blank the rows out again on every pull-to-refresh.
          if (!provider.hasLoadedPastWorkers) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.pastWorkers.isEmpty) {
            return _empty();
          }

          return RefreshIndicator(
            onRefresh: provider.fetchPastWorkers,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: provider.pastWorkers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) =>
                  _workerRow(provider.pastWorkers[i], provider.rehireCost),
            ),
          );
        },
      ),
    );
  }

  Widget _empty() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 100, 32, 32),
      children: const [
        Icon(Icons.history, size: 48, color: AppColors.neutral400),
        SizedBox(height: 14),
        Text(
          'No finished jobs yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral900,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Workers you complete a job with will appear here, '
          'so you can hire them again for less.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: AppColors.neutral600),
        ),
      ],
    );
  }

  Widget _workerRow(Map<String, dynamic> worker, int? cost) {
    final name = (worker['name'] ?? '').toString();
    final avatar = (worker['avatar'] ?? '').toString();
    final timesHired = (worker['times_hired'] as num?)?.toInt() ?? 0;
    final rating = (worker['rating_avg'] as num?)?.toDouble();
    final ratingCount = (worker['rating_count'] as num?)?.toInt() ?? 0;
    final isVerified = worker['is_verified'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.neutral200,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.neutral700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral900,
                        ),
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified,
                          size: 15, color: AppColors.success),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                /*
                    How many times, not just that it happened.

                    "Hired 3x" is the whole reason to trust this row over a
                    search result, and it is the same count the applicant
                    card already shows.
                */
                Text(
                  [
                    timesHired == 1 ? 'Hired once' : 'Hired ${timesHired}x',
                    if (ratingCount > 0 && rating != null)
                      '${rating.toStringAsFixed(1)} from $ratingCount',
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.neutral600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          /*
              The price is under the button, not on it.

              "Invite · 1 Barya" on the button overflowed by 6px beside a long
              Philippine name at 360dp, because the label grows the one element
              on the row that cannot shrink. Stacked, the button stays a fixed
              narrow width and the number is still read before anything is
              spent - which is the rule that mattered, not where it sits.
          */
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => _inviteAgain(worker),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Invite',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              if (cost != null) ...[
                const SizedBox(height: 3),
                Text(
                  Credits.amount(cost),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.neutral600),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
