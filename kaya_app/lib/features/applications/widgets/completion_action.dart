import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_toast.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/job_provider.dart';

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
        'The $otherParty has to confirm as well.',
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

  /*
      Both lists, from the server, before the caller's own refresh.

      markComplete merges the server's row into ApplicationProvider, which is
      the worker's list. The employer's card is not built from that at all - it
      reads JobProvider's `hire` - so confirming from the employer side updated
      a list that side never renders, and Mark as complete sat there until the
      app was restarted.

      Refreshed here rather than left to each call site, because there are
      three of them across two screens and the one that was wrong was wrong
      silently. A completion changes both sides of the same job by definition,
      so both are refetched whoever pressed the button.
  */
  await refreshActivity(context);
  if (!context.mounted) return;

  await onChanged();
}

/*
    Refetches whichever activity lists this account actually has.

    Completing and reviewing both change a row that two screens render from two
    different providers - the worker reads ApplicationProvider, the employer
    reads JobProvider - and every call site was left to remember that on its
    own. The ones that forgot left a button on screen for something that had
    already happened, which is how Mark as complete and Review both survived
    being pressed and needed the app restarted.
*/
Future<void> refreshActivity(BuildContext context) async {
  final appMode = context.read<AppModeProvider>();

  await Future.wait([
    if (appMode.hasWorkerProfile)
      context.read<ApplicationProvider>().fetchMyApplications(),
    if (appMode.hasEmployerProfile) context.read<JobProvider>().fetchMyJobs(),
  ]);
}

/*
    When the work was due to be finished.

    The job's end date, or its start date when it is one day. Read straight
    out of the job map because the activity lists hold maps rather than Job
    models; it is the same fact as Job.lastDay and JobPost::deadline.

    Null for a post made before jobs had dates. Those have no deadline and are
    not held to one.
*/
DateTime? jobDeadline(Map<String, dynamic>? job) {
  final raw = (job?['end_date'] ?? job?['start_date']) as String?;
  final parsed = raw == null ? null : DateTime.tryParse(raw);

  return parsed == null
      ? null
      : DateTime(parsed.year, parsed.month, parsed.day);
}

/*
    Whether Mark as complete belongs on screen at all yet.

    It does not exist before the job's last day, so that finishing a job means
    the work was due to be done rather than somebody tapping a button on the
    afternoon they were hired. The last day itself counts - work finishes
    during the day, and neither side should have to wait for midnight to say
    so - and the server applies the same rule, so a stale screen is refused
    rather than obeyed.
*/
bool completionHasOpened(Map<String, dynamic>? job) {
  final deadline = jobDeadline(job);
  if (deadline == null) return true;

  final now = DateTime.now();

  return !deadline.isAfter(DateTime(now.year, now.month, now.day));
}

/// The line the card carries while the button is still to come.
String? completionWaitNote(Map<String, dynamic>? job) {
  final deadline = jobDeadline(job);
  if (deadline == null || completionHasOpened(job)) return null;

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  return 'Due ${months[deadline.month - 1]} ${deadline.day}'
      ' · mark complete opens that day';
}
