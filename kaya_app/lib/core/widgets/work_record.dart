import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/*
    The completion record and work history, for a public profile.

    One widget for both sides on purpose. A worker judging an employer is
    asking exactly what an employer asks about an applicant — does this person
    finish what they start — and only the worker was ever being judged. An
    employer who habitually never confirms completion costs the worker a review
    and a rating, and nothing on their profile could show it.

    Kept separate from either screen so the two cannot drift, which is what
    happened to the activity cards twice.
*/

/// "Finished 8 of 9 jobs taken through KAYA (89%)", or a plain line when
/// nothing has finished yet.
///
/// Said as a sentence, not drawn as a dashboard: a big coloured percentage
/// over a progress bar is a template, and it made one good job out of one
/// look as loud as a hundred out of a hundred. The numbers are bold; the
/// sentence says what they count.
///
/// success_rate arrives as null for an account with no finished work, and that
/// is deliberate — see WorkRecord on the server. Rendering it as 0% would read
/// as a bad record earned by nothing, which is the worst thing a new profile
/// could say about someone.
class CompletionRecord extends StatelessWidget {
  const CompletionRecord({
    super.key,
    required this.completed,
    required this.unsuccessful,
    required this.successRate,
  });

  final int completed;
  final int unsuccessful;
  final int? successRate;

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(fontSize: 14, height: 1.5, color: AppColors.neutral700);
    const strong = TextStyle(fontWeight: FontWeight.w700, color: AppColors.neutral900);

    if (successRate == null) {
      return const Text('No finished jobs yet.', style: TextStyle(fontSize: 14, color: AppColors.neutral500));
    }

    final taken = completed + unsuccessful;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: body,
            children: [
              const TextSpan(text: 'Finished '),
              TextSpan(text: '$completed', style: strong),
              const TextSpan(text: ' of '),
              TextSpan(text: '$taken', style: strong),
              TextSpan(text: ' job${taken == 1 ? '' : 's'} taken through KAYA ('),
              TextSpan(text: '$successRate%', style: strong),
              const TextSpan(text: ').'),
            ],
          ),
        ),
        if (unsuccessful > 0) ...[
          const SizedBox(height: 2),
          Text(
            '$unsuccessful did not complete.',
            style: const TextStyle(fontSize: 13, color: AppColors.neutral500),
          ),
        ],
      ],
    );
  }
}

/// The jobs actually finished through KAYA.
///
/// Distinct from the worker's own "Work Experience", which is what they typed
/// in about jobs elsewhere. This list is the part the app can vouch for, and
/// it carries no counterpart names — who hired whom is between those two.
class WorkHistoryList extends StatelessWidget {
  const WorkHistoryList({super.key, required this.history});

  final List<Map<String, dynamic>> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Text(
        'Nothing finished through KAYA yet.',
        style: TextStyle(fontSize: 13, color: AppColors.neutral500),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < history.length; i++) ...[
          if (i > 0) const Divider(height: 20, color: AppColors.neutral200),
          _entry(history[i]),
        ],
      ],
    );
  }

  /// The job, its trade and town, and the month. No icon: every row would
  /// carry the same one, which says nothing the heading has not.
  Widget _entry(Map<String, dynamic> row) {
    final title = (row['job_title'] ?? 'Job').toString();
    final category = row['category']?.toString();
    final city = row['city']?.toString();
    final date = _month(row['completed_at']?.toString());
    final meta = [category, city].where((s) => s != null && s.isNotEmpty).join('  ·  ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.neutral600),
                ),
              ],
            ],
          ),
        ),
        if (date != null) ...[
          const SizedBox(width: 12),
          Text(date, style: const TextStyle(fontSize: 12, color: AppColors.neutral500)),
        ],
      ],
    );
  }

  /// "Sep 2026". The day is not shown — it says nothing useful about the work
  /// and it narrows down where somebody was on a given date.
  static String? _month(String? iso) {
    if (iso == null) return null;
    final date = DateTime.tryParse(iso);
    if (date == null) return null;

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
