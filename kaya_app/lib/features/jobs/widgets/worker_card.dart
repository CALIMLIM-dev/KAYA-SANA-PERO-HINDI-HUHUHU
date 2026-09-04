import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/utils/format.dart';

/// Worker directory card — employer-mode Search/Home. Distinct from
/// FeaturedJobCard: workers have an availability status, not a price, and no
/// bookmark/applied state, so this isn't a relabeled job card.
class WorkerCard extends StatelessWidget {
  final String name;
  final String primarySkill;
  final String location;
  final String rating;
  final String reviews;
  final bool isAvailable;
  final bool isVerified;
  final List<String> skills;
  final int? matchScore;
  final double? distanceKm;

  /// The servers phrasing, e.g. "P500-P800/day - Open to offers".
  final String? rateLabel;

  /// The worker's photo. The card drew an initial in a rounded square and
  /// had no field for this at all, so search results were faceless even
  /// though the browse endpoint has always sent a resolved avatar URL.
  final String? imageUrl;
  final VoidCallback? onTap;

  const WorkerCard({
    super.key,
    required this.name,
    required this.primarySkill,
    required this.location,
    required this.rating,
    required this.reviews,
    required this.isAvailable,
    this.isVerified = false,
    this.skills = const [],
    this.matchScore,
    this.distanceKm,
    this.rateLabel,
    this.imageUrl,
    this.onTap,
  });

  Color get _matchColor {
    final p = matchScore ?? 0;
    if (p >= 80) return AppColors.success;
    if (p >= 50) return AppColors.warning;
    return AppColors.neutral600;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: avatar + info ────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Circle, like every other avatar. This was a rounded square
                // with an initial in it, so the same worker looked like a
                // different kind of thing in search and on their profile.
                ProfileAvatar(
                  imageUrl: imageUrl,
                  name: name,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.neutral900,
                              ),
                              overflow: TextOverflow.ellipsis,
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
                      Text(
                        primarySkill,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.neutral600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: AppColors.neutral400),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              distanceKm != null
                                  ? '$location · ${formatDistance(distanceKm!)}'
                                  : location,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.neutral400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      // What they charge, straight from the server so this
                      // card, the profile and the search result all phrase it
                      // the same way. Absent when no rate is set — an employer
                      // reading "₱0" would think the worker works for nothing.
                      if (rateLabel != null && rateLabel!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          rateLabel!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Row 2: skill chips ──────────────────────────────────────────
            if (skills.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: skills.take(4).map((skill) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.neutral200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      skill,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.neutral600,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // ── Row 3: availability + match % + rating ─────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isAvailable ? AppColors.success : AppColors.neutral400)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAvailable
                              ? AppColors.success
                              : AppColors.neutral400,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAvailable ? 'Available now' : 'Currently busy',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isAvailable
                              ? AppColors.success
                              : AppColors.neutral600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (reviews.isNotEmpty) ...[
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 15),
                  const SizedBox(width: 3),
                  Text(
                    '$rating $reviews',
                    style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
                  ),
                ],
                if (matchScore != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _matchColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$matchScore% match',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _matchColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // ── Row 4: view profile ─────────────────────────────────────────
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Profile',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_forward_ios,
                          size: 11, color: AppColors.primary),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
