import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// My Worker Profile - JobStreet-inspired card layout
/// Shows filled data in cards, NOT empty clickable placeholders
class MyWorkerProfileScreen extends StatefulWidget {
  const MyWorkerProfileScreen({super.key});

  @override
  State<MyWorkerProfileScreen> createState() => _MyWorkerProfileScreenState();
}

class _MyWorkerProfileScreenState extends State<MyWorkerProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // TODO: Load from Provider/storage
  String? _userName;
  String? _userLocation;
  String? _userPhone;
  String? _userEmail;
  List<String> _skills = [];
  List<Map<String, String>> _experiences = [];
  List<Map<String, dynamic>> _certifications = [];
  List<Map<String, dynamic>> _licenses = [];
  bool _hasPhoto = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 280,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () {},
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 56),
                          Row(
                            children: [
                              // Profile Photo
                              Container(
                                width: 75,
                                height: 75,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                                child: _hasPhoto
                                    ? const Icon(Icons.check_circle, color: Colors.white, size: 28)
                                    : const Icon(Icons.camera_alt, color: Colors.white70, size: 24),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.more_vert, color: Colors.white),
                                onPressed: () {},
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _userName ?? 'Add your name',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _userName != null ? Colors.white : Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _userLocation ?? 'Add your location',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.visibility, size: 13, color: Colors.white),
                                SizedBox(width: 5),
                                Text(
                                  'Set your profile visibility',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.neutral600,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Suggested for you'),
                    Tab(text: 'Verifications'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildSuggestedTab(),
            _buildVerificationsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Suggested for you',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.neutral900,
          ),
        ),
        const SizedBox(height: 16),
        
        // Personal Details Card - SHOWS DATA
        _buildInfoCard(
          title: 'Personal Details',
          icon: Icons.contact_page,
          iconColor: AppColors.primary,
          content: _userPhone != null || _userEmail != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_userPhone != null)
                      Text('Phone: $_userPhone', style: const TextStyle(fontSize: 14)),
                    if (_userEmail != null)
                      Text('Email: $_userEmail', style: const TextStyle(fontSize: 14)),
                  ],
                )
              : const Text('Add your contact details', style: TextStyle(color: AppColors.neutral600)),
          onTap: () {
            Navigator.pushNamed(context, '/add-personal-details');
          },
        ),
        
        // Skills Card - SHOWS DATA
        _buildInfoCard(
          title: 'Skills',
          icon: Icons.build_circle,
          iconColor: AppColors.accent,
          content: _skills.isNotEmpty
              ? Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _skills.map((skill) => Chip(
                    label: Text(skill, style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )).toList(),
                )
              : const Text('Add your skills', style: TextStyle(color: AppColors.neutral600)),
          onTap: () {
            Navigator.pushNamed(context, '/add-skills');
          },
        ),
        
        // Experience Card - SHOWS DATA
        _buildInfoCard(
          title: 'Experience',
          icon: Icons.work,
          iconColor: AppColors.success,
          content: _experiences.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _experiences.map((exp) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exp['position'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text('${exp['company']} • ${exp['duration']}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  )).toList(),
                )
              : const Text('Add your experience', style: TextStyle(color: AppColors.neutral600)),
          onTap: () {
            Navigator.pushNamed(context, '/add-experience');
          },
        ),
        
        // Certifications Card - SHOWS DATA
        _buildInfoCard(
          title: 'Certifications',
          icon: Icons.workspace_premium,
          iconColor: Colors.orange,
          content: _certifications.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _certifications.map((cert) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.verified, size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${cert['title']} - ${cert['issuer']}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                )
              : const Text('Add certifications', style: TextStyle(color: AppColors.neutral600)),
          onTap: () {
            Navigator.pushNamed(context, '/add-certifications');
          },
        ),
        
        // Licenses Card - SHOWS DATA
        _buildInfoCard(
          title: 'Licenses',
          icon: Icons.badge,
          iconColor: Colors.purple,
          content: _licenses.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _licenses.map((license) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.badge, size: 16, color: Colors.purple),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${license['title']} - ${license['issuer']}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                )
              : const Text('Add licenses', style: TextStyle(color: AppColors.neutral600)),
          onTap: () {
            Navigator.pushNamed(context, '/add-licenses');
          },
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget content,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neutral900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      content,
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Verifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.neutral900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Profiles with verifications are more likely to be selected',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.neutral600,
          ),
        ),
        const SizedBox(height: 20),
        
        _buildVerificationCard(
          title: 'Government ID',
          subtitle: 'Upload valid government-issued ID',
          icon: Icons.badge,
          isVerified: false,
        ),
        _buildVerificationCard(
          title: 'Phone number',
          subtitle: 'Verify via SMS code',
          icon: Icons.phone,
          isVerified: false,
        ),
        _buildVerificationCard(
          title: 'Email',
          subtitle: 'Verify via email link',
          icon: Icons.email,
          isVerified: false,
        ),
      ],
    );
  }

  Widget _buildVerificationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isVerified,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        child: InkWell(
          onTap: () {
            // TODO: Trigger verification
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isVerified
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.neutral100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isVerified ? Icons.check_circle : icon,
                    color: isVerified ? AppColors.success : AppColors.neutral600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900,
                        ),
                      ),
                      if (!isVerified)
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.neutral600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Verified',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.neutral400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) => false;
}
