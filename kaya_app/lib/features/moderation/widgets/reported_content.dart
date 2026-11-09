import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../moderation_date.dart';

/// The person's own content a violation was about, as it was saved.
class ReportedContent extends StatelessWidget {
  const ReportedContent({super.key, required this.content});

  final Map<String, dynamic> content;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      for (final key in const ['title', 'name', 'company', 'location'])
        if ((content[key] ?? '').toString().isNotEmpty) content[key].toString(),
    ];
    final text = (content['text'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reported Content',
          style: TextStyle(fontSize: 12, color: AppColors.neutral500),
        ),
        const SizedBox(height: 4),
        for (final line in lines)
          Text(line, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.neutral800)),
        ],
        if (content['sent_at'] != null) ...[
          const SizedBox(height: 4),
          Text('Sent ${formatModerationDate(content['sent_at'], time: true)}',
              style: const TextStyle(fontSize: 12, color: AppColors.neutral600)),
        ],
      ],
    );
  }
}
