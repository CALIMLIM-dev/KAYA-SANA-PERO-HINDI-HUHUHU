import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/employer_profile_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/employer_profile_provider.dart';
import '../../../providers/verification_provider.dart';
import '../widgets/inline_edit_row.dart';
import '../widgets/inline_location_row.dart';

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

  /// 'Company' | 'Individual', read from the server — never local state.
  ///
  /// This used to be a mutable field driven by an on-screen toggle, so the
  /// whole page could render as a company while the account was an individual.
  /// The type is decided once during setup and fixed afterwards, so the only
  /// correct source is the stored profile.
  String? get _role =>
      context.watch<EmployerProfileProvider>().profile?.employerType.label;

  /*
      Read from the stored profile, not from local fields.

      These were plain variables initialised to null and never populated from
      anywhere. An employer with a fully filled-in profile opened this screen
      and saw "Add your company name", "Location not set" and "Your Name" —
      their real details were on the server the whole time and simply never
      read. `_role` above was the only thing that looked at the provider.
  */
  EmployerProfile? get _profile =>
      context.watch<EmployerProfileProvider>().profile;

  /*
      An individual employer has no company name.

      This read company_name and nothing else, so anybody hiring as a person
      rather than as a business saw an empty name on their own profile — the
      field is genuinely null for them, and their identity is the name on
      their account.

      Which is also how the server decides an individual's setup is complete:
      it checks the user's name, not the company field.
  */
  String? get _name {
    final company = _profile?.companyName;
    if (company != null && company.trim().isNotEmpty) return company;

    final accountName = context.read<AuthProvider>().user?['name'] as String?;
    return (accountName != null && accountName.trim().isNotEmpty)
        ? accountName
        : null;
  }
  String? get _description => _profile?.description;
  String? get _location {
    final value = _profile?.location;
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Stops a pull landing on top of a reload that is already running.
  bool _isReloading = false;

  bool get _hasPhoto => (_profile?.imageUrl ?? _profile?.imagePath) != null;

  /// Drives the NestedScrollView, so a tab change can send it back to the top.
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Nothing loaded the profile this screen is supposed to display.
      final provider = context.read<EmployerProfileProvider>();
      if (provider.profile == null) provider.fetchProfile();
      context.read<VerificationProvider>().fetchVerifications();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Back to the top on a tab change - see the worker profile for why.
  void _onTabChanged() {
    if (!_scroll.hasClients) return;
    if (_tabController.indexIsChanging && _scroll.offset > 0) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  /// Pull down to reload, the way every other list in the app behaves.
  ///
  /// Note the unconditional fetch: initState deliberately skips the request
  /// when a profile is already cached, which is right on open and wrong here —
  /// somebody pulling the screen down is asking for fresh data, and returning
  /// the cached copy would look like the gesture did nothing.
  Future<void> _reload() async {
    if (!mounted || _isReloading) return;
    setState(() => _isReloading = true);

    try {
      await Future.wait([
        context.read<EmployerProfileProvider>().fetchProfile(),
        context.read<VerificationProvider>().fetchVerifications(),
      ]);
    } catch (e) {
      debugPrint('[employer profile] reload failed: $e');
      if (mounted) {
        AppToast.info(context, 'Could not refresh your profile. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _isReloading = false);
    }
  }

  // ─── helpers ────────────────────────────────────────────────────────────────
  // ─── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    /*
        How many lines past the first the name will take.

        Decided here because the header's height is fixed before its contents
        are laid out. Roughly 22 characters fit on a line beside the avatar, so
        this counts them rather than guessing - and caps at two extra lines,
        which is where the name itself starts being truncated anyway.
    */
    // The name wraps to at most two lines now, so this only ever adds room
    // for the second one - no open-ended guessing about how long a name is.
    final extraNameLines = (_name ?? '').length > 22 ? 1 : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        controller: _scroll,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            // Scaled with the text for the reason described on the worker
            // profile: a fixed header height overflows the moment somebody
            // turns their font size up.
            /*
                And tall enough for a name that wraps.

                214 fits a short one on a single line. A registered business
                name - "Santiago Construction and General Services
                Incorporated" - runs to three, and the header had no room, so a
                filled employer profile spilled out of its own header while an
                empty one looked fine.
            */
            expandedHeight: (214 + (extraNameLines * 44) + 6) *
                MediaQuery.textScalerOf(context).scale(1.0),
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            /*
                The overflow menu is gone rather than filled.

                It was an IconButton with an empty handler — three dots at the
                top of the screen that opened nothing, on the one screen where
                people go looking for how to change their details. Every action
                it might plausibly have held is already a tappable card below
                it, so there was nothing to move into it.

                Removed rather than left inert: a control that answers a tap
                with silence reads as the app being broken, and it sends people
                hunting in the wrong place for the edit they wanted.
            */
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
            RefreshIndicator(onRefresh: _reload, child: _buildProfileTab()),
            RefreshIndicator(onRefresh: _reload, child: _buildVerificationsTab()),
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
              const SizedBox(height: 34),

              // ── Avatar + info row ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile photo — tappable to upload
                  GestureDetector(
                    // The picker is not built yet. This used to flip a local
                    // flag, swapping the camera icon for a business icon —
                    // which looked exactly like an upload had succeeded.
                    onTap: () => AppToast.info(
                      context,
                      'Adding a company photo is coming soon.',
                    ),
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

                        /*
                            Two lines, then an ellipsis.

                            A registered business name runs long - "Santiago
                            Construction and General Services Incorporated" is
                            four lines in a header this narrow - and an
                            uncapped one pushed the header past its own height.

                            Capping it is better than making the header taller
                            to fit: the header has a fixed height, so anything
                            that can grow without limit will eventually
                            outgrow it, and the full name is on the row below
                            where there is room for it.
                        */
                        Text(
                          _name ?? 'Your Name',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                            // Barangay, city and province is a long line and a
                            // Row will happily carry it off the screen.
                            Expanded(
                              child: Text(
                                _location ?? 'Location not set',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: _location != null
                                        ? Colors.white70
                                        : Colors.white30),
                              ),
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
                  fontSize: 13.5,
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

  /// Reads the real verification records.
  ///
  /// This used a local field fixed at 'unverified', so an employer who had
  /// been approved still saw "Not Verified" forever. The worker profile
  /// already read the provider — see `my_worker_profile_screen`.
  Widget _buildVerificationBadge() {
    final status = context.watch<VerificationProvider>().statusFor('government_id');

    if (status == 'verified') {
      return _badge(Icons.verified, 'Verified', AppColors.success);
    } else if (status == 'pending') {
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

  /// The account type, stated rather than offered.
  ///
  /// Says plainly that it cannot be changed. Leaving that unsaid invites the
  /// user to hunt for a setting that does not exist — and the reason it does
  /// not exist is real: a company profile carries business verification and
  /// document requirements an individual one does not, so switching would
  /// invalidate whatever has already been approved.
  Widget _buildAccountTypeRow() {
    final role = _role;

    // Same anatomy as every other row — label above value — so the one
    // read-only row does not announce itself as a different kind of thing. The
    // padlock replaces the chevron, which is the only difference that carries
    // meaning here: this row is the one you cannot open.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Account type',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.neutral600)),
                const SizedBox(height: 2),
                Text(role ?? 'Not set',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral900)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.lock_outline, size: 18, color: AppColors.neutral400),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // Same heading the worker profile opens with, so the two sides of one
        // account read as the same product.
        const Text(
          'Complete Your Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.neutral900,
          ),
        ),
        const SizedBox(height: 16),

        // ── ACCOUNT TYPE ── read-only.
        //
        // This was a live Company/Individual toggle the user could flip at
        // will. It changed nothing: the server keys its validation off the
        // stored employer_type and never accepts a new one, so flipping it
        // only made the screen disagree with the account. Worse, it implied
        // the choice was reversible when it is decided once, during setup, and
        // fixed after — a company profile carries business verification an
        // individual one does not.
        _buildAccountTypeRow(),

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
          /*
              Edited here, the same way the worker profile does it.

              These were the last rows in the app that pushed a screen to
              change one field, and two of them used to write only to local
              state - the name and the description looked saved and were gone
              on the next rebuild. Doing it in place removes both the
              navigation and the chance to forget the save call.
          */
          InlineEditRow(
            label: _role == 'Company' ? 'Company name' : 'Your name',
            value: _name,
            maxLength: 120,
            validator: (v) => v.isEmpty ? 'A name is required.' : null,
            onSave: (v) async {
              final p = context.read<EmployerProfileProvider>();
              final ok = await p.updateProfile(companyName: v);
              return ok ? null : (p.errorMessage ?? 'Could not save.');
            },
          ),

          InlineEditRow(
            label: _role == 'Company' ? 'About the company' : 'About you',
            value: _description,
            maxLines: 4,
            maxLength: 1000,
            emptyLabel: _role == 'Company'
                ? 'Tell workers about your company'
                : 'Tell workers about yourself',
            onSave: (v) async {
              final p = context.read<EmployerProfileProvider>();
              final ok = await p.updateProfile(description: v);
              return ok ? null : (p.errorMessage ?? 'Could not save.');
            },
          ),

          /*
              Industry and website, which nothing could set before.

              Both have been on the model and accepted by updateProfile since
              the profile was built, and no screen ever showed them - so the
              columns existed, the endpoint took them, and they stayed empty
              forever. They are worth showing: an employer with a named trade
              and a real page reads as a business rather than an empty shell.
          */
          InlineEditRow(
            label: 'Industry',
            value: _profile?.industry,
            maxLength: 100,
            onSave: (v) async {
              final p = context.read<EmployerProfileProvider>();
              final ok = await p.updateProfile(industry: v);
              return ok ? null : (p.errorMessage ?? 'Could not save.');
            },
          ),

          InlineEditRow(
            label: 'Website or page',
            value: _profile?.website,
            keyboardType: TextInputType.url,
            maxLength: 255,
            validator: (v) {
              if (v.isEmpty) return null;
              // Deliberately loose. Most small businesses here have a Facebook
              // page and no domain of their own, and a strict URL check would
              // leave this permanently empty for the people most likely to
              // fill it in.
              return v.contains(' ')
                  ? 'A web address has no spaces in it.'
                  : null;
            },
            onSave: (v) async {
              final p = context.read<EmployerProfileProvider>();
              final ok = await p.updateProfile(website: v);
              return ok ? null : (p.errorMessage ?? 'Could not save.');
            },
          ),

          // The same picker the worker side uses: typed, but committed as a
          // real place, so the coordinates behind it stay correct.
          InlineLocationRow(
            value: _location,
            onSave: (place) async {
              final p = context.read<EmployerProfileProvider>();
              final ok = await p.updateProfile(
                location: place.displayName,
                locationId: place.id,
                latitude: place.latitude,
                longitude: place.longitude,
              );
              return ok ? null : (p.errorMessage ?? 'Could not save.');
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

// ─── sticky tab delegate ──────────────────────────────────────────────────────

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) => false;
}
