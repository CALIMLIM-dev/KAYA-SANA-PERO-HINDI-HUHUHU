import 'dart:math' as math;

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
              /*
                  Expanded, so the heading gives way instead of the button.

                  A Row hands an unconstrained child every pixel it asks for,
                  and a title plus a subtitle asks for as much as the longest
                  line needs. On a narrow phone, or at a larger font, that is
                  more than the row has, so the whole thing was pushed wide and
                  "See All" — the only way into the full list — was carried off
                  the right edge behind a striped overflow bar.

                  Expanded caps the text at what is left after the button is
                  laid out, and the ellipsis below decides what to drop.
              */
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Jobs',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.neutral900,
                      ),
                    ),
                    Text(
                      _subtitle(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.neutral600,
                      ),
                    ),
                  ],
                ),
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
        /*
            Sized from the text, not from a number somebody measured once.

            This was a literal height, and it had been raised three times —
            140, then 150, then 168 — each time to fix an overflow that had
            just been reported, and each raise bought one more line of slack
            before the next one. The pattern is the bug: a fixed strip cannot
            hold content that grows, and the content grows the moment somebody
            turns their font size up, which Android lets everybody do.

            Multiplying by the text scale gives the cards exactly the room the
            text asked for, at every setting, without anybody having to
            remember to raise it again.

            The height stays uniform across the row on purpose. A horizontal
            carousel of cards that each size themselves looks broken, so the
            strip sets one height for all of them and the cards fill it.
        */
        SizedBox(
          height: 168 * MediaQuery.textScalerOf(context).scale(1.0),
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

  /*
      A card is 280 wide, unless the phone is not.

      280 plus the 16px padding on each side needs a 312px screen, and the
      narrowest Android still in use is 320 — so on those the card reached the
      edge with nothing to spare and the peek of the next card, which is what
      tells somebody the row scrolls, disappeared entirely.

      Leaving 56px means the next card always shows an edge, on every phone.
  */
  static double _cardWidth(BuildContext context) =>
      // The lower bound matters: a width can arrive as zero before the first
      // real layout, and a negative box constraint is a crash rather than an
      // ugly card.
      math.max(200.0, math.min(280.0, MediaQuery.sizeOf(context).width - 56));

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
          width: _cardWidth(context),
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
          width: _cardWidth(context),
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