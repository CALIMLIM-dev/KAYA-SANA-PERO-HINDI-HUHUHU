import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'compact_worker_card.dart';
import '../../../data/models/worker_profile_model.dart';

/// People Who Can Help Section - Horizontal scroll of worker profiles
class PeopleWhoCanHelpSection extends StatelessWidget {
  final List<WorkerProfile> workers;
  final bool isLoading;
  final String? userLocation;

  /*
      The place the list was fetched for.

      This was a radius - fifty kilometres by default, doubling to two hundred
      from the empty state. Nobody hiring a plumber is looking fifty kilometres
      away, and the number was a workaround for a location filter that matched
      city rows exactly and therefore matched nobody. The filter understands a
      city and its barangays now, so the section can say where it is looking.
  */
  final String? placeLabel;
  final VoidCallback? onSeeAll;
  final Function(WorkerProfile)? onWorkerTap;
  final Function(WorkerProfile)? onWorkerInvite;

  /// Opens the place picker from the empty state, which is the only thing
  /// that can help when nobody is here: look somewhere else.
  final VoidCallback? onChangePlace;

  const PeopleWhoCanHelpSection({
    super.key,
    required this.workers,
    this.isLoading = false,
    this.userLocation,
    this.placeLabel,
    this.onSeeAll,
    this.onWorkerTap,
    this.onWorkerInvite,
    this.onChangePlace,
  });

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
              // Expanded for the reason spelled out on the jobs row: without
              // it the heading pushes "See All" off the right edge.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Workers',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.neutral900,
                      ),
                    ),
                    /*
                        The place, and the way to change it.

                        This line stated a radius, and the only way to alter
                        the search was a "wider area" button that appeared
                        when the list was already empty. The place is the
                        input now, so it is a control wherever the list is -
                        full or empty.
                    */
                    InkWell(
                      onTap: onChangePlace,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (onChangePlace != null) ...[
                              const Icon(Icons.place_outlined,
                                  size: 13, color: AppColors.neutral600),
                              const SizedBox(width: 3),
                            ],
                            Flexible(
                              child: Text(
                                placeLabel != null && placeLabel!.trim().isNotEmpty
                                    ? placeLabel!.trim()
                                    : 'Anywhere',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.neutral600,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            if (onChangePlace != null)
                              const Icon(Icons.expand_more,
                                  size: 15, color: AppColors.neutral600),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      // Best first: rating, work finished, a verified ID and
                      // how near they are, with a paid boost above the rest.
                      'Best matches first',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.neutral600,
                      ),
                    ),
                  ],
                ),
              ),
              if (workers.isNotEmpty || !isLoading)
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
        
        // Workers Horizontal List
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
          height: 170 * MediaQuery.textScalerOf(context).scale(1.0),
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              // Prevent parent scroll view from handling horizontal scroll
              return true;
            },
            child: _buildWorkersList(),
          ),
        ),
      ],
    );
  }

  /// Never wider than the phone. Same reasoning as the jobs row.
  static double _cardWidth(BuildContext context) =>
      // The lower bound matters: a width can arrive as zero before the first
      // real layout, and a negative box constraint is a crash rather than an
      // ugly card.
      math.max(200.0, math.min(280.0, MediaQuery.sizeOf(context).width - 56));

  Widget _buildWorkersList() {
    if (isLoading) {
      return _buildLoadingState();
    }
    
    if (workers.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: workers.length,
      itemBuilder: (context, index) {
        final worker = workers[index];
        return Container(
          width: _cardWidth(context),
          margin: EdgeInsets.only(right: index < workers.length - 1 ? 12 : 0),
          child: CompactWorkerCard(
            worker: worker,
            onTap: () => onWorkerTap?.call(worker),
            onInvite: () => onWorkerInvite?.call(worker),
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
          child: _SkeletonWorkerCard(),
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
              Icons.person_search,
              size: 32,
              color: AppColors.neutral400,
            ),
            const SizedBox(height: 8),
            Text(
              'No workers nearby',
              style: TextStyle(
                color: AppColors.neutral600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              placeLabel != null && placeLabel!.trim().isNotEmpty
                  ? 'Nobody has set up a worker profile in ${placeLabel!.trim()} yet'
                  : 'No worker profiles yet',
              style: TextStyle(
                color: AppColors.neutral500,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            /*
                The only way out of an empty list, so it has to work.

                It used to offer a wider radius, which meant workers two towns
                over for a job somebody has to travel to. Looking somewhere
                else is the honest version of the same offer.
            */
            if (onChangePlace != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onChangePlace,
                child: Text(
                  'Look in another place',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonWorkerCard extends StatelessWidget {
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
          // Profile header skeleton
          Row(
            children: [
              // Avatar skeleton
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.neutral200,
              ),
              const SizedBox(width: 12),
              
              // Name and skill skeleton
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.neutral200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 100,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.neutral200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Availability skeleton
              Column(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.neutral200,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 30,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.neutral200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Rating skeleton
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.neutral200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.neutral200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 4),
          
          // Location skeleton
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.neutral200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 100,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.neutral200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          
          const Spacer(),
          
          // Bottom row skeleton
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.neutral200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 80,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.neutral200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 50,
                height: 24,
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