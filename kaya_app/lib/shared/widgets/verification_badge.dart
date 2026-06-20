import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Verification Badge Component
/// Small teal checkmark chip next to name, label "Verified"
class VerificationBadge extends StatelessWidget {
  final bool isVerified;
  final double size;

  const VerificationBadge({
    super.key,
    this.isVerified = true,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: AppColors.verified.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.verified.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified,
            color: AppColors.verified,
            size: size,
          ),
          const SizedBox(width: 4),
          Text(
            'Verified',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.verified,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
