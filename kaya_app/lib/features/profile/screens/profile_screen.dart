import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';

/// Profile / Account Screen
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final String userName = 'Eddison';
    final String userRole = 'Worker';
    final String primarySkill = 'Professional Plumber';
    final String location = 'Urdaneta City, Pangasinan';
    final String email = 'eddison@email.com';
    final String phone = '+63 912 345 6789';
    final bool isVerified = DateTime.now().millisecondsSinceEpoch < 0;
    final int yearsExperience = 5;

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
                              child: const CircleAvatar(
                                backgroundColor: AppColors.primaryLight,
                                child: Icon(Icons.person,
                                    size: 50, color: Colors.white),
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
                        const SizedBox(height: 4),
                        Text(
                          userRole == 'Worker' ? primarySkill : 'Employer',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.9)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(location,
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14)),
                          ],
                        ),
                        if (userRole == 'Worker') ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color:
                                  Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.work,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text('$yearsExperience years experience',
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.9),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
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

          // ── Contact Info ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Contact Information'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: email),
                        const Divider(height: 24),
                        _InfoRow(
                            icon: Icons.phone_outlined,
                            label: 'Phone',
                            value: phone),
                        const Divider(height: 24),
                        _InfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'Location',
                            value: location),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Account ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _SectionHeader(title: 'Account'),
                  const SizedBox(height: 12),
                  _MenuItem(
                    icon: Icons.person_outline,
                    title: 'My Worker Profile',
                    subtitle: 'Manage your skills and availability',
                    onTap: () =>
                        Navigator.pushNamed(context, '/my-worker-profile'),
                  ),
                  _MenuItem(
                    icon: Icons.business_outlined,
                    title: 'Employer Profile',
                    subtitle: auth.employerProfileExists
                        ? 'Edit your employer profile'
                        : 'Set up your employer profile',
                    onTap: () => Navigator.pushNamed(
                      context,
                      auth.employerProfileExists
                          ? '/my-employer-profile'
                          : '/setup-employer-profile',
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Jobs ──
                  _SectionHeader(title: 'Jobs'),
                  const SizedBox(height: 12),
                  _MenuItem(
                    icon: Icons.bookmark_outline,
                    title: 'Saved Jobs',
                    subtitle: 'View your saved job postings',
                    onTap: () =>
                        Navigator.pushNamed(context, '/saved-jobs'),
                  ),
                  if (userRole == 'Employer')
                    _MenuItem(
                      icon: Icons.business_center_outlined,
                      title: 'My Job Posts',
                      subtitle: 'Manage jobs you posted',
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
                    subtitle: 'Security, language, notifications',
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
                    subtitle: 'FAQs and support',
                    onTap: () => Navigator.pushNamed(context, '/faq'),
                  ),
                  _MenuItem(
                    icon: Icons.info_outline,
                    title: 'About',
                    subtitle: 'Version 1.0.0',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.description_outlined,
                    title: 'Terms & Privacy',
                    subtitle: 'Read our policies',
                    onTap: () {},
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
              await auth.logout();
              
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.neutral600,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.neutral900,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
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
        subtitle: Text(subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.neutral600)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.neutral400),
        onTap: onTap,
      ),
    );
  }
}
