import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../utils/json_parse.dart';

/// How a list of workers (Applicants, Suggested Workers) is ordered.
enum ResumeSort {
  best('Best Match'),
  nearest('Nearest'),
  rated('Highest Rated'),
  jobs('Most Jobs Done');

  const ResumeSort(this.label);
  final String label;

  /// The rows in this order. Best Match keeps the server's order (skills
  /// first, then fit and strength, anyone busy on the start day last). The
  /// others are stable: workers equal on the key keep that order.
  List<Map<String, dynamic>> apply(List<Map<String, dynamic>> rows) {
    if (this == ResumeSort.best) return rows;

    double key(Map<String, dynamic> r) => switch (this) {
          // Nearest first; no known distance goes last.
          ResumeSort.nearest => asDoubleOrNull(r['distance_km']) ?? double.infinity,
          ResumeSort.rated => -((asDoubleOrNull(r['worker_rating'] ?? r['rating_avg']) ?? 0) * 1000 +
              (asIntOrNull(r['reviews_total'] ?? r['worker_rating_count'] ?? r['rating_count']) ?? 0)),
          ResumeSort.jobs => -(asIntOrNull(r['jobs_completed']) ?? 0).toDouble(),
          ResumeSort.best => 0,
        };

    final indexed = rows.indexed.toList()
      ..sort((a, b) {
        final byKey = key(a.$2).compareTo(key(b.$2));
        return byKey != 0 ? byKey : a.$1.compareTo(b.$1);
      });
    return [for (final (_, row) in indexed) row];
  }
}

/// The four choices as a row of chips.
class ResumeSortChips extends StatelessWidget {
  const ResumeSortChips({super.key, required this.value, required this.onChanged});

  final ResumeSort value;
  final ValueChanged<ResumeSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final sort in ResumeSort.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(sort.label),
                selected: sort == value,
                onSelected: (_) => onChanged(sort),
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: sort == value ? AppColors.primary : AppColors.neutral600,
                ),
                selectedColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundColor: Colors.white,
                side: BorderSide(color: sort == value ? AppColors.primary : AppColors.neutral300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
        ],
      ),
    );
  }
}
