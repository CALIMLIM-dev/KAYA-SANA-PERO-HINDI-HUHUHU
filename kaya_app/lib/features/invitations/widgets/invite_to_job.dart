import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/credits.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../providers/credits_provider.dart';
import '../../../providers/invitation_provider.dart';
import '../../../providers/job_provider.dart';

/*
    Picking one of your open jobs and inviting someone to it.

    This lived inside the worker profile screen, which meant the only way to
    hire someone you already know was to go and find their profile first. For a
    repeat hire that is the wrong shape entirely: you already have a
    conversation with everyone you have ever hired, so the inbox is the list of
    past workers, and the trip out to a profile screen is pure detour.

    Lifted out so the chat can offer it too. One dialog, two doors — rather than
    a second copy that drifts from this one the first time either is touched.
*/
Future<void> showInviteToJobSheet(
  BuildContext context, {
  required int workerId,
  required String workerName,
}) async {
  final jobProvider = context.read<JobProvider>();
  await jobProvider.fetchMyJobs();
  if (!context.mounted) return;

  // Only open jobs can carry an invitation — the server refuses the rest, so
  // offering them here would just be a slower way to reach an error.
  final openJobs = jobProvider.jobs
      .where((j) => (j['status'] ?? '').toString() == 'open')
      .toList();

  if (openJobs.isEmpty) {
    AppToast.info(context, 'Post an open job first, then you can invite $workerName.');
    return;
  }

  final credits = context.read<CreditsProvider>();
  await credits.load();
  if (!context.mounted) return;

  final cost = credits.costOf('invite');

  // Short already: say so before showing a picker that cannot be acted on.
  if (cost != null && !credits.canAfford('invite')) {
    AppToast.error(context, 'You need ${Credits.amount(cost)} to invite someone.');
    return;
  }

  final jobId = await showDialog<int>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Invite to apply'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Which job is $workerName being invited to?',
                style: const TextStyle(fontSize: 13.5, color: AppColors.neutral600)),

            /*
                The cost, in the dialog that is already the confirmation.

                Not a second dialog on top of this one: the job picker is the
                moment the employer commits, so the price belongs here. Hidden
                when the wallet has not loaded rather than guessed, since a
                wrong number about money is worse than no number.
            */
            if (cost != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Credits.icon, size: 15, color: AppColors.primary),
                  const SizedBox(width: 5),
                  Text(
                    'Costs ${Credits.amount(cost)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: openJobs.length,
                itemBuilder: (_, i) {
                  final job = openJobs[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text((job['title'] ?? 'Untitled').toString(),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text((job['location'] ?? '').toString(),
                        style: const TextStyle(fontSize: 12)),
                    onTap: () => Navigator.pop(dialogContext, job['id'] as int?),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel')),
      ],
    ),
  );

  if (jobId == null || !context.mounted) return;

  final provider = context.read<InvitationProvider>();
  final sent = await provider.sendInvitation(jobId: jobId, workerId: workerId);
  if (!context.mounted) return;

  if (sent) {
    // The balance just moved. Refetched rather than decremented locally.
    await credits.refresh();
    if (!context.mounted) return;

    AppToast.success(context, 'Invitation sent to $workerName.');
    return;
  }

  /*
      The server's own reason, not a generic failure.

      It knows things this screen does not: already invited to that job, the
      worker is suspended, the job closed while the dialog was open, or the
      worker is already hired for a date this job clashes with. Every one of
      those needs a different response from the employer.
  */
  AppToast.error(
    context,
    provider.errorMessage ?? 'Could not send the invitation.',
  );
}
