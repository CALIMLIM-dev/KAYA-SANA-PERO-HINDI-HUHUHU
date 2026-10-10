import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/*
    How an applicant fits a job, in the words an employer can check.

    "Required skills: 1 of 2 (LCD Replacement) · Same trade · About 3 km
    away". The list is ordered by exactly these facts - required skills
    first, then trade, then the rest - so the line explains the rank instead
    of a number standing in for it. Built from one row of the applicants or
    matches payload.
*/
String? employerFitLine(Map<String, dynamic> row) {
  final required = (row['required_count'] as num?)?.toInt() ?? 0;
  final matched = (row['matched_count'] as num?)?.toInt() ?? 0;
  final names = ((row['matched_skills'] as List?) ?? const [])
      .map((s) => _title(s.toString()))
      .where((s) => s.isNotEmpty)
      .toList();
  final sameTrade = row['same_trade'] == true;
  final distance = (row['distance_label'] ?? '').toString();

  final parts = <String>[
    if (required > 0)
      'Required skills: $matched of $required'
          '${names.isEmpty ? '' : ' (${names.join(', ')})'}',
    if (sameTrade) 'Same trade',
    if (distance.isNotEmpty) distance,
  ];

  return parts.isEmpty ? null : parts.join(' · ');
}

/// Whether the row holds a required skill, or fits a job that names none.
bool meetsRequirements(Map<String, dynamic> row) =>
    ((row['match_tier'] as num?)?.toInt() ?? 0) >= 2;

/// "lcd replacement" as "Lcd Replacement" - the server sends normalised names.
String _title(String s) => s
    .split(' ')
    .where((w) => w.isNotEmpty)
    .map((w) => w.length <= 4 && !RegExp('[aeiou]').hasMatch(w)
        ? w.toUpperCase()
        : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/*
    No reviews and no finished jobs yet.

    Stated, not scored: a newcomer is neither pushed down nor lifted for it.
    The employer sees that the profile is new and decides for themselves -
    the honest answer to a ranking that would otherwise never give anyone a
    first job.
*/
class NewOnKayaTag extends StatelessWidget {
  const NewOnKayaTag({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : AppColors.neutral700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.18) : AppColors.neutral100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: onDark ? Colors.white.withValues(alpha: 0.35) : AppColors.neutral300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_new_outlined, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            'New on KAYA',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}
