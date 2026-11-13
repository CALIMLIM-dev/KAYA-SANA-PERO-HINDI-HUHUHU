import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// A heading above a run of profile sections.
class ProfileSectionHeading extends StatelessWidget {
  const ProfileSectionHeading(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 2),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: AppColors.neutral500,
        ),
      ),
    );
  }
}
