import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/employer_profile_provider.dart';
import '../../../providers/worker_profile_provider.dart';
import '../../help/screens/faq_screen.dart';
import '../../legal/screens/legal_screen.dart';
import '../widgets/change_password_sheet.dart';
import '../widgets/delete_account_sheet.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_version.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/kaya_popup.dart';
import '../../../data/services/api_client.dart';

/// Settings.
///
/// Everything here does something. The previous version had a Change Password
/// form that announced "Password updated" without sending anything, four
/// notification switches that were local widget state, a language picker with
/// no translations behind it, and two rows badged "Soon". All of it looked
/// functional and none of it was.
///
/// One card per group, the way phone settings read. Help and the legal pages
/// live here because Settings is where people look for them, and the version
/// is the real one, not a number typed into the profile tab once.
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
    'jobs': ('Job Updates', Icons.work_outline),
    'reviews': ('Reviews', Icons.star_outline),
    'account': ('Account and Verification', Icons.verified_user_outlined),
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
    final auth = context.watch<AuthProvider>();
    final hasBoth = auth.workerProfileExists && auth.employerProfileExists;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _group('Account', [
            _SettingsRow(
              icon: Icons.lock_reset_outlined,
              title: 'Change Password',
              subtitle: 'Signs out your other devices',
              onTap: () => showChangePasswordSheet(context),
            ),
            _SettingsRow(
              icon: Icons.shield_outlined,
              title: 'Account Status',
              subtitle: 'Violations, limits and review requests',
              onTap: () => AppRouter.push(context, AppRouter.accountStatus),
            ),
          ]),

          _group('Notifications', _notificationRows()),

          _group('Help & Support', [
            _SettingsRow(
              icon: Icons.help_outline,
              title: 'FAQs',
              onTap: () => showKayaPopup(context, tall: true, builder: (_) => const FAQScreen()),
            ),
            _SettingsRow(
              icon: Icons.support_agent_outlined,
              title: 'Message KAYA Support',
              onTap: () => AppRouter.push(context, AppRouter.support),
            ),
          ]),

          _group('About & Legal', [
            _SettingsRow(
              icon: Icons.description_outlined,
              title: 'Terms & Conditions',
              onTap: () => _openLegal(0),
            ),
            _SettingsRow(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () => _openLegal(1),
            ),
            _SettingsRow(
              icon: Icons.currency_exchange_outlined,
              title: 'Refund Policy',
              onTap: () => _openLegal(2),
            ),
            // Information, not a control: no chevron, nothing to tap.
            _SettingsRow(
              icon: Icons.info_outline,
              title: 'Version',
              trailing: Text(
                AppVersion.current,
                style: const TextStyle(fontSize: 13.5, color: AppColors.neutral500),
              ),
            ),
          ]),

          /*
              Leaving, in one row.

              An account holding both sides can drop either one and keep the
              rest, so the row opens the choices. With one side or none there
              is only one thing to do, and the row goes straight to it.
          */
          _group('', [
            _SettingsRow(
              icon: Icons.person_remove_outlined,
              title: hasBoth ? 'Delete Account or a Profile' : 'Delete Account',
              danger: true,
              onTap: hasBoth ? _openLeaving : () => showDeleteAccountSheet(context),
            ),
          ]),
        ],
      ),
    );
  }

  /// Opens the reader in a pop-up rather than a new screen. 0 is Terms,
  /// 1 is Privacy, 2 is Refunds.
  void _openLegal(int tab) => showKayaPopup(
        context,
        tall: true,
        builder: (_) => LegalScreen(initialTab: tab),
      );

  List<Widget> _notificationRows() {
    if (_prefsError != null && _prefs == null) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
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
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ];
    }

    return _categories.entries.map((entry) {
      final (title, icon) = entry.value;
      final value = _prefs![entry.key] ?? true;
      final onChanged = _savingPrefs ? null : (bool v) => _setPref(entry.key, v);

      return _SettingsRow(
        icon: icon,
        title: title,
        onTap: onChanged == null ? null : () => onChanged(!value),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
        ),
      );
    }).toList();
  }

  /// A heading and one white card holding [rows], divided by hairlines.
  Widget _group(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          // The white surface is a Material so the tap ripple shows on it
          // rather than behind it, clipped to the rounded corners.
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 52, color: AppColors.neutral100),
                  rows[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── leaving ─────────────────────────────────────────────────────────────────

  Future<void> _openLeaving() async {
    final choice = await showKayaPopup<String>(
      context,
      builder: (popupContext) => const _LeavingChoices(),
    );
    if (!mounted || choice == null) return;

    switch (choice) {
      case 'worker':
        await _removeProfile(worker: true);
      case 'employer':
        await _removeProfile(worker: false);
      case 'account':
        await showDeleteAccountSheet(context);
    }
  }

  /*
      Removes one side and leaves the account and the other side alone.

      Confirmed first and named plainly. What goes is what the profile holds;
      reviews belong to the account, so they stay. The server refuses to drop
      an employer profile while job posts are open, and says so.
  */
  Future<void> _removeProfile({required bool worker}) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(worker ? 'Remove Your Worker Profile?' : 'Remove Your Employer Profile?'),
        content: Text(
          worker
              ? 'Your skills, experience, certifications and licences are '
                  'removed. Your account, your employer profile and your '
                  'reviews stay. You can set a worker profile up again later.'
              : 'Your employer details are removed. Your account, your worker '
                  'profile, your past job posts and your reviews stay. Close '
                  'any open job posts first. You can set an employer profile '
                  'up again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (yes != true || !mounted) return;

    final String? error;
    if (worker) {
      final provider = context.read<WorkerProfileProvider>();
      error = await provider.deleteProfile() ? null : (provider.errorMessage ?? 'Could not remove it.');
    } else {
      final provider = context.read<EmployerProfileProvider>();
      error = await provider.deleteProfile() ? null : (provider.errorMessage ?? 'Could not remove it.');
    }

    if (!mounted) return;

    if (error != null) {
      AppToast.error(context, error);
      return;
    }

    // The flags decide what the whole app shows, so they are refetched before
    // anything renders against the old ones.
    await context.read<AuthProvider>().fetchMe();

    if (!mounted) return;

    AppToast.success(
      context,
      worker ? 'Your worker profile has been removed.' : 'Your employer profile has been removed.',
    );
  }
}

/// One row in a settings card. With no [onTap] it is information only and
/// draws no chevron.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tint = danger ? AppColors.error : AppColors.primary;

    return ListTile(
      minLeadingWidth: 20,
      leading: Icon(icon, size: 20, color: tint),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: danger ? AppColors.error : AppColors.neutral900,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.neutral500)),
      trailing: trailing ??
          (onTap == null ? null : const Icon(Icons.chevron_right, size: 20, color: AppColors.neutral400)),
      onTap: onTap,
    );
  }
}

/// What an account holding both sides can leave: either side, or everything.
class _LeavingChoices extends StatelessWidget {
  const _LeavingChoices();

  @override
  Widget build(BuildContext context) {
    Widget choice(String value, IconData icon, String title, String subtitle) => ListTile(
          leading: Icon(icon, size: 22, color: value == 'account' ? AppColors.error : AppColors.primary),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: value == 'account' ? AppColors.error : AppColors.neutral900,
            ),
          ),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.neutral500)),
          onTap: () => Navigator.pop(context, value),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Delete Account or a Profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.neutral900),
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Drop one side and keep the rest, or delete everything.',
              style: TextStyle(fontSize: 13.5, color: AppColors.neutral600),
            ),
          ),
          const SizedBox(height: 8),
          choice('worker', Icons.engineering_outlined, 'Remove Worker Profile',
              'Your account and employer profile stay'),
          choice('employer', Icons.storefront_outlined, 'Remove Employer Profile',
              'Your account and worker profile stay'),
          choice('account', Icons.delete_forever_outlined, 'Delete Account',
              'Everything, for good'),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}
