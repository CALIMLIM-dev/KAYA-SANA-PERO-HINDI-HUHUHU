import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/job_model.dart';
import '../../../data/models/worker_profile_model.dart';
import 'compact_job_card.dart';
import 'compact_worker_card.dart';

/*
    The second row on the home screen, one per side.

    The ranking and the boosts went in and nothing on the home screen used
    either: an employer saw one list of workers ordered by a score they were
    never shown, and a worker had no idea a boosted post was a boosted post.
    This is the row that says so - proven workers for whoever is hiring,
    promoted jobs for whoever is looking.

    Which row appears follows the side the account is acting as, the same rule
    the rest of the home follows. It renders nothing at all when there is
    nothing to put in it, rather than a heading over an empty strip.
*/
class RecommendationRow extends StatelessWidget {
  const RecommendationRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.workers = const [],
    this.jobs = const [],
    this.onWorkerTap,
    this.onWorkerInvite,
    this.onJobTap,
  });

  final String title;
  final String subtitle;

  final List<WorkerProfile> workers;
  final List<Job> jobs;

  final void Function(WorkerProfile)? onWorkerTap;
  final void Function(WorkerProfile)? onWorkerInvite;
  final void Function(Job)? onJobTap;

  bool get _isEmpty => workers.isEmpty && jobs.isEmpty;

  @override
  Widget build(BuildContext context) {
    if (_isEmpty) return const SizedBox.shrink();

    // Scales with the text, or the cards clip their own last line on a phone
    // set to large type - the same rule the other two carousels follow.
    final rowHeight = 190 * MediaQuery.textScalerOf(context).scale(1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.neutral900,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.neutral600),
          ),
        ),
        SizedBox(
          height: rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: workers.isNotEmpty ? workers.length : jobs.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              if (workers.isNotEmpty) {
                final worker = workers[i];

                return SizedBox(
                  width: 260,
                  child: CompactWorkerCard(
                    worker: worker,
                    onTap: () => onWorkerTap?.call(worker),
                    onInvite: onWorkerInvite == null
                        ? null
                        : () => onWorkerInvite!(worker),
                  ),
                );
              }

              final job = jobs[i];

              return SizedBox(
                width: 260,
                child: CompactJobCard(
                  job: job,
                  onTap: () => onJobTap?.call(job),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
