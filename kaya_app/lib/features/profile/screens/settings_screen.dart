import 'package:flutter/material.dart';
import '../widgets/change_password_sheet.dart';

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

    /*
        Material, not a decorated box.

        A ListTile paints its tap ripple onto the nearest Material above it, so
        a plain Container with a white background sits in between and hides the
        splash completely: the row still works, it just gives no sign that it
        was pressed. Flutter says so out loud in a debug assertion, which is how
        this was found — every settings row in the app was a dead-feeling tap.

        Making the white surface itself a Material puts the ink back on the
        thing the finger is touching, and clipping it to the same radius keeps
        the splash inside the rounded corners instead of squaring them off.
    */
  Widget _menuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
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
      ),
    );
  }

  Widget _switchItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
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

  void _openChangePassword() => showChangePasswordSheet(context);
}
