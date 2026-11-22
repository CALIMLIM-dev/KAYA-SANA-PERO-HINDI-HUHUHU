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

/// One square per job taken through KAYA, then the sentence that counts them.
///
/// A filled square is a job finished, an outlined red one a job that did not
/// complete. The squares are the record itself, not a percentage of it: one
/// good job out of one is one square, a hundred out of a hundred is a hundred,
/// and nobody mistakes the first for the second the way a big "100%" made them.
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

  /// Past this many the squares stop being countable at a glance, and the
  /// sentence carries it alone.
  static const int maxSquares = 60;

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
        if (taken <= maxSquares) ...[
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (var i = 0; i < completed; i++) const _JobSquare(finished: true),
              for (var i = 0; i < unsuccessful; i++) const _JobSquare(finished: false),
            ],
          ),
          const SizedBox(height: 14),
        ],
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
          const SizedBox(height: 4),
          // The outlined square again, as its own key.
          Row(
            children: [
              const _JobSquare(finished: false, size: 12),
              const SizedBox(width: 8),
              Text(
                '$unsuccessful did not complete.',
                style: const TextStyle(fontSize: 13, color: AppColors.neutral600),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _JobSquare extends StatelessWidget {
  const _JobSquare({required this.finished, this.size = 18});

  final bool finished;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: finished ? AppColors.success : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: finished ? null : Border.all(color: AppColors.error, width: 1.5),
      ),
    );
  }
}

/// One row on a [RecordTimeline]: when, on the left; what, on the right.
class TimelineEntry {
  const TimelineEntry({
    required this.title,
    this.when,
    this.until,
    this.meta,
    this.note,
    this.current = false,
  });

  final String title;

  /// The start (or the only) date, shown strong: "Oct 2026".
  final String? when;

  /// The end, under it: "Present", "Feb 2018".
  final String? until;

  final String? meta;
  final String? note;

  /// Still going (a current job): its dot is filled.
  final bool current;
}

/// Dated rows joined by a rail, newest first.
///
/// For the record of work: the jobs finished through KAYA and the work
/// experience a worker typed in. The dates are the first thing read because
/// they are what makes a list of jobs a history.
class RecordTimeline extends StatelessWidget {
  const RecordTimeline({super.key, required this.entries});

  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          _row(entries[i], first: i == 0, last: i == entries.length - 1),
      ],
    );
  }

  Widget _row(TimelineEntry e, {required bool first, required bool last}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (e.when != null)
                    Text(e.when!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        )),
                  if (e.until != null)
                    Text(e.until!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.neutral500,
                          fontFeatures: [FontFeature.tabularFigures()],
                        )),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 24,
            child: Column(
              children: [
                // The rail runs through the dot, so the rows read as one line.
                Container(width: 2, height: 5, color: first ? Colors.transparent : AppColors.neutral200),
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: e.current || first ? AppColors.primary : Colors.white,
                    border: Border.all(
                      color: e.current || first ? AppColors.primary : AppColors.neutral400,
                      width: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(width: 2, color: last ? Colors.transparent : AppColors.neutral200),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.neutral900, height: 1.25)),
                  if (e.meta != null && e.meta!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(e.meta!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.neutral600, height: 1.3)),
                  ],
                  if (e.note != null && e.note!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(e.note!,
                        style: const TextStyle(fontSize: 13.5, color: AppColors.neutral700, height: 1.45)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
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

    return RecordTimeline(
      entries: [
        for (final row in history)
          TimelineEntry(
            title: (row['job_title'] ?? 'Job').toString(),
            when: monthYear(row['completed_at']?.toString()),
            meta: [row['category']?.toString(), row['city']?.toString()]
                .where((s) => s != null && s.isNotEmpty)
                .join('  ·  '),
          ),
      ],
    );
  }

  /// "Sep 2026". The day is not shown — it says nothing useful about the work
  /// and it narrows down where somebody was on a given date.
  static String? monthYear(String? iso) {
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
