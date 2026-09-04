import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/profile_view_provider.dart';
import '../../../core/constants/credits.dart';
import '../../../core/navigation/app_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/credits_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/invitation_provider.dart';
import '../../../providers/messaging_provider.dart';
import '../../../providers/worker_profile_provider.dart';
import '../../../providers/employer_profile_provider.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../legal/screens/legal_screen.dart';

/// Profile / Account Screen
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Everything shown here now comes from the signed-in account.
    //
    // This screen previously declared eight hardcoded values — name 'Eddison',
    // 'Professional Plumber', '5 years experience', an email and a phone
    // number — so every user who opened their own profile saw one developer's
    // details. The trade, years of experience and location were dropped rather
    // than wired: they belong to the worker profile, they are already shown on
    // it, and repeating them here only creates a second place to go stale.
    final String userName = (auth.user?['name'] as String?)?.trim().isNotEmpty == true
        ? auth.user!['name'] as String
        : 'Your account';
    final String email = (auth.user?['email'] as String?) ?? '';
    final bool isVerified = auth.user?['is_verified'] == true;

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            backgroundColor: AppColors.primary,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: const Text('My Profile',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),

          // ── Profile header ──
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.primary,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                    color: Colors.white, width: 4),
                              ),
                              // Was a hardcoded person icon, so the
                              // account picture never appeared on the one
                              // screen called "My Profile".
                              child: ProfileAvatar(
                                imageUrl: auth.user?['avatar'] as String?,
                                name: userName,
                                radius: 46,
                                background: AppColors.primaryLight,
                                foreground: Colors.white,
                              ),
                            ),
                            if (isVerified)
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.verified,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(userName,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        // Trade, years of experience and location used to sit
                        // here as fixed strings. They belong to the worker
                        // profile, which already shows them — duplicating them
                        // on this screen only created a second place to drift.
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.9)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    height: 30,
                    decoration: const BoxDecoration(
                      color: AppColors.neutral50,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // A "Contact Information" card sat here showing a fixed email, phone
          // number and location — the same three values for every account.
          // Removed rather than wired up: the email is already in the header,
          // and phone and location are edited on the worker profile, so a
          // read-only copy here would just be another thing to keep in step.
          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ── Account ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _SectionHeader(title: 'Account'),
                  const SizedBox(height: 12),
                  // Both sides are always listed, whether or not the account
                  // has them. That is the hybrid model made visible: an
                  // account is not "a worker" or "an employer", it simply has
                  // or hasn't set each side up, and either can be added at any
                  // time. Hiding the missing one would leave a user with no
                  // way to discover they could hire as well as work.
                  //
                  // Neither branches on existence here — the routers decide.
                  _MenuItem(
                    icon: Icons.person_outline,
                    title: 'Worker Profile',
                    // Only when there is something to prompt. "Edit your
                    // skills, experience and rate" under "Worker Profile" was
                    // saying the same thing twice.
                    subtitle: auth.workerProfileExists
                        ? null
                        : 'Set this up to apply for jobs',
                    trailing: auth.workerProfileExists
                        ? null
                        : const _AddChip(),
                    onTap: () =>
                        Navigator.pushNamed(context, '/my-worker-profile'),
                  ),
                  _MenuItem(
                    icon: Icons.business_outlined,
                    title: 'Employer Profile',
                    subtitle: auth.employerProfileExists
                        ? null
                        : 'Set this up to post jobs and hire',
                    trailing: auth.employerProfileExists
                        ? null
                        : const _AddChip(),
                    onTap: () =>
                        Navigator.pushNamed(context, '/my-employer-profile'),
                  ),

                  const SizedBox(height: 24),

                  // ── Wallet ──
                  _SectionHeader(title: 'Wallet'),
                  /*
                      The balance is shown on the row itself rather than made
                      you tap to find out. It is the number people check most
                      often and the one they are most likely to dispute, so
                      hiding it a screen deeper buys nothing.
                  */
                  Consumer<CreditsProvider>(
                    builder: (context, credits, _) => _MenuItem(
                      icon: Credits.walletIcon,
                      title: 'My Wallet',
                      subtitle: credits.hasLoadedOnce
                          ? '${credits.balance} ${Credits.plural}'
                          : null,
                      onTap: () => Navigator.pushNamed(context, AppRouter.wallet),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Jobs ──
                  _SectionHeader(title: 'Jobs'),
                  const SizedBox(height: 12),
                  _MenuItem(
                    icon: Icons.bookmark_outline,
                    title: 'Saved Jobs',
                    onTap: () =>
                        Navigator.pushNamed(context, '/saved-jobs'),
                  ),
                  // Gated on the real profile flag. This used to read
                  // `userRole == 'Employer'` against a variable hardcoded to
                  // 'Worker', so the condition was never true and My Job Posts
                  // was invisible to everyone, employers included.
                  if (auth.employerProfileExists)
                    _MenuItem(
                      icon: Icons.business_center_outlined,
                      title: 'My Job Posts',
                      onTap: () =>
                          Navigator.pushNamed(context, '/manage-jobs'),
                    ),

                  const SizedBox(height: 24),

                  // ── Settings ──
                  _SectionHeader(title: 'Settings'),
                  const SizedBox(height: 12),
                  _MenuItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () =>
                        Navigator.pushNamed(context, '/settings'),
                  ),

                  const SizedBox(height: 24),

                  // ── Support ──
                  _SectionHeader(title: 'Support'),
                  const SizedBox(height: 12),
                  _MenuItem(
                    icon: Icons.help_outline,
                    title: 'Help Center',
                    onTap: () => Navigator.pushNamed(context, '/faq'),
                  ),
                  // "About" was a row with an empty onTap — it looked tappable
                  // and did nothing, which reads as a broken app rather than a
                  // missing screen. The only thing it carried was the version,
                  // so that is shown plainly at the bottom instead.
                  _MenuItem(
                    icon: Icons.description_outlined,
                    title: 'Terms & Privacy',
                    // Opens the reader, not the sign-up consent sheet. The sheet
                    // gates its button on scrolling both documents to the end,
                    // which is right when taking consent and absurd when
                    // somebody wants to check one clause.
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LegalScreen()),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Logout ──
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showLogoutDialog(context),
                      icon: const Icon(Icons.logout, color: AppColors.error),
                      label: const Text('Logout',
                          style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'KAYA version 1.0.0',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.neutral400),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── dialogs / sheets ─────────────────────────────────────────────────────────

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              
              // Perform logout
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final appMode =
                  Provider.of<AppModeProvider>(context, listen: false);
              final notifications =
                  Provider.of<NotificationProvider>(context, listen: false);
              final profileViews =
                  Provider.of<ProfileViewProvider>(context, listen: false);
              final credits =
                  Provider.of<CreditsProvider>(context, listen: false);
              // Resolved before the await, like the ones above: the context
              // may be gone by the time logout returns.
              final jobs = Provider.of<JobProvider>(context, listen: false);
              final applications =
                  Provider.of<ApplicationProvider>(context, listen: false);
              final invitations =
                  Provider.of<InvitationProvider>(context, listen: false);
              final messaging =
                  Provider.of<MessagingProvider>(context, listen: false);
              final workerProfile =
                  Provider.of<WorkerProfileProvider>(context, listen: false);
              final employerProfile =
                  Provider.of<EmployerProfileProvider>(context, listen: false);
              await auth.logout();
              // Drop the persisted Worker/Employer mode so the next account to
              // sign in on this device does not inherit it.
              await appMode.clear();
              // Same reason: a stale badge count and someone else's inbox must
              // not survive into the next session.
              notifications.clear();
              // And the previous account's view count, which would otherwise
              // greet the next person as if it were theirs.
              profileViews.clear();
              /*
                  And their balance, which was the worst of these.

                  CreditsProvider has a clear() and nothing ever called it, so
                  the next account to sign in on this phone inherited the last
                  one's number. Worse than a stale badge: load() returns early
                  once it has loaded, so the wrong balance never corrected
                  itself on the home screen - it sat there until something else
                  forced a refresh, showing one account somebody else's money.
              */
              credits.clear();

              /*
                  And everything else that belongs to one account.

                  The balance was found and fixed on its own; the same hole was
                  open in six more providers, none of which had a clear() at
                  all. Signing out and back in on one phone left the next
                  person holding the previous account's posted jobs, their
                  applications and applicant lists, their invitations, their
                  conversations and their profile - and, once the rehire list
                  existed, the names and photos of everyone they had hired.

                  Reference data is not touched: categories and the skill
                  catalog are the same for every account.
              */
              jobs.clear();
              applications.clear();
              invitations.clear();
              messaging.clear();
              workerProfile.clear();
              employerProfile.clear();

              // Navigate to login screen and clear navigation stack
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── reusable section widgets ─────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold, color: AppColors.neutral700)),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;

  /// Optional, and usually absent.
  ///
  /// Every row used to carry one, so the screen read as a manual — "Saved
  /// Jobs / View your saved job postings" says the same thing twice and gives
  /// the eye nothing to rank. A subtitle is kept only where it tells you
  /// something the title cannot, which in practice means prompting a profile
  /// side that has not been set up yet. Those rows then stand out, which is
  /// the point.
  final String? subtitle;
  final VoidCallback onTap;

  /// Replaces the chevron when a row needs to say more than "opens something" —
  /// used to mark a profile side the account hasn't set up yet.
  final Widget? trailing;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    // The white surface is the Material itself, so the tap ripple lands on the
    // row rather than being hidden behind it. Same reason as the settings rows.
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          title: Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          subtitle: subtitle == null
              ? null
              : Text(subtitle!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.neutral600)),
          trailing: trailing ??
              const Icon(Icons.chevron_right, color: AppColors.neutral400),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Marks a profile side the account hasn't created yet.
///
/// A row that reads identically whether or not you have the thing gives the
/// user no way to tell "edit" from "create" until they've tapped it.
class _AddChip extends StatelessWidget {
  const _AddChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 14, color: AppColors.primary),
          SizedBox(width: 3),
          Text('Add',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ],
      ),
    );
  }
}
