import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/app_mode_provider.dart';
import '../../providers/auth_provider.dart';

/// Reusable Suspension Dialog
/// Shows when account is suspended - used in login and while app is running
class SuspensionDialog {
  /// Show suspension dialog (for login - ALWAYS shows generic message)
  static void showOnLogin(BuildContext context, String reason) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _buildDialog(
        context: context,
        reason: 'Your account has been suspended.', // ALWAYS generic, never show admin reason
        showLogoutButton: false,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  /// Show suspension dialog and force logout (for active sessions - shows actual reason)
  static void showAndLogout(BuildContext context, String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: _buildDialog(
          context: context,
          reason: reason, // Show actual reason from admin
          showLogoutButton: true,
          onClose: () async {
            // Resolve both providers before the first await — reading them off
            // `context` afterwards crosses an async gap.
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final appMode = Provider.of<AppModeProvider>(context, listen: false);
            await authProvider.logout();
            // Keep mode state in step with the cleared session.
            await appMode.clear();

            if (context.mounted) {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            }
          },
        ),
      ),
    );
  }

  static Widget _buildDialog({
    required BuildContext context,
    required String reason,
    required bool showLogoutButton,
    required VoidCallback onClose,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Red header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.block, size: 32, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Account Suspended',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      reason,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (showLogoutButton) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'You have been logged out.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.neutral600,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'If you believe this is a mistake, please contact support.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.neutral500,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Actions
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(showLogoutButton ? 'Logout' : 'Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
