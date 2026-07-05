import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// My Employer Profile - JobStreet-inspired layout
/// Toggle (Company / Individual) is visible directly on the profile tab
/// Each card SHOWS saved data; tap to edit on a full screen
class MyEmployerProfileScreen extends StatefulWidget {
  const MyEmployerProfileScreen({super.key});

  @override
  State<MyEmployerProfileScreen> createState() =>
      _MyEmployerProfileScreenState();
}

class _MyEmployerProfileScreenState extends State<MyEmployerProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Role toggle — null means not yet chosen
  String? _role; // 'Company' | 'Individual'

  // Profile data — all null until user fills them in
  String? _name;
  String? _description;
  String? _location;
  bool _hasPhoto = false;
  String _verificationStatus = 'unverified'; // verified | pending | unverified
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

  // ─── helpers ────────────────────────────────────────────────────────────────
  // ─── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
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
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(),
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
                  Tab(text: 'Profile'),
                  Tab(text: 'Verifications'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildProfileTab(),
            _buildVerificationsTab(),
          ],
        ),
      ),
    );
  }

  // ─── header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 44),

              // ── Avatar + info row ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile photo — tappable to upload
                  GestureDetector(
                    onTap: () {
                      // TODO: wire to image picker
                      setState(() => _hasPhoto = !_hasPhoto);
                    },
                    child: Stack(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: _hasPhoto
                              ? const Icon(Icons.business,
                                  color: Colors.white, size: 32)
                              : const Icon(Icons.camera_alt,
                                  color: Colors.white54, size: 24),
                        ),
                        if (!_hasPhoto)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 1.5),
                              ),
                              child: const Icon(Icons.add,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Role chip
                        if (_role != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _role == 'Company'
                                      ? Icons.business_center
                                      : Icons.person,
                                  size: 11,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Text(_role!,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white70)),
                              ],
                            ),
                          ),

                        // Name
                        Text(
                          _name ?? 'Your Name',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _name != null
                                ? Colors.white
                                : Colors.white30,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Location
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 13,
                                color: _location != null
                                    ? Colors.white70
                                    : Colors.white30),
                            const SizedBox(width: 3),
                            Text(
                              _location ?? 'Location not set',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _location != null
                                      ? Colors.white70
                                      : Colors.white30),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Description
              Text(
                _description != null
                    ? (_description!.length > 90
                        ? '${_description!.substring(0, 90)}...'
                        : _description!)
                    : 'No description yet',
                style: TextStyle(
                  fontSize: 13,
                  color: _description != null
                      ? Colors.white60
                      : Colors.white24,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 10),

              // Verification badge
              _buildVerificationBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationBadge() {
    if (_verificationStatus == 'verified') {
      return _badge(Icons.verified, 'Verified', AppColors.success);
    } else if (_verificationStatus == 'pending') {
      return _badge(Icons.hourglass_top, 'Verification Pending', AppColors.warning);
    }
    return _badge(Icons.info_outline, 'Not Verified', Colors.white38);
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  // ─── profile tab ────────────────────────────────────────────────────────────

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // ── ROLE TOGGLE ── visible directly on the screen, NOT inside a card
        const Text(
          'I am a...',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.neutral200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildToggleOption(
                  type: 'Company',
                  icon: Icons.business_center,
                  label: 'Company',
                  isSelected: _role == 'Company',
                  onTap: () => setState(() => _role = 'Company'),
                ),
              ),
              Expanded(
                child: _buildToggleOption(
                  type: 'Individual',
                  icon: Icons.person,
                  label: 'Individual',
                  isSelected: _role == 'Individual',
                  onTap: () => setState(() => _role = 'Individual'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── CARDS — only show after role is chosen ──
        if (_role == null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neutral300),
            ),
            child: const Center(
              child: Text(
                'Select your role above to continue setting up your profile',
                style: TextStyle(fontSize: 14, color: AppColors.neutral600),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else ...[
          // Name card — label changes based on role
          _buildInfoCard(
            title: _role == 'Company' ? 'Company Name' : 'Your Name',
            icon: _role == 'Company' ? Icons.business : Icons.person,
            iconColor: AppColors.primary,
            content: _name != null
                ? Text(_name!,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral900))
                : Text(
                    _role == 'Company'
                        ? 'Add your company name'
                        : 'Add your full name',
                    style: const TextStyle(color: AppColors.neutral600)),
            onTap: () async {
              final result = await Navigator.pushNamed(
                context,
                '/add-employer-details',
                arguments: _name,
              );
              if (result != null && result is String) {
                setState(() => _name = result);
              }
            },
          ),

          // Description card — label changes based on role
          _buildInfoCard(
            title: _role == 'Company' ? 'About the Company' : 'About You',
            icon: Icons.info_outline,
            iconColor: AppColors.accent,
            content: _description != null
                ? Text(_description!,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.neutral900),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis)
                : Text(
                    _role == 'Company'
                        ? 'Tell workers about your company'
                        : 'Tell workers about yourself',
                    style: const TextStyle(color: AppColors.neutral600)),
            onTap: () async {
              final result = await Navigator.pushNamed(
                context,
                '/add-employer-about',
              );
              if (result != null && result is String) {
                setState(() => _description = result);
              }
            },
          ),

          // Location
          _buildInfoCard(
            title: 'Location',
            icon: Icons.location_on,
            iconColor: AppColors.success,
            content: _location != null
                ? Row(children: [
                    const Icon(Icons.location_on,
                        size: 14, color: AppColors.neutral600),
                    const SizedBox(width: 6),
                    Text(_location!,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.neutral900)),
                  ])
                : const Text('Add your location',
                    style: TextStyle(color: AppColors.neutral600)),
            onTap: () async {
              final result = await Navigator.pushNamed(
                context,
                '/add-employer-location',
              );
              if (result != null && result is String) {
                setState(() => _location = result);
              }
            },
          ),
        ],
      ],
    );
  }

  // ─── verifications tab ───────────────────────────────────────────────────────

  Widget _buildVerificationsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Verifications',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.neutral900)),
        const SizedBox(height: 8),
        const Text('Verified profiles attract more quality workers',
            style: TextStyle(fontSize: 14, color: AppColors.neutral600)),
        const SizedBox(height: 20),

        // Company verifications
        if (_role == 'Company') ...[
          _buildVerificationCard(
            title: 'Business Registration',
            subtitle: 'Upload DTI, SEC, or Mayor\'s permit',
            icon: Icons.business_center,
            type: 'business_reg',
            isVerified: false,
          ),
          _buildVerificationCard(
            title: 'Phone Number',
            subtitle: 'Verify via SMS code',
            icon: Icons.phone,
            type: 'phone',
            isVerified: false,
          ),
          _buildVerificationCard(
            title: 'Email Address',
            subtitle: 'Verify via email link',
            icon: Icons.email,
            type: 'email',
            isVerified: false,
          ),
        ]

        // Individual verifications
        else if (_role == 'Individual') ...[
          _buildVerificationCard(
            title: 'Government ID',
            subtitle: 'Upload a valid government-issued ID',
            icon: Icons.badge,
            type: 'government_id',
            isVerified: false,
          ),
          _buildVerificationCard(
            title: 'Phone Number',
            subtitle: 'Verify via SMS code',
            icon: Icons.phone,
            type: 'phone',
            isVerified: false,
          ),
          _buildVerificationCard(
            title: 'Email Address',
            subtitle: 'Verify via email link',
            icon: Icons.email,
            type: 'email',
            isVerified: false,
          ),
        ]

        // No role chosen yet
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neutral300),
            ),
            child: const Center(
              child: Text(
                'Select your role in the Profile tab first',
                style: TextStyle(fontSize: 14, color: AppColors.neutral600),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // ─── reusable widgets ────────────────────────────────────────────────────────

  Widget _buildToggleOption({
    required String type,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : AppColors.neutral600,
                size: 18),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.neutral600,
              ),
            ),
          ],
        ),
      ),
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
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.neutral900)),
                      const SizedBox(height: 8),
                      content,
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String type,
    required bool isVerified,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        child: InkWell(
          onTap: isVerified ? null : () {
            Navigator.pushNamed(
              context,
              '/verification',
              arguments: {
                'type': type,
                'title': title,
                'subtitle': subtitle,
              },
            );
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
                        : AppColors.neutral200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isVerified ? Icons.check_circle : icon,
                    color:
                        isVerified ? AppColors.success : AppColors.neutral600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.neutral900)),
                      if (!isVerified)
                        Text(subtitle,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.neutral600)),
                    ],
                  ),
                ),
                if (isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Verified',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success)),
                  )
                else
                  const Icon(Icons.arrow_forward_ios,
                      size: 16, color: AppColors.neutral400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
