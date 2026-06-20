import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Verification Badge Widget
class VerificationBadgeWidget extends StatelessWidget {
  final bool isVerified;
  final double size;

  const VerificationBadgeWidget({
    super.key,
    required this.isVerified,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.verified.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified,
            size: size,
            color: AppColors.verified,
          ),
          const SizedBox(width: 4),
          Text(
            'Verified',
            style: TextStyle(
              fontSize: size * 0.75,
              color: AppColors.verified,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
