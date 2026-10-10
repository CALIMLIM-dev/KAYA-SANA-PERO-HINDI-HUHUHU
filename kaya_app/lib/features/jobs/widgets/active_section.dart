import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/motion.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/job_provider.dart';
import '../../applications/screens/applications_screen.dart';

/*
    Active work, on the home screen.

    What was My Activity's Active tab, moved here whole: the same cards, read
    through the same activeItems rule, for a worker and an employer alike.
    The first version was a compact summary of its own, and a summary is a
    second drawing of the same job that has to be kept in step with the
    first. This is the first.

    Two compact cards, then See all. However many jobs are running, the
    section is never taller than two cards; the rest are one tap away on
    the Active screen.
*/
class ActiveSection extends StatelessWidget {
  const ActiveSection({super.key, required this.onChanged, this.maxRows = 2});

  /// Refetches the home screen after a card changes something.
  final Future<void> Function() onChanged;

  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final items = activeItems(
      context.watch<AppModeProvider>(),
      context.watch<ApplicationProvider>(),
      context.watch<JobProvider>(),
    );

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral900,
                    ),
                  ),
                ),
                if (items.length > maxRows)
                  TextButton(
                    onPressed: () => AppRouter.push(context, AppRouter.active),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: Text('See all ${items.length}'),
                  ),
              ],
            ),
          ),
          // One panel, rows divided by a hairline: a list of jobs in
          // progress, not a stack of boxes.
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.neutral200),
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  for (final (i, row) in items.take(maxRows).indexed) ...[
                    if (i > 0) const Divider(height: 1, color: AppColors.neutral200),
                    EntranceIn(
                      key: ValueKey(row['id'] ?? i),
                      index: i,
                      child: activeCard(row, onChanged, compact: true),
                    ),
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
