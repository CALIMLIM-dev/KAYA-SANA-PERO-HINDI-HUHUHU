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
            // The whole post, as My Jobs holds it: the form fills itself in
            // from it, photos and pin included. A hand-picked subset is how
            // the old edit screen lost fields and wrote defaults back.
            AppRouter.push(context, '/edit-job', arguments: job);
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
