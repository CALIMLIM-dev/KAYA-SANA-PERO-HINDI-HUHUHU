import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  /*
      The same plain dialog as every confirmation in the app.

      This was a hand-built card: a tinted header block, a 64px icon in a
      circle, the reason in its own bordered box, then "you have been logged
      out", then "contact support", then a full-width button - five things
      saying one thing, in a frame nothing else in the app uses. A title, the
      reason, and one button say it in the shape every other dialog has.
  */
  static Widget _buildDialog({
    required BuildContext context,
    required String reason,
    required bool showLogoutButton,
    required VoidCallback onClose,
  }) {
    return AlertDialog(
      title: const Text('Account suspended'),
      content: Text(reason),
      actions: [
        TextButton(
          onPressed: onClose,
          child: Text(showLogoutButton ? 'Sign out' : 'OK'),
        ),
      ],
    );
  }
}
