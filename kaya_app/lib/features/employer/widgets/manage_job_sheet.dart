import 'package:flutter/material.dart';
import '../../../core/widgets/kaya_popup.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../providers/job_provider.dart';
import '../screens/roster_screen.dart';

/*
    Edit or close one of your posts.

    Lifted out of My Jobs when running posts moved to the home screen's
    Active section, so the card there offers the same Manage as the card
    that used to be in My Jobs rather than a second copy of it.
*/
void showManageJobSheet(BuildContext context, Map<String, dynamic> job) {
  final jobId = job['id'] as int;
  final title = (job['title'] ?? '').toString();
  final category = job['category'] as Map<String, dynamic>?;

  showKayaPopup(
    context,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral900)),
          const SizedBox(height: 4),
          const Text('Choose an action',
              style: TextStyle(fontSize: 13.5, color: AppColors.neutral600)),
          const SizedBox(height: 20),
          _actionTile(Icons.edit_outlined, 'Edit Job', AppColors.primary, () {
            Navigator.pop(sheetContext);
            /*
                Everything the edit form can change has to arrive here.

                Only half of it used to. The form opened with its own
                defaults for the rest — not urgent, Daily, no maximum — so an
                urgent job displayed as ordinary, and saving would have
                written those defaults back over the real values.
            */
            AppRouter.push(context, '/edit-job', arguments: {
              'id': jobId,
              'title': job['title'],
              'category': category?['name'],
              'category_id': category?['id'],
              'description': job['description'],
              'budget_min': job['budget_min'],
              'budget_max': job['budget_max'],
              'budget_period': job['budget_period'],
              'is_urgent': job['is_urgent'],
              // Same reason as the fields above: the edit form sends these
              // back, so omitting them here would hand it nulls and wipe the
              // job's schedule on the first save.
              'start_date': job['start_date'],
              'end_date': job['end_date'],
              'skill_ids': (job['skills'] as List?)
                  ?.map((s) => (s as Map)['id'])
                  .whereType<int>()
                  .toList(),
              'location': job['city'] ?? job['location'],
              'location_id': job['location_id'],
              // Without this a job for five opened the form showing one.
              'workersNeeded': job['workers_needed'],
            });
          }),
          _actionTile(Icons.close, 'Close Job', AppColors.error, () {
            Navigator.pop(sheetContext);
            _confirmClose(context, jobId, title);
          }),
        ],
      ),
    ),
  );
}

/// The roster for a job with more than one person on it, and the job list
/// asked again on the way back: completions may have moved while it was open.
Future<void> openRoster(BuildContext context, int jobId) async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => RosterScreen(jobId: jobId)),
  );
  if (context.mounted) await context.read<JobProvider>().fetchMyJobs();
}

Widget _actionTile(IconData icon, String label, Color color, VoidCallback onTap) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    ),
    title: Text(label,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
    onTap: onTap,
  );
}

void _confirmClose(BuildContext context, int jobId, String title) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Close Job?'),
      content: Text('Close "$title"? Workers can no longer apply.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            final provider = context.read<JobProvider>();
            final ok = await provider.changeStatus(jobId, 'closed');
            if (!context.mounted) return;
            AppToast.info(
                context,
                ok
                    ? 'Job closed'
                    : provider.errorMessage ?? 'Failed to close job');
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Close Job', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
