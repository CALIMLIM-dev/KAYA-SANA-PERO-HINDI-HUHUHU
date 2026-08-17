import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'compact_job_card.dart';
import '../../../data/models/job_model.dart';

/// Jobs Near You Section - Horizontal scroll of job opportunities
class JobsNearYouSection extends StatelessWidget {
  final List<Job> jobs;
  final bool isLoading;
  final String? userLocation;
  final VoidCallback? onSeeAll;
  final Function(Job)? onJobTap;
  final Function(Job)? onJobContact;
  final List<String> workerSkills;

  const JobsNearYouSection({
    super.key,
    required this.jobs,
    this.isLoading = false,
    this.userLocation,
    this.onSeeAll,
    this.onJobTap,
    this.onJobContact,
    this.workerSkills = const [],
  });

  /// What this list actually is, rather than what we wish it were.
  ///
  /// This used to read "Open jobs in {your city}" over a list that was never
  /// filtered to that city — the server sorts nearest-first but returns
  /// everything, so someone in Urdaneta was told "Open jobs in Urdaneta City"
  /// above jobs in three other provinces. Reported as a bug, and it was one:
  /// the heading was making a promise the data underneath never kept.
  ///
  /// Sorting rather than cutting off is the right call — a worker in a quiet
  /// town would otherwise open the app to an empty screen — so the heading is
  /// what has to change.
  String _subtitle() {
    final hasDistances = jobs.any((j) => j.distance != null);

    if (!hasDistances) {
      // No coordinates on the viewer means the order is arbitrary. Say so, and
      // say what would fix it.
      return 'All open jobs · add your location to sort by distance';
    }

    return userLocation != null
        ? 'Nearest to $userLocation first'
        : 'Nearest to you first';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Jobs',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.neutral900,
                    ),
                  ),
                  Text(
                    _subtitle(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.neutral600,
                    ),
                  ),
                ],
              ),
              if (jobs.isNotEmpty || !isLoading)
                TextButton(
                  onPressed: onSeeAll,
                  child: Text(
                    'See All',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Jobs Horizontal List
        SizedBox(
          /*
              168, and this is the second time it has been raised.

              It went 140 → 150 to "fix overflow", which bought 10px of slack
              and left the card one line away from breaking again — which is
              what the reported overflow on this widget was. Adding the schedule
              row then overflowed it by exactly 3px, caught by the render test
              rather than by a tester.

              168 fits the current content with room for one more line. If
              another row is ever added here, raise this in the same commit and
              re-run `flutter test test/screens_render_test.dart` — the card is
              a fixed height on purpose, because a horizontal carousel of
              different-height cards looks broken, so the height and the content
              have to be changed together.
          */
          height: 168,
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              // Prevent parent scroll view from handling horizontal scroll
              return true;
            },
            child: _buildJobsList(),
          ),
        ),
      ],
    );
  }

  Widget _buildJobsList() {
    if (isLoading) {
      return _buildLoadingState();
    }
    
    if (jobs.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        return Container(
          width: 280,
          margin: EdgeInsets.only(right: index < jobs.length - 1 ? 12 : 0),
          child: CompactJobCard(
            job: job,
            onTap: () => onJobTap?.call(job),
            onContact: () => onJobContact?.call(job),
            workerSkills: workerSkills,
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          width: 280,
          margin: EdgeInsets.only(right: index < 2 ? 12 : 0),
          child: _SkeletonJobCard(),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.work_outline,
              size: 32,
              color: AppColors.neutral400,
            ),
            const SizedBox(height: 8),
            Text(
              'No jobs nearby',
              style: TextStyle(
                color: AppColors.neutral600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try expanding your search radius',
              style: TextStyle(
                color: AppColors.neutral500,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                // TODO: Expand search radius or adjust location
              },
              child: Text(
                'Adjust Location',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonJobCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          // Status indicator skeleton
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.neutral200,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.neutral200,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const Spacer(),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.neutral200,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Title skeleton
          Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.neutral200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          
          // Company skeleton
          Container(
            width: 120,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.neutral200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Spacer(),
          
          // Bottom row skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 80,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.neutral200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: 60,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.neutral200,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}