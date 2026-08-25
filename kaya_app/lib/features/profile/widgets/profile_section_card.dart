import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// One section of a profile: what it holds, and a way into it.
///
/// The pattern hiring apps settled on, and for a reason worth stating. A
/// profile edited inline becomes one enormous screen where every field is
/// present at once, nothing is findable, and the act of changing a phone
/// number means scrolling past nine other things. A card per section turns
/// that into a table of contents: you see what you have, what you are missing,
/// and you go and fix one thing.
///
/// An empty section says so and offers to fill it, rather than rendering
/// nothing and leaving somebody to wonder whether the app lost their data.
class ProfileSectionCard extends StatelessWidget {
  const ProfileSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.summary,
    this.count,
    this.isEmpty = false,
    this.emptyLabel = 'Not added yet',
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  /// What is in there — a name, a place, the first couple of skills.
  final String? summary;

  /// For sections that hold a list, so "3" can sit beside the title.
  final int? count;

  final bool isEmpty;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                // An unfilled section is outlined in the accent rather than
                // greyed out. Grey reads as disabled; this reads as an
                // invitation, which is what it is.
                color: isEmpty
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : AppColors.neutral200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 19, color: AppColors.primary),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neutral900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (count != null && count! > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.neutral100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.neutral600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isEmpty ? emptyLabel : (summary ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isEmpty
                              ? AppColors.primary
                              : AppColors.neutral600,
                          fontWeight:
                              isEmpty ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isEmpty ? Icons.add : Icons.chevron_right,
                  size: isEmpty ? 20 : 22,
                  color: isEmpty ? AppColors.primary : AppColors.neutral400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A heading above a run of section cards.
class ProfileSectionHeading extends StatelessWidget {
  const ProfileSectionHeading(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 2),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: AppColors.neutral500,
        ),
      ),
    );
  }
}
