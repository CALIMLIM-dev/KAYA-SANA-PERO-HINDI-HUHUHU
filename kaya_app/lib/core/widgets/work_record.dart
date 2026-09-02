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

/// "8 completed · 89%", or a plain line when nothing has finished yet.
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
    if (successRate == null) {
      return Row(
        children: [
          const Icon(Icons.history_toggle_off,
              size: 16, color: AppColors.neutral400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No finished jobs yet',
              style: const TextStyle(fontSize: 13, color: AppColors.neutral500),
            ),
          ),
        ],
      );
    }

    // Green at 80 and above, amber in the middle, red below half. The bands
    // are wide on purpose: one bad job out of five is not a warning.
    final rate = successRate!;
    final colour = rate >= 80
        ? AppColors.success
        : rate >= 50
            ? AppColors.warning
            : AppColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('$rate%',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: colour)),
            const SizedBox(width: 8),
            const Text('completion rate',
                style: TextStyle(fontSize: 13, color: AppColors.neutral600)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rate / 100,
            minHeight: 6,
            backgroundColor: AppColors.neutral200,
            valueColor: AlwaysStoppedAnimation(colour),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          unsuccessful == 0
              ? '$completed finished'
              : '$completed finished · $unsuccessful did not complete',
          style: const TextStyle(fontSize: 12.5, color: AppColors.neutral600),
        ),
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

  Widget _entry(Map<String, dynamic> row) {
    final title = (row['job_title'] ?? 'Job').toString();
    final category = row['category']?.toString();
    final city = row['city']?.toString();
    final date = _month(row['completed_at']?.toString());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.check, size: 18, color: AppColors.success),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral900)),
              if (category != null || city != null) ...[
                const SizedBox(height: 3),
                Text(
                  [category, city].where((s) => s != null && s.isNotEmpty).join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.neutral600),
                ),
              ],
            ],
          ),
        ),
        if (date != null) ...[
          const SizedBox(width: 8),
          Text(date,
              style: const TextStyle(fontSize: 12, color: AppColors.neutral400)),
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
