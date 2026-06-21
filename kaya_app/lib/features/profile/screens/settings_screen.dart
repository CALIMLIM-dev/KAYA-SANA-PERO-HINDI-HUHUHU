import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Settings Screen — Security + Language and other preferences
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage = 'English';
  bool _notifJobs = true;
  bool _notifApplications = true;
  bool _notifMessages = true;
  bool _notifInvitations = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Security ──────────────────────────────────────────────────────
          _sectionHeader('Security'),
          const SizedBox(height: 12),

          _menuItem(
            icon: Icons.lock_reset_outlined,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: () => _showChangePassword(context),
          ),
          _menuItem(
            icon: Icons.phone_android_outlined,
            title: 'Two-Factor Authentication',
            subtitle: 'Add an extra layer of security',
            trailing: _comingSoonBadge(),
            onTap: () => _snack(context, '2FA — coming soon'),
          ),
          _menuItem(
            icon: Icons.devices_outlined,
            title: 'Active Sessions',
            subtitle: 'See where you\'re logged in',
            trailing: _comingSoonBadge(),
            onTap: () => _snack(context, 'Active sessions — coming soon'),
          ),

          const SizedBox(height: 24),

          // ── Language ──────────────────────────────────────────────────────
          _sectionHeader('Language'),
          const SizedBox(height: 12),

          _languageOption('English'),
          _languageOption('Filipino'),

          const SizedBox(height: 24),

          // ── Notifications ─────────────────────────────────────────────────
          _sectionHeader('Notifications'),
          const SizedBox(height: 12),

          _switchItem(
            icon: Icons.work_outline,
            title: 'Job Recommendations',
            subtitle: 'New jobs matching your skills',
            value: _notifJobs,
            onChanged: (v) => setState(() => _notifJobs = v),
          ),
          _switchItem(
            icon: Icons.description_outlined,
            title: 'Application Updates',
            subtitle: 'Status changes on your applications',
            value: _notifApplications,
            onChanged: (v) => setState(() => _notifApplications = v),
          ),
          _switchItem(
            icon: Icons.chat_bubble_outline,
            title: 'Messages',
            subtitle: 'New messages from employers/workers',
            value: _notifMessages,
            onChanged: (v) => setState(() => _notifMessages = v),
          ),
          _switchItem(
            icon: Icons.mail_outline,
            title: 'Invitations',
            subtitle: 'Job invitations from employers',
            value: _notifInvitations,
            onChanged: (v) => setState(() => _notifInvitations = v),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── helpers ─────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.neutral500,
            letterSpacing: 0.5));
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral900)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                fontSize: 12, color: AppColors.neutral500)),
        trailing: trailing ??
            const Icon(Icons.chevron_right, color: AppColors.neutral400),
        onTap: onTap,
      ),
    );
  }

  Widget _languageOption(String language) {
    final isSelected = _selectedLanguage == language;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.4)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.neutral100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.language,
              color: isSelected ? AppColors.primary : AppColors.neutral400,
              size: 20),
        ),
        title: Text(language,
            style: TextStyle(
                fontSize: 14,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.neutral900)),
        trailing: isSelected
            ? const Icon(Icons.check_circle,
                color: AppColors.primary, size: 20)
            : null,
        onTap: () => setState(() => _selectedLanguage = language),
      ),
    );
  }

  Widget _switchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral900)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                fontSize: 12, color: AppColors.neutral500)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ),
    );
  }

  Widget _comingSoonBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.neutral200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text('Soon',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral500)),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showChangePassword(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Change Password',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral900)),
            const SizedBox(height: 20),
            _passField('Current Password'),
            const SizedBox(height: 12),
            _passField('New Password'),
            const SizedBox(height: 12),
            _passField('Confirm New Password'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _snack(context, 'Password updated');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Update Password',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passField(String label) {
    return TextField(
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        filled: true,
        fillColor: AppColors.neutral100,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.neutral300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
