import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/services/api_client.dart';
import '../../moderation/widgets/evidence_photos.dart';
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
  Future<void> Function() onChanged, {
  /*
      Whether the deadline has arrived.

      The control used to be absent until it had. Completion takes both
      sides, so it was never possible to finish a job alone on the day
      you were hired - and hiding the button meant a pair who finished
      early could not agree that they had. Now it is there, and this is
      what decides whether it reads as finishing the job or as asking
      the other person whether it is finished.
  */
  bool early = false,
}) async {
  final photos = <XFile>[];
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(early
            ? 'Finished Early?'
            : 'Mark This Job as Complete?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(early
                  ? 'The $otherParty will be asked to confirm.'
                  : 'The $otherParty also needs to confirm.'),
              _TheirProof(applicationId: applicationId, otherParty: otherParty),
              const SizedBox(height: 12),
              EvidencePhotos(
                photos: photos,
                label: 'Photo as Proof (Optional)',
                onChanged: (picked) => setDialogState(() => photos
                  ..clear()
                  ..addAll(picked)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(early ? 'Yes, Mark as Complete' : 'Mark as Complete'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final provider = context.read<ApplicationProvider>();
  final ok = await provider.markComplete(applicationId, photos: photos);

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
    provider.lastCompletionMessage ?? 'Marked as complete',
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

/// The proof photos the other side added when they marked it complete.
/// Nothing at all when there are none, or when they cannot be loaded.
class _TheirProof extends StatefulWidget {
  const _TheirProof({required this.applicationId, required this.otherParty});

  final int applicationId;
  final String otherParty;

  @override
  State<_TheirProof> createState() => _TheirProofState();
}

class _TheirProofState extends State<_TheirProof> {
  // Once, not on every rebuild of the dialog around it.
  late final Future<List<Uint8List>> _photos = _load();

  Future<List<Uint8List>> _load() async {
    try {
      final api = ApiClient();
      final res = await api.get('/applications/${widget.applicationId}/completion');
      final count = (res.data['data']?['hire_actions']?['their_photos'] as num?)?.toInt() ?? 0;

      return [
        for (var i = 0; i < count; i++)
          Uint8List.fromList((await api.getBytes('/applications/${widget.applicationId}/proof/$i')).data ?? const []),
      ];
    } catch (_) {
      return const [];
    }
  }

  void _open(Uint8List bytes) => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: InteractiveViewer(maxScale: 5, child: Image.memory(bytes, fit: BoxFit.contain)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Uint8List>>(
      future: _photos,
      builder: (context, snapshot) {
        final photos = snapshot.data ?? const [];
        if (photos.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Photos from the ${widget.otherParty}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.neutral700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final bytes in photos)
                    InkWell(
                      onTap: () => _open(bytes),
                      borderRadius: BorderRadius.circular(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(bytes, width: 64, height: 64, fit: BoxFit.cover),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
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
    When the work is due to be finished.

    The server sends `deadline` already worked out, because two dates can
    answer this and only it knows which won: the day the pair agreed in the
    chat beats the date on the post, and the post's own date applies when
    nothing was agreed. See JobPost::deadline.

    The end_date fallback is for a payload from a server that has not been
    updated yet, and for the job maps the app builds itself. Null for a post
    made before jobs had dates - those have no deadline and are not held to
    one.
*/
DateTime? jobDeadline(Map<String, dynamic>? job) {
  final raw = (job?['deadline'] ?? job?['end_date'] ?? job?['start_date']) as String?;
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

/*
    The line the card carries while the button is still to come.

    It names the way out as well as the date. Somebody who has finished the
    work three days early does not want to be told to wait - they want to
    know that agreeing today's date in the chat moves the deadline, which it
    does, because an agreed day beats the posted one.

    Where the day already came from the chat it says so, so nobody wonders
    why the card disagrees with the post.
*/
String? completionWaitNote(Map<String, dynamic>? job) {
  final deadline = jobDeadline(job);
  if (deadline == null || completionHasOpened(job)) return null;

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final agreedInChat = job?['agreed_day'] != null;
  final due = '${months[deadline.month - 1]} ${deadline.day}';

  return agreedInChat
      ? 'Due $due, agreed in the chat.'
      : 'Due $due.';
}
