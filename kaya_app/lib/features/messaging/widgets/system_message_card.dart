import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';

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

  const SystemMessageCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final payload = message['payload'];
    final p = payload is Map ? Map<String, dynamic>.from(payload) : const <String, dynamic>{};
    final event = '${p['event'] ?? ''}';
    final jobId = p['job_id'] as int?;
    final title = p['job_title'] as String?;

    final (icon, color, label) = switch (event) {
      'hired' => (Icons.handshake_outlined, AppColors.primary, 'Hired'),
      'confirmed' => (Icons.hourglass_top, AppColors.warning, 'Marked done'),
      'completed' => (Icons.check_circle_outline, AppColors.success, 'Job complete'),
      'ended' => (Icons.block, AppColors.neutral600, 'Job ended'),
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
            onTap: jobId == null
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
