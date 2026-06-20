import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Verified badge that appears beside names
class AppVerifiedBadge extends StatelessWidget {
  final double size;

  const AppVerifiedBadge({
    super.key,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppTheme.successColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check,
        color: Colors.white,
        size: size * 0.65,
      ),
    );
  }
}
