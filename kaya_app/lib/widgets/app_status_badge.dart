import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Status badge with color coding and text label
class AppStatusBadge extends StatelessWidget {
  final String label;
  final AppStatusType type;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: _getTextColor(),
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (type) {
      case AppStatusType.success:
        return AppTheme.successColor.withValues(alpha: 0.1);
      case AppStatusType.warning:
        return AppTheme.warningColor.withValues(alpha: 0.1);
      case AppStatusType.error:
        return AppTheme.errorColor.withValues(alpha: 0.1);
      case AppStatusType.info:
        return AppTheme.infoColor.withValues(alpha: 0.1);
      case AppStatusType.neutral:
        return AppTheme.borderColor;
    }
  }

  Color _getTextColor() {
    switch (type) {
      case AppStatusType.success:
        return AppTheme.successColor;
      case AppStatusType.warning:
        return AppTheme.warningColor;
      case AppStatusType.error:
        return AppTheme.errorColor;
      case AppStatusType.info:
        return AppTheme.infoColor;
      case AppStatusType.neutral:
        return AppTheme.textSecondary;
    }
  }
}

enum AppStatusType {
  success,
  warning,
  error,
  info,
  neutral,
}
