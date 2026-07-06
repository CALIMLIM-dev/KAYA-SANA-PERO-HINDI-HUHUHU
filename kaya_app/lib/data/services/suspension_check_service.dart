import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/suspension_dialog.dart';

/// Suspension Check Service
/// Periodically checks if user account has been suspended
/// Shows dialog and logs out if suspended
class SuspensionCheckService {
  static Timer? _timer;
  static bool _isChecking = false;

  /// Start periodic suspension checks (every 30 seconds)
  static void startPeriodicCheck(BuildContext context) {
    // Cancel existing timer if any
    _timer?.cancel();

    // Check immediately
    _checkSuspensionStatus(context);

    // Then check every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkSuspensionStatus(context);
    });
  }

  /// Stop periodic checks
  static void stopPeriodicCheck() {
    _timer?.cancel();
    _timer = null;
  }

  /// Check suspension status once
  static Future<void> _checkSuspensionStatus(BuildContext context) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.checkSuspensionStatus();

      if (result == null) {
        _isChecking = false;
        return;
      }

      if (result['is_suspended'] == true) {
        // Account is suspended - show dialog and logout
        stopPeriodicCheck();
        _isChecking = false;

        if (context.mounted) {
          SuspensionDialog.showAndLogout(
            context,
            result['suspended_reason'] ?? 'Your account has been suspended.',
          );
        }
        return;
      }

      _isChecking = false;
    } catch (e) {
      _isChecking = false;
    }
  }
}
