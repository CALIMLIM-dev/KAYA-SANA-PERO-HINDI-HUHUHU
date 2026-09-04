import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class FeaturedJobCard extends StatelessWidget {
  final String title;
  final String company;
  final String location;
  final String rating;
  final String reviews;
  final String salary;
  final bool isUrgent;
  final bool requiresVerification;
  final String? category;
  final String? distance;
  final bool? hasApplied;
  final VoidCallback? onTap;
  final List<String> requiredSkills;

  /// Worker's own skills — pass empty list for employer view (no match shown)
  final List<String> workerSkills;

  /// Server-computed match (JobMatchService) — category-first, so a same-trade
  /// worker with no exact skill overlap still scores and stays visible. Takes
  /// priority over the client-side skill-overlap fallback below.
  final int? matchScore;

  /// Whether this job is bookmarked, and what to do when the mark is
  /// tapped. The bookmark on this card was a bare Icon with no handler and
  /// a permanently empty outline - it could not be pressed and never showed
  /// that a job had already been saved.
  final bool isSaved;
  final VoidCallback? onToggleSave;

  const FeaturedJobCard({
    super.key,
    required this.title,
    required this.company,
    required this.location,
    required this.rating,
    required this.reviews,
    required this.salary,
    this.isUrgent = false,
    this.requiresVerification = false,
    this.category,
    this.distance,
    this.hasApplied,
    this.onTap,
    this.requiredSkills = const [],
    this.workerSkills = const [],
    this.matchScore,
    this.isSaved = false,
    this.onToggleSave,
  });

  // ─── match calculation ───────────────────────────────────────────────────────

  bool get _showMatch =>
      matchScore != null || (workerSkills.isNotEmpty && requiredSkills.isNotEmpty);

  int get _matchPercent {
    if (matchScore != null) return matchScore!;
    if (workerSkills.isEmpty || requiredSkills.isEmpty) return 0;
    final wLower = workerSkills.map((s) => s.toLowerCase()).toSet();
    final matched =
        requiredSkills.where((s) => wLower.contains(s.toLowerCase())).length;
    return ((matched / requiredSkills.length) * 100).round();
  }

  Color get _matchColor {
    final p = _matchPercent;
    if (p >= 80) return AppColors.success;
    if (p >= 50) return AppColors.warning;
    return AppColors.neutral600;
  }

  // ─── build ───────────────────────────────────────────────────────────────────

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
            // ── Row 1: icon + info + bookmark ──────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_categoryIcon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + urgent tag on same line
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.neutral900,
                              ),
                            ),
                          ),
                          if (isUrgent) ...[
                            const SizedBox(width: 6),
                            _smallTag('Urgent', AppColors.accent),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Company + verified
                      Row(
                        children: [
                          if (requiresVerification)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.verified,
                                  size: 13, color: AppColors.success),
                            ),
                          Flexible(
                            child: Text(
                              company,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: AppColors.neutral600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Location
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: AppColors.neutral400),
                          const SizedBox(width: 2),
                          // Barangay plus city plus province plus a distance
                          // is a long line, and it is the only thing on this
                          // row that can give way.
                          Expanded(
                            child: Text(
                              distance != null
                                  ? '$location · $distance'
                                  : location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.neutral400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // A real control now, and one that shows its state. Sized to
                // a proper tap target: a bare 20px icon sits well under the
                // 48dp minimum and was awkward to hit even once it did
                // something.
                InkWell(
                  onTap: onToggleSave,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: 20,
                      color: isSaved ? AppColors.primary : AppColors.neutral400,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Row 2: skill chips ──────────────────────────────────────────
            if (requiredSkills.isNotEmpty) ...[
              _buildSkillChips(),
              const SizedBox(height: 12),
            ],

            // ── Row 3: salary + match % + rating ───────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Salary
                Text(
                  salary,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral900,
                  ),
                ),
                const Spacer(),
                // Rating
                const Icon(Icons.star_rounded,
                    color: Colors.amber, size: 15),
                const SizedBox(width: 3),
                Text(
                  '$rating $reviews',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.neutral500),
                ),
                // Match pill — subtle, right-aligned
                if (_showMatch) ...[
                  const SizedBox(width: 10),
                  _matchPill(),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // ── Row 4: applied badge + view details ────────────────────────
            Row(
              children: [
                if (hasApplied == true) ...[
                  _smallTag('Applied', AppColors.success),
                  const SizedBox(width: 8),
                ],
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
                        'View Details',
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

  // ─── skill chips ─────────────────────────────────────────────────────────────

  Widget _buildSkillChips() {
    final wLower = workerSkills.map((s) => s.toLowerCase()).toSet();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: requiredSkills.map((skill) {
        final matched =
            wLower.isNotEmpty && wLower.contains(skill.toLowerCase());
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: matched
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.neutral200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (matched) ...[
                const Icon(Icons.check,
                    size: 11, color: AppColors.success),
                const SizedBox(width: 3),
              ],
              Text(
                skill,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: matched
                      ? AppColors.success
                      : AppColors.neutral600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── match pill ──────────────────────────────────────────────────────────────

  Widget _matchPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _matchColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$_matchPercent% match',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _matchColor,
        ),
      ),
    );
  }

  // ─── small tag ───────────────────────────────────────────────────────────────

  Widget _smallTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ─── category icon ───────────────────────────────────────────────────────────

  IconData get _categoryIcon {
    switch (category?.toLowerCase()) {
      case 'plumbing':
        return Icons.plumbing;
      case 'electrical':
        return Icons.electrical_services;
      case 'painting':
        return Icons.format_paint;
      case 'carpentry':
      case 'construction':
        return Icons.construction;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'ac repair':
      case 'hvac':
        return Icons.ac_unit;
      default:
        return Icons.work_outline;
    }
  }
}
