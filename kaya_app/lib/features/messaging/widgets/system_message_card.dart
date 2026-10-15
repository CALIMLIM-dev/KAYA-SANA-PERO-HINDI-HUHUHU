import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/services/api_client.dart';
import '../../../providers/application_provider.dart';
import '../../applications/widgets/completion_action.dart';

/*
    A system row in the chat: the job's history, the way a shop's chat
    carries the order's history.

    Centred, not a bubble, because nobody said it. A job icon and a line
    for what happened, and the job's title underneath, tapped to open it.
    The colour says which kind of event: hired is blue, one side confirmed
    is amber, both confirmed is green.
*/
class SystemMessageCard extends StatelessWidget {
  final Map<String, dynamic> message;

  /// The hire this chat is about, so "Marked done" can be answered here.
  final int? applicationId;

  const SystemMessageCard({super.key, required this.message, this.applicationId});

  /*
      "Marked done", answered where it is read.

      The row opened the job post, which says nothing about finishing it -
      so somebody told "Ana marked the job as done" had to go and find the
      card with the button on it. Now the row asks the server where things
      stand and, when the other side marked it and this side has not, offers
      the confirmation right here. Otherwise it says where things stand.
  */
  Future<void> _answerMarkedDone(BuildContext context, int applicationId) async {
    final Map<String, dynamic> state;
    try {
      final res = await ApiClient().get('/applications/$applicationId/completion');
      state = (res.data['data'] as Map).cast<String, dynamic>();
    } catch (e) {
      if (context.mounted) AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    if (!context.mounted) return;

    if (state['complete'] == true) {
      AppToast.info(context, 'This job is complete.');
      return;
    }
    if (const {'closed', 'expired'}.contains(state['job_status'])) {
      AppToast.info(context, 'This job was closed, so it can no longer be marked complete.');
      return;
    }
    if (state['you_confirmed'] == true) {
      AppToast.info(context, 'You marked it done. Waiting for the other side to confirm.');
      return;
    }

    final who = ((message['sender'] as Map?)?['name'] ?? 'They').toString();
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm the Job Is Complete?'),
        content: Text('$who marked it done. Confirming finishes the job, and you can both leave a review.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Not Yet')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;

    final provider = context.read<ApplicationProvider>();
    final ok = await provider.markComplete(applicationId);
    if (!context.mounted) return;

    if (!ok) {
      AppToast.error(context, provider.errorMessage ?? 'Could not confirm.');
      return;
    }
    AppToast.success(context, provider.lastCompletionMessage ?? 'Confirmed.');
    await refreshActivity(context);
  }

  @override
  Widget build(BuildContext context) {
    final payload = message['payload'];
    final p = payload is Map ? Map<String, dynamic>.from(payload) : const <String, dynamic>{};
    final event = '${p['event'] ?? ''}';
    final jobId = p['job_id'] as int?;
    final title = p['job_title'] as String?;

    final (icon, color, label) = switch (event) {
      'hired' => (Icons.handshake_outlined, AppColors.primary, 'Hired'),
      'confirmed' => (Icons.hourglass_top, AppColors.warning, 'Marked as Complete'),
      'completed' => (Icons.check_circle_outline, AppColors.success, 'Job Completed'),
      'ended' => (Icons.block, AppColors.neutral600, 'Job Ended'),
      _ => (Icons.info_outline, AppColors.neutral600, 'Update'),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: event == 'confirmed' && applicationId != null
                ? () => _answerMarkedDone(context, applicationId!)
                : jobId == null
                    ? null
                    : () => AppRouter.push(context, '/job-details', arguments: {'jobId': jobId}),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.2),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${message['message_text'] ?? ''}',
                          style: const TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.neutral800),
                        ),
                        if (title != null && title.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            title,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutral600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
