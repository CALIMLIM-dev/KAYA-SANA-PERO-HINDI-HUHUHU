import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/credentials_section.dart';
import '../widgets/experience_section.dart';
import '../widgets/inline_edit_row.dart';
import '../widgets/inline_location_row.dart';
import '../widgets/profile_completeness_header.dart';
import '../widgets/profile_section_card.dart';
import '../../../data/services/api_client.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/worker_skill_model.dart';
import '../../../data/models/skill_model.dart';
import '../../../providers/worker_profile_provider.dart';
import '../../../providers/verification_provider.dart';
import '../../../providers/profile_view_provider.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/verification_card.dart';

/// My Worker Profile - JobStreet-inspired card layout
/// Shows filled data in cards, NOT empty clickable placeholders
class MyWorkerProfileScreen extends StatefulWidget {
  const MyWorkerProfileScreen({super.key});

  @override
  State<MyWorkerProfileScreen> createState() => _MyWorkerProfileScreenState();
}

class _MyWorkerProfileScreenState extends State<MyWorkerProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Profile data read from WorkerProfileProvider — no local state needed
  // These getters proxy to the provider for display

  /// True while a manual reload is in flight, so the button can show it.
  /// Kept so a reload triggered on resume cannot overlap one the user pulled.
  bool _isReloading = false;

  /// Drives the NestedScrollView, so a tab change can send it back to the top.
  final ScrollController _scroll = ScrollController();

  /*
      The header's height, measured rather than predicted.

      It used to be arithmetic — a base number plus a bit per contact row plus
      a block if there were any skills, all multiplied by the text scale. That
      is a guess about content nobody has laid out yet, and it was wrong in
      both directions: too short for a filled-in profile, which overflowed,
      then too tall once padded to cover that, which left a band of empty
      purple between the skill chips and the tabs.

      A SliverAppBar does need its height before its contents exist, so the
      first frame still uses the estimate. After that frame the marker at the
      bottom of the header says where the content really ended, and the header
      adopts it. One frame at the wrong size, then correct for every profile,
      every text scale and every number of skills.
  */
  final GlobalKey _headerEndKey = GlobalKey();
  double? _headerHeight;

  void _measureHeader() {
    final box = _headerEndKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    // Distance from the top of the screen to the end of the header's content.
    // Only meaningful while the header is fully expanded, which is why this
    // bails out once the list has been scrolled.
    if (_scroll.hasClients && _scroll.offset > 1) return;

    final bottom = box.localToGlobal(Offset.zero).dy + _headerBottomPadding;
    if (bottom <= 0) return;
    if (_headerHeight != null && (_headerHeight! - bottom).abs() < 0.5) return;

    setState(() => _headerHeight = bottom);
  }

  /// The padding that sits below the marker, which the marker cannot see.
  ///
  /// Must match the bottom of the header's own EdgeInsets.fromLTRB(16, 16,
  /// 16, 24). It was 16 here against 24 there, and the profile overflowed by
  /// exactly the eight pixels of difference — measuring to the wrong place is
  /// no better than guessing, it just fails more precisely.
  static const double _headerBottomPadding = 24;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  /*
      Back to the top when the tab changes.

      A NestedScrollView keeps one shared outer scroll position for every tab,
      so scrolling to the bottom of the profile and then tapping Verifications
      landed you at the bottom of a shorter list, with the header already
      collapsed and no sign of where you were. Nothing was broken, but you had
      to scroll up before you could read the tab you just asked for.

      Every other tabbed screen on a phone starts a new tab at the top, so this
      does too. Animated rather than jumped, so it reads as the page moving
      rather than as content changing under you.
  */
  void _onTabChanged() {
    if (!_scroll.hasClients) return;
    // indexIsChanging is false on the settle, which would run this twice.
    if (_tabController.indexIsChanging && _scroll.offset > 0) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }



  /// Loads the profile and its verifications.
  ///
  /// Both fetches used to hang off `.catchError((e) => print(...))`, so a
  /// failure printed to a console nobody reads and left the screen showing an
  /// empty profile — indistinguishable from an account that genuinely has
  /// nothing filled in, and with no way to try again.
  ///
  /// Failures are still not fatal: the providers keep whatever they already
  /// had. What changed is that the user can see it happening and retry.
  Future<void> _reload() async {
    if (!mounted || _isReloading) return;
    setState(() => _isReloading = true);

    try {
      await Future.wait([
        context.read<WorkerProfileProvider>().fetchProfile(),
        context.read<VerificationProvider>().fetchVerifications(),
        // Fetched alongside the profile rather than on its own timer, so the
        // view count is as fresh as everything else on the screen.
        context.read<ProfileViewProvider>().fetch(),
      ]);
    } catch (e) {
      debugPrint('[worker profile] reload failed: $e');
      if (mounted) {
        AppToast.info(context, 'Could not refresh your profile. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _isReloading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /*
      Tapping your own photo offers to show it, not just replace it.

      This went straight to a Gallery/Camera dialog, so the only thing you
      could do with your own picture was overwrite it — and at 68 pixels in
      the header there was no way to check what an employer actually sees.
      That is the one thing worth looking at, since it is what a hiring
      decision gets made on.

      Viewing comes first when a photo exists, because looking is the common
      case and replacing is the rare one.
  */
  Future<void> _onPhotoTapped() async {
    final provider = context.read<WorkerProfileProvider>();
    final path = provider.profilePhotoPath;
    final hasPhoto = path != null && path.isNotEmpty;

    final choice = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Profile photo'),
        children: [
          if (hasPhoto)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'view'),
              child: const Text('View photo'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'gallery'),
            child: Text(hasPhoto ? 'Choose a new one' : 'Choose from gallery'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'camera'),
            child: const Text('Take a photo'),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    if (choice == 'view') {
      _showPhotoPreview(ApiClient.fileUrl(path));
      return;
    }

    await provider.uploadPhoto(fromCamera: choice == 'camera');
  }

  /// The photo at the size other people see it, pinch to zoom.
  void _showPhotoPreview(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              maxScale: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                  // A broken image with no explanation reads as the photo
                  // having been lost, which it has not.
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Could not load your photo.\nCheck your connection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(dialogContext),
              tooltip: 'Close',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    /*
        How many contact rows the header is about to draw.

        Read here rather than inside the header, because the height of the
        SliverAppBar has to be decided before its contents are built - and it
        was decided from a constant, which is how a filled-in profile ended up
        taller than the space reserved for it.
    */
    // Re-measure after every build: the skills, the contact rows and the text
    // scale can all change while the screen is open, and each of them moves
    // where the header ends.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureHeader();
    });

    final profile = context.watch<WorkerProfileProvider>();
    final contactLines = [
      (profile.phone ?? '').isNotEmpty,
      (profile.email ?? '').isNotEmpty,
    ].where((present) => present).length;

    /*
        And the skills preview, which is the rest of the header.

        Below the contact rows the header prints each skill category in
        capitals with a chip per skill under it. A profile with no skills draws
        none of that, which is why an empty one always fitted while a real one
        was eleven pixels over on the phone that reported it.

        A flat number rather than one per category, because the preview is
        capped at 80 logical pixels and scrolls inside that - so however many
        skills there are, the block is the same height. 92 is that cap plus the
        gap above it.
    */
    final skillsBlock = profile.skills.isEmpty ? 0 : 92;

    return Scaffold(
      backgroundColor: AppColors.background,
      /*
          White on yellow is unreadable, and the default elevation drew a hard
          dark ring around the button that looked like a rendering fault.

          Dark ink on the accent instead — the accent is a light yellow, so it
          behaves like a highlight, not like a dark brand colour. Elevation is
          dropped to 2 so the button sits on the page rather than hovering off
          it. The list below gets bottom padding so this no longer covers the
          last row.
      */
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.neutral900,
        elevation: 2,
        icon: const Icon(Icons.check, size: 20),
        label: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: NestedScrollView(
        controller: _scroll,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
            /*
                Scaled with the text, not fixed.

                A hard number here is a promise that the content inside will
                never need more room, and text scaling breaks that promise on
                the first phone whose owner has turned the setting up: the
                header keeps its height, the name and category inside grow, and
                the bottom spills. It cost eighteen pixels of overflow at the
                largest size this app allows.

                Multiplying by the same factor the text grew by gives the
                content exactly the extra room it asked for.
            */
              /*
                  Tall enough for what is actually in it.

                  190 fits a name and a location. It does not fit a name, a
                  location, a phone number and an email address, so a profile
                  filled in properly spilled out of its own header - which is
                  why this only ever happened on some accounts and never on a
                  fresh one.

                  Each contact line adds its own height rather than padding the
                  number and hoping, and the whole thing still scales with the
                  text.
              */
              /*
                  The measured height once there is one.

                  The estimate is only used for the first frame, and it stays
                  generous on purpose. Trimming it to sit closer to the real
                  height overflowed that frame on a narrow phone at the larger
                  text sizes — the populated-profile tests catch exactly that,
                  since they render before any measurement can have happened.

                  So the estimate only ever errs tall, and the measurement is
                  what brings it down. Overshooting costs one frame of extra
                  purple; undershooting costs a frame of clipped content, and
                  those are not equally cheap.
              */
              expandedHeight: _headerHeight ??
                  ((190 + (contactLines * 24) + skillsBlock) *
                      MediaQuery.textScalerOf(context).scale(1.0)),
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              /*
                  No refresh button.

                  There was one here, added so a failed load had a way back.
                  It did the job and still had to go: a refresh icon in a
                  toolbar is a desktop control, and on a phone it reads as
                  something being wrong — people ask what it is for, because
                  every other screen they use refreshes by pulling down.

                  The gesture below replaces it and covers the same failure,
                  with the advantage that nobody has to be told it exists.
              */
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
                          // Clears the pinned toolbar. Sized with the header
                          // height above — a spacer left at 56 overflows once
                          // the header is no longer 280 tall.
                          const SizedBox(height: 34),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Profile Photo
                              GestureDetector(
                                onTap: _onPhotoTapped,
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
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: context.watch<WorkerProfileProvider>().profilePhotoPath != null
                                            ? Image.network(
                                                ApiClient.fileUrl(context.watch<WorkerProfileProvider>().profilePhotoPath),
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(Icons.person, color: Colors.white54, size: 32),
                                              )
                                            : const Icon(Icons.camera_alt, color: Colors.white54, size: 24),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: AppColors.accent,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        child: const Icon(Icons.add, size: 13, color: Colors.white),
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
                                    // Name — always visible
                                    Text(
                                      context.watch<WorkerProfileProvider>().name ?? 'Add your name',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: context.watch<WorkerProfileProvider>().name != null
                                            ? Colors.white
                                            : Colors.white38,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Location — always visible
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 13,
                                          color: context.watch<WorkerProfileProvider>().location != null
                                              ? Colors.white70
                                              : Colors.white30,
                                        ),
                                        const SizedBox(width: 3),
                                        // A full address is barangay, city and
                                        // province. Unconstrained it carried
                                        // the row off the right of the header.
                                        Expanded(
                                          child: Text(
                                            context.watch<WorkerProfileProvider>().location ?? 'Add location',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              color: context.watch<WorkerProfileProvider>().location != null
                                                  ? Colors.white70
                                                  : Colors.white30,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Contact info
                                    Builder(builder: (context) {
                                      final p = context.watch<WorkerProfileProvider>();
                                      final hasPhone = p.phone != null && p.phone!.isNotEmpty;
                                      final hasEmail = p.email != null && p.email!.isNotEmpty;
                                      
                                      if (!hasPhone && !hasEmail) {
                                        return const Text('Add contact details',
                                            style: TextStyle(fontSize: 12, color: Colors.white24));
                                      }
                                      
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Both capped for the same reason as
                                          // the address above: an email
                                          // address is long and a Row will
                                          // gladly run off the screen for it.
                                          if (hasPhone)
                                            Row(
                                              children: [
                                                const Icon(Icons.phone, size: 12, color: Colors.white60),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(p.phone!,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 12, color: Colors.white60)),
                                                ),
                                              ],
                                            ),
                                          if (hasEmail)
                                            Row(
                                              children: [
                                                const Icon(Icons.email, size: 12, color: Colors.white60),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(p.email!,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 12, color: Colors.white60)),
                                                ),
                                              ],
                                            ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Skills preview - Grouped by category
                          Selector<WorkerProfileProvider, List<WorkerSkillModel>>(
                            selector: (_, provider) => provider.skills,
                            shouldRebuild: (prev, next) => prev.length != next.length,
                            builder: (context, skills, _) {
                              if (skills.isNotEmpty) {
                                // Group skills by category
                                final Map<String, List<WorkerSkillModel>> grouped = {};
                                for (var skill in skills) {
                                  final category = skill.categoryName ?? 'Other';
                                  grouped.putIfAbsent(category, () => []).add(skill);
                                }

                                return Container(
                                  constraints: const BoxConstraints(maxHeight: 80),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: grouped.entries.map((entry) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Category header
                                              Text(
                                                entry.key.toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white70,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              // Skills
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: entry.value.map((skill) => Container(
                                                  key: ValueKey(skill.id ?? skill.skillName),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  /*
                                                      Capped, because a Wrap
                                                      cannot break one child.

                                                      Wrap moves a chip to the
                                                      next line when it does
                                                      not fit, which is the
                                                      right behaviour and was
                                                      never the problem. A
                                                      single chip wider than
                                                      the screen has no next
                                                      line to move to -
                                                      "Refrigeration and aircon
                                                      servicing" is one skill
                                                      and it does not fit on a
                                                      320px phone at any font
                                                      size.
                                                  */
                                                  child: ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                      maxWidth: MediaQuery.sizeOf(context).width - 170,
                                                    ),
                                                    child: Text(
                                                      skill.skillName,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                )).toList(),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                );
                              } else {
                                return Container(
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
                                );
                              }
                            },
                          ),
                          /*
                              Where the header's content actually ends.

                              Zero height and invisible; it exists to be
                              measured. The Column is top-packed, so this sits
                              directly under the last thing drawn, and its
                              distance from the top of the screen is the real
                              height of the header — including whatever the
                              text scale and the number of skills did to it.

                              _measureHeader reads it after the frame and
                              adopts it, which is what stops the arithmetic
                              above from having to be right.
                          */
                          SizedBox(key: _headerEndKey, height: 0),
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
                    Tab(text: 'Profile'),
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
            RefreshIndicator(onRefresh: _reload, child: _buildSuggestedTab()),
            RefreshIndicator(onRefresh: _reload, child: _buildVerificationsTab()),
          ],
        ),
      ),
    );
  }

  /*
      The same small pin control as the setup flow.

      This was a full-width card with a border, an icon, a title, a sentence
      and a chevron, all of it saying what the pin icon says on its own. A
      maps app uses one small button for this because there is nothing to
      explain.

      Kept identical to the setup flow version deliberately - it is the same
      action on the same data, and two different-looking controls for it is
      how someone ends up unsure whether they are the same thing.
  */
  Widget _pinRow(WorkerProfileProvider p) {
    final pinned = p.hasPinnedLocation;
    final hasCity = (p.location ?? '').trim().isNotEmpty;

    final tint = !hasCity
        ? AppColors.neutral400
        : (pinned ? AppColors.success : AppColors.primary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: hasCity ? () => _openPinPicker(p) : null,
          icon: Icon(
            pinned ? Icons.where_to_vote : Icons.add_location_alt_outlined,
            size: 18,
          ),
          label: Text(pinned ? 'Pinned' : 'Pin location'),
          style: OutlinedButton.styleFrom(
            foregroundColor: tint,
            side: BorderSide(color: tint.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
  Future<void> _openPinPicker(WorkerProfileProvider p) async {
    final result = await Navigator.pushNamed(
      context,
      '/pin-location',
      arguments: {
        'latitude': p.latitude,
        'longitude': p.longitude,
        'label': p.location,
      },
    );

    if (result is! Map || !mounted) return;

    final lat = (result['latitude'] as num?)?.toDouble();
    final lng = (result['longitude'] as num?)?.toDouble();
    final resolved = result['resolved'] as LocationModel?;
    if (lat == null || lng == null) return;

    final provider = context.read<WorkerProfileProvider>();

    /*
        The label follows the pin.

        This sent the profile's existing location text back with the new
        coordinates and dropped location_id entirely, so moving the pin to the
        next town over saved the new spot under the old name — the profile
        still said Urdaneta while its coordinates sat in Binalonan, and every
        distance was measured from a place the profile never showed. It also
        looked like the pin had not saved at all, because the only thing on
        screen that could have shown a change was the text, and the text never
        moved.

        The pin screen already reverse-geocodes and hands back `resolved`;
        this was the one caller throwing it away. The setup flow asks before
        overwriting a name the user typed, so this asks too.
    */
    final movedElsewhere = resolved != null &&
        (provider.location ?? '').trim().isNotEmpty &&
        resolved.displayName.trim().toLowerCase() !=
            (provider.location ?? '').trim().toLowerCase();

    var label = provider.location ?? '';
    int? locationId;

    if (resolved != null) {
      final adopt = !movedElsewhere || await _confirmLocationChange(resolved);
      if (!mounted) return;
      if (adopt) {
        label = resolved.displayName;
        locationId = resolved.id;
      }
    }

    final ok = await provider.updateLocation(
      label,
      locationId: locationId,
      latitude: lat,
      longitude: lng,
    );
    if (!mounted) return;

    if (!ok) {
      AppToast.error(context, provider.errorMessage ?? 'Could not save the pin.');
    }
  }

  /// Asked before a dropped pin renames the profile's location.
  Future<bool> _confirmLocationChange(LocationModel resolved) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update your location?'),
        content: Text(
          'That pin is in ${resolved.displayName}.\n\n'
          'Update your profile location to match, so jobs show the right '
          'distance to you?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep current name'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    return yes ?? false;
  }

  /// "8 employers viewed your profile this week."
  ///
  /// Hidden entirely until the count is both loaded and non-zero. A brand-new
  /// worker being told "0 people viewed your profile" on the day they sign up
  /// is discouraging and tells them nothing they can act on — and "0" is also
  /// what a failed request looks like, so showing it would sometimes be a lie.
  Widget _buildViewsBanner() {
    final views = context.watch<ProfileViewProvider>();

    if (!views.hasLoaded || views.workerUniqueViewers == 0) {
      return const SizedBox.shrink();
    }

    final n = views.workerUniqueViewers;
    final people = n == 1 ? 'employer' : 'employers';
    final window = views.days == 7 ? 'this week' : 'in the last ${views.days} days';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined,
              size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          // Expanded + soft wrapping: the sentence changes length with the
          // number and the window, and a fixed row here would overflow on a
          // narrow screen.
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 13.5, color: AppColors.neutral700),
                children: [
                  TextSpan(
                    text: '$n $people ',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutral900),
                  ),
                  TextSpan(text: 'viewed your profile $window'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedTab() {
    final p = context.watch<WorkerProfileProvider>();
    return ListView(
      // 96 at the bottom clears the floating Done button, which was sitting
      // on top of the final row.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _buildViewsBanner(),
        /*
            The heading here used to be the words "Complete Your Profile" and
            nothing else — no sense of how complete, or of what was missing.

            The server has computed both since profile completeness was built,
            and nothing read it. A ring that is visibly short of closing does
            what a heading cannot: it gives somebody a reason to finish.
        */
        Consumer<AuthProvider>(
          builder: (context, auth, _) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ProfileCompletenessHeader(
              percent: auth.workerCompletenessPercent,
              next: auth.workerCompletenessNext,
            ),
          ),
        ),

        ProfileSectionHeading('About you'),

        /*
            Edited here rather than on a screen of its own.

            Changing a name was: tap the row, wait for a page to slide in, type
            in the only field on it, tap save, wait for it to slide back. For
            one line of text. Now the row itself takes the cursor.
        */
        InlineEditRow(
          label: 'Full name',
          value: p.name,
          maxLength: 100,
          validator: (v) => v.isEmpty ? 'A name is required.' : null,
          onSave: (v) async {
            final provider = context.read<WorkerProfileProvider>();
            final ok = await provider.updateName(v);
            return ok ? null : (provider.errorMessage ?? 'Could not save.');
          },
        ),

        /*
            Typed here, but still a real place.

            Same inline treatment as the fields above, with one difference that
            matters: what gets saved is the chosen place, not the typed text. A
            location carries a PSGC id and coordinates, and everything that
            measures distance depends on them, so free text is never accepted
            on its own.
        */
        InlineLocationRow(
          value: p.location,
          onSave: (place) async {
            final provider = context.read<WorkerProfileProvider>();
            // The place's own coordinates are its centroid - the middle of the
            // city, not where anybody lives. Good enough to sort by until the
            // exact spot is pinned below, and it replaces any previous pin
            // because a pin in the old city is worse than none.
            final ok = await provider.updateLocation(
              place.displayName,
              locationId: place.id,
              latitude: place.latitude,
              longitude: place.longitude,
            );
            return ok ? null : (provider.errorMessage ?? 'Could not save.');
          },
        ),

        /*
            The exact spot, which the city alone cannot give.

            Choosing a city saves its centroid, so every distance in the app
            would be measured from the middle of town. This is what makes
            "3.4 km away" mean anything, and it is the one part of a location
            that genuinely needs a map rather than a text field.
        */
        _pinRow(p),

        /*
            Both details, both on screen, both editable.

            These were collapsed into a single "Personal Details" row that
            showed a summary and hid the actual fields behind another screen.
            Two short pieces of text do not need to be hidden - showing them is
            the whole point of a profile, and there is room.
        */
        InlineEditRow(
          label: 'Phone number',
          value: p.phone,
          hint: '09XX XXX XXXX',
          keyboardType: TextInputType.phone,
          maxLength: 20,
          validator: (v) {
            if (v.isEmpty) return null; // clearing is handled by the row
            // Deliberately loose. Landlines, +63, and spaces are all real, and
            // a strict pattern here rejects more valid numbers than it catches
            // bad ones.
            final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
            return digits.length < 7 ? 'That does not look like a phone number.' : null;
          },
          onSave: (v) async {
            final provider = context.read<WorkerProfileProvider>();
            final ok = await provider.updatePhone(v);
            return ok ? null : (provider.errorMessage ?? 'Could not save.');
          },
        ),

        // Shown because people expect to see it, locked because changing a
        // sign-in address is an account operation with its own verification -
        // not something to do by tapping a row on a profile.
        InlineEditRow(
          label: 'Email',
          value: p.email,
          enabled: false,
          disabledNote: 'Your email is your sign-in. Change it in Settings.',
          emptyLabel: 'Not set',
          onSave: (_) async => null,
        ),

        ProfileSectionHeading('Your work'),

        // Skills Card - Using Selector to prevent unnecessary rebuilds
        Selector<WorkerProfileProvider, List<WorkerSkillModel>>(
          selector: (_, provider) => provider.skills,
          shouldRebuild: (prev, next) => prev.length != next.length,
          builder: (context, skills, _) {
            final hasSkills = skills.isNotEmpty;
            
            // Group skills by category
            final Map<String, List<WorkerSkillModel>> grouped = {};
            for (var skill in skills) {
              final category = skill.categoryName ?? 'Other';
              grouped.putIfAbsent(category, () => []).add(skill);
            }
            
            return _buildInfoCard(
              title: 'Skills',
              icon: Icons.build_circle,
              iconColor: AppColors.accent,
              content: hasSkills
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: grouped.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category header
                              Text(
                                entry.key.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.neutral600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Skills in this category
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: entry.value.map((skill) => Container(
                                  key: ValueKey(skill.id ?? skill.skillName),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      /*
                                          Capped, because nothing above will
                                          cap it.

                                          The chip sits in a Wrap, which gives
                                          each child unbounded width and moves
                                          it to the next line if it does not
                                          fit. A chip wider than the screen has
                                          no next line to move to, and a real
                                          skill name - "Refrigeration and
                                          aircon servicing" - is exactly that
                                          on a small phone.

                                          Flexible cannot help here: it needs a
                                          bounded parent and a Wrap child has
                                          none. The width has to come from the
                                          screen.
                                      */
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: MediaQuery.sizeOf(context).width - 170,
                                        ),
                                        child: Text(
                                          skill.skillName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () async {
                                          // Show confirmation dialog
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Remove Skill'),
                                              content: Text('Remove "${skill.skillName}" from your skills?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                  ),
                                                  child: const Text('Remove'),
                                                ),
                                              ],
                                            ),
                                          );
                                          
                                          if (confirmed == true && mounted && skill.id != null) {
                                            // Delete the specific skill by ID
                                            final provider = context.read<WorkerProfileProvider>();
                                            await provider.deleteSkill(skill.id!);
                                          }
                                        },
                                        child: Icon(Icons.close, size: 14, color: AppColors.primary.withValues(alpha: 0.7)),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  : const Text('None added', style: TextStyle(color: AppColors.neutral600)),
              onTap: () async {
                final skillNames = skills.map((s) => s.skillName).toList();
                final result = await Navigator.pushNamed(context, '/add-skills', 
                    arguments: skillNames);
                if (result != null && result is List<SkillModel> && mounted) {
                  // Save skills with category info
                  await context.read<WorkerProfileProvider>().saveSkillsWithCategories(result);
                }
              },
            );
          },
        ),

        /*
            Work history, edited here rather than on another screen.

            This was a read-only list whose only action opened a separate
            page. Each entry now opens into its own fields in place, with
            delete beside save and a confirmation on it.
        */
        ExperienceSection(experiences: p.experiences),

        ProfileSectionHeading('Credentials'),

        /*
            Both open into their own fields, like everything else here.

            These were the last two rows that pushed a separate screen, and
            that screen is where the replacement document was being silently
            dropped. One editor now, so there is one save path rather than
            two that drifted.
        */
        CredentialsSection(kind: CredentialKind.certification),

        const SizedBox(height: 4),
        CredentialsSection(kind: CredentialKind.licence),
      ],
    );
  }

  /*
      One row of the profile.

      Rebuilt after screenshotting the screen. It used to be a 130px card
      carrying a 48x48 tinted icon square — blue for name, green for location,
      yellow for skills — so five stacked rows were five small logos in five
      unrelated colours, and only four fitted on a phone.

      The icon box is gone entirely. It identified nothing the label did not
      already say, and it was the single biggest source of visual noise.
      `icon` and `iconColor` are still accepted so the seven call sites did not
      all have to change in the same edit; they are deliberately unused.

      What replaced it: label above value, a chevron for rows that are filled
      and a `+` for rows that are not, and a hairline border instead of an
      elevation shadow. About 68px per row against 130.
  */
  Widget _buildInfoCard({
    required String title,
    // ignore: avoid_unused_constructor_parameters
    required IconData icon,
    // ignore: avoid_unused_constructor_parameters
    required Color iconColor,
    required Widget content,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.neutral600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // The caller's content, re-styled from here so one change
                      // reaches every row rather than seven.
                      DefaultTextStyle.merge(
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        child: content,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.chevron_right,
                    size: 22, color: AppColors.neutral400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationsTab() {
    return Consumer<VerificationProvider>(
      builder: (context, vp, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Verification',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.neutral900)),
          const SizedBox(height: 8),
          // What it unlocks, not what it might get you. The old line sold a
          // benefit nobody promised; this one states the rule.
          const Text('Required before you can apply for work.',
              style: TextStyle(fontSize: 14, color: AppColors.neutral600)),
          const SizedBox(height: 20),

          /*
              Identity only.

              Phone and email used to sit here as two more verification cards,
              which put three things of very different weight on one screen and
              made the whole section read as paperwork. A government ID with a
              selfie is what an employer is actually deciding on; a phone
              number is a contact detail, and it belongs with the other contact
              details rather than being dressed up as a credential.
          */
          VerificationCard(
            title: 'Valid Philippine ID',
            subtitle: 'Government-issued ID with selfie',
            icon: Icons.badge,
            type: 'government_id',
            status: vp.statusFor('government_id'),
          ),
        ],
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

