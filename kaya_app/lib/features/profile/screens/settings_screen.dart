import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/services/api_client.dart';

/// Settings.
///
/// Everything here does something. The previous version had a Change Password
/// form that announced "Password updated" without sending anything, four
/// notification switches that were local widget state, a language picker with
/// no translations behind it, and two rows badged "Soon". All of it looked
/// functional and none of it was.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiClient _api = ApiClient();

  /// Mirrors the server. Null until loaded, so the switches are not rendered
  /// in a guessed position that then jumps when the real values arrive.
  Map<String, bool>? _prefs;
  String? _prefsError;
  bool _savingPrefs = false;

  /// Label and icon only.
  ///
  /// Each of these carried an explanatory sentence — "Messages / New messages
  /// in your conversations" — which is the title again in more words. Under a
  /// heading that already says Notifications, the label is enough.
  static const _categories = <String, (String, IconData)>{
    'applications': ('Applications', Icons.description_outlined),
    'invitations': ('Invitations', Icons.mail_outline),
    'messages': ('Messages', Icons.chat_bubble_outline),
    'jobs': ('Job updates', Icons.work_outline),
    'reviews': ('Reviews', Icons.star_outline),
    'account': ('Account and verification', Icons.verified_user_outlined),
  };

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final res = await _api.get('/me/notification-preferences');
      final map = (res.data['data']['preferences'] as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        _prefs = map.map((k, v) => MapEntry(k, v == true));
        _prefsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _prefsError = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _setPref(String key, bool value) async {
    final previous = Map<String, bool>.from(_prefs!);

    // Optimistic: a switch that waits for a round trip before moving feels
    // broken. Reverted below if the save fails.
    setState(() {
      _prefs![key] = value;
      _savingPrefs = true;
    });

    try {
      await _api.put('/me/notification-preferences', data: _prefs);
      if (mounted) setState(() => _savingPrefs = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _prefs = previous;
        _savingPrefs = false;
      });
      AppToast.info(context, 'Could not save that. Check your connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Account'),
          const SizedBox(height: 10),
          _menuItem(
            icon: Icons.lock_reset_outlined,
            title: 'Change password',
            subtitle: 'Signs out your other devices',
            onTap: _openChangePassword,
          ),

          const SizedBox(height: 24),
          _sectionHeader('Notifications'),
          const SizedBox(height: 10),
          ..._buildNotificationSection(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Widget> _buildNotificationSection() {
    if (_prefsError != null && _prefs == null) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _prefsError!,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.neutral600),
                ),
              ),
              TextButton(onPressed: _loadPrefs, child: const Text('Retry')),
            ],
          ),
        ),
      ];
    }

    if (_prefs == null) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ];
    }

    return _categories.entries.map((entry) {
      final (title, icon) = entry.value;
      return _switchItem(
        icon: icon,
        title: title,
        value: _prefs![entry.key] ?? true,
        onChanged: _savingPrefs ? null : (v) => _setPref(entry.key, v),
      );
    }).toList();
  }

  // ─── pieces ──────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.neutral500,
          letterSpacing: 0.5,
        ),
      );

  Widget _menuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: _iconBox(icon),
        title: Text(title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.neutral500)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.neutral400),
        onTap: onTap,
      ),
    );
  }

  Widget _switchItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: _iconBox(icon),
        title: Text(title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      );

  // ─── change password ─────────────────────────────────────────────────────────

  void _openChangePassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ChangePasswordSheet(),
    );
  }
}

/// The password form, with its own state so its controllers are disposed when
/// the sheet closes rather than living as long as the settings screen.
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final ApiClient _api = ApiClient();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final res = await _api.put('/me/password', data: {
        'current_password': _current.text,
        'password': _next.text,
        'password_confirmation': _confirm.text,
      });

      // The server invalidates every other token and issues a fresh one, so
      // this device has to store it or the next request is a 401.
      final token = res.data['data']?['token'] as String?;
      if (token != null) await ApiClient.saveToken(token);

      if (!mounted) return;
      Navigator.pop(context);
      AppToast.success(context, 'Password updated. Other devices were signed out.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Change password',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral900)),
            const SizedBox(height: 16),
            _field(
              controller: _current,
              label: 'Current password',
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your current password' : null,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _next,
              label: 'New password',
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter a new password';
                if (v.length < 8) return 'Use at least 8 characters';
                if (v == _current.text) return 'Choose a different password';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _field(
              controller: _confirm,
              label: 'Confirm new password',
              validator: (v) => v != _next.text ? 'Passwords do not match' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.neutral300,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text('Update password',
                        style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        filled: true,
        fillColor: AppColors.neutral100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.neutral300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
