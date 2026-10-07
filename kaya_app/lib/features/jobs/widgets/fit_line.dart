import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/*
    How a person fits, stated as a fact.

    Replaces the "72% match" pills. A percentage could not be checked and
    could disagree with the order a list was in; "You have 1 of 2 required
    skills" is something the reader can verify against the job, and it is
    what the ranking is built on. One widget so every card says it the same
    way.
*/
class FitLine extends StatelessWidget {
  const FitLine({super.key, required this.text, this.strong = false});

  final String text;

  /// The reader meets what was asked for: drawn in the primary colour.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final color = strong ? AppColors.primary : AppColors.neutral600;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(strong ? Icons.task_alt : Icons.checklist_rtl, size: 14, color: color),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
              color: color,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
