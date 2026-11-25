import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Why something is locked, and the way to unlock it, beside what is locked.
class TopUpStrip extends StatelessWidget {
  const TopUpStrip({super.key, required this.reason, required this.onTopUp});

  final String reason;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 16, color: AppColors.neutral600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(reason, style: const TextStyle(fontSize: 13, color: AppColors.neutral700)),
            ),
            TextButton(
              onPressed: onTopUp,
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text('Top Up'),
            ),
          ],
        ),
      );
}
