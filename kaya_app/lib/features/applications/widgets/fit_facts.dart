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

/*
    Which of the worker's own skills met which requirement, from the
    server's matched_pairs: [{required, held}]. The words can differ -
    "Tubero" meets "Ayos ng tagas" because the System linked both to the
    same skill - and each person sees their own words with a check.
*/
List<({String required, String held})> matchedPairs(Map<String, dynamic> row) =>
    ((row['matched_pairs'] as List?) ?? const [])
        .whereType<Map>()
        .map((p) => (required: '${p['required'] ?? ''}', held: '${p['held'] ?? ''}'))
        .where((p) => p.required.isNotEmpty && p.held.isNotEmpty)
        .toList();

/// The worker's own skill names that met a requirement, lower-cased.
Set<String> matchedHeld(Map<String, dynamic> row) =>
    matchedPairs(row).map((p) => p.held.toLowerCase()).toSet();

/// The pairs whose words differ, for the "Tubero matches your ..." lines.
List<({String required, String held})> differentWords(Map<String, dynamic> row) =>
    matchedPairs(row).where((p) => p.held.toLowerCase() != p.required.toLowerCase()).toList();

/// "✓ Tubero matches your "Ayos ng tagas"", under the chips.
class MatchWordsLine extends StatelessWidget {
  const MatchWordsLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1, right: 5),
            child: Icon(Icons.check, size: 14, color: AppColors.primary),
          ),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.neutral700)),
          ),
        ],
      ),
    );
  }
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
