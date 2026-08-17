import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_toast.dart';
import '../../../providers/application_provider.dart';

/// Records one side's confirmation that the work is finished.
///
/// Shared by the worker's application card, the employer's job card and the
/// applicant list, so all three behave identically. Which side you are on is
/// worked out by the server from the job — the app never says, because a client
/// that could would let a worker confirm on the employer's behalf and then
/// review them unilaterally.
///
/// Confirmed first because it is not freely reversible: it tells the other
/// party the job is over, and it is what unlocks reviewing.
Future<void> confirmCompletion(
  BuildContext context,
  int applicationId,
  String otherParty,
  Future<void> Function() onChanged,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Mark this job complete?'),
      content: Text(
        'The $otherParty has to confirm as well before the job counts as '
        'finished and either of you can leave a review.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Not yet'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Mark complete'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final provider = context.read<ApplicationProvider>();
  final ok = await provider.markComplete(applicationId);

  if (!context.mounted) return;

  if (!ok) {
    AppToast.error(context, provider.errorMessage ?? 'Could not mark complete');
    return;
  }

  // The server's own wording, which differs by outcome: "waiting for the other
  // side" or "both sides confirmed". Saying "Marked complete" in the first case
  // would tell the user the job is finished when it is not.
  AppToast.show(
    context,
    provider.lastCompletionMessage ?? 'Marked complete',
    type: ToastType.success,
  );

  await onChanged();
}
