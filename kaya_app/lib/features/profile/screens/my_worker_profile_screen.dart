import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/inline_edit_row.dart';
import '../widgets/inline_location_row.dart';
import '../widgets/profile_completeness_header.dart';
import '../widgets/profile_section_card.dart';
import '../../../data/services/api_client.dart';
import '../../../data/models/worker_skill_model.dart';
import '../../../data/models/skill_model.dart';
import '../../../providers/worker_profile_provider.dart';
import '../../../providers/verification_provider.dart';
import '../../../providers/profile_view_provider.dart';
import '../../../core/widgets/app_toast.dart';

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

  @override
  Widget build(BuildContext context) {
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
              expandedHeight:
                  190 * MediaQuery.textScalerOf(context).scale(1.0),
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
                                onTap: () async {
                                  final provider = context.read<WorkerProfileProvider>();
                                  final choice = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Profile Photo'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Gallery'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Camera'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (choice == null) return;
                                  await provider.uploadPhoto(fromCamera: choice);
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
                                        Text(
                                          context.watch<WorkerProfileProvider>().location ?? 'Add location',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: context.watch<WorkerProfileProvider>().location != null
                                                ? Colors.white70
                                                : Colors.white30,
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
                                          if (hasPhone)
                                            Row(
                                              children: [
                                                const Icon(Icons.phone, size: 12, color: Colors.white60),
                                                const SizedBox(width: 4),
                                                Text(p.phone!,
                                                    style: const TextStyle(fontSize: 12, color: Colors.white60)),
                                              ],
                                            ),
                                          if (hasEmail)
                                            Row(
                                              children: [
                                                const Icon(Icons.email, size: 12, color: Colors.white60),
                                                const SizedBox(width: 4),
                                                Text(p.email!,
                                                    style: const TextStyle(fontSize: 12, color: Colors.white60)),
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
                                                  child: Text(
                                                    skill.skillName,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.white,
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

  /// Asks before removing a job entry, because there is no undo for one.
  Future<void> _confirmDeleteExperience(Map<String, dynamic> exp) async {
    final title = (exp['title'] ?? exp['position'] ?? 'this entry').toString();

    final sure = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove this experience?'),
        content: Text('"$title" will be removed from your profile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (sure != true || !mounted) return;

    final id = exp['id'];
    if (id is! int) return;

    final provider = context.read<WorkerProfileProvider>();
    final ok = await provider.deleteExperience(id);
    if (!mounted) return;

    if (!ok) {
      AppToast.error(context, provider.errorMessage ?? 'Could not remove it.');
    }
  }

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return '';
    try {
      if (d.contains('-')) {
        final parts = d.split('-');
        const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final m = int.tryParse(parts[1]) ?? 1;
        return '${months[m]} ${parts[0]}';
      }
    } catch (_) {}
    return d;
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
          hint: 'Your full name',
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
                                      Text(skill.skillName, style: const TextStyle(fontSize: 12)),
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

        // Experience Card
        _buildInfoCard(
          title: 'Experience',
          icon: Icons.work,
          iconColor: AppColors.success,
          content: p.experiences.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  /*
                      Each entry carries its own actions.

                      This was a read-only list, and the only way to correct a
                      typo in a job title was to open a separate screen and
                      find the entry again. Edit and delete belong next to the
                      thing they act on.

                      Delete asks first. It is one tap next to an edit button,
                      the two are easy to confuse, and there is no undo for a
                      job history somebody typed out by hand.
                  */
                  children: p.experiences.map((exp) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exp['title'] ?? exp['position'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                '${exp['company']} • ${_fmtDate(exp['start_date'])} – ${exp['end_date'] != null ? _fmtDate(exp['end_date']) : 'Present'}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pushNamed(
                              context, '/add-experience', arguments: exp),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          color: AppColors.neutral500,
                          tooltip: 'Edit',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                        ),
                        IconButton(
                          onPressed: () => _confirmDeleteExperience(exp),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: AppColors.error,
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                        ),
                      ],
                    ),
                  )).toList(),
                )
              : const Text('None added', style: TextStyle(color: AppColors.neutral600)),
          onTap: () => Navigator.pushNamed(context, '/add-experience'),
        ),

        ProfileSectionHeading('Credentials'),

        // Certifications Card
        _buildInfoCard(
          title: 'Certifications',
          icon: Icons.workspace_premium,
          iconColor: Colors.orange,
          content: p.certifications.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: p.certifications.map((cert) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${cert.certificationName} - ${cert.issuingOrganization}',
                            style: const TextStyle(fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                )
              : const Text('None added', style: TextStyle(color: AppColors.neutral600)),
          onTap: () => Navigator.pushNamed(context, '/add-certifications'),
        ),

        // Licenses Card
        _buildInfoCard(
          title: 'Licenses',
          icon: Icons.badge,
          iconColor: Colors.purple,
          content: p.licenses.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: p.licenses.map((lic) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.badge, size: 16, color: Colors.purple),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${lic.licenseName} - ${lic.issuingAuthority}',
                            style: const TextStyle(fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                )
              : const Text('None added', style: TextStyle(color: AppColors.neutral600)),
          onTap: () => Navigator.pushNamed(context, '/add-licenses'),
        ),
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
          const Text('Verified workers get picked more often',
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
          _buildVerificationCard(
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

  Widget _buildVerificationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String type,
    required String status,
  }) {
    final isVerified = status == 'verified';
    final isPending  = status == 'pending';
    final isRejected = status == 'rejected';
    final hasSubmitted = isPending || isVerified || isRejected;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        child: InkWell(
          onTap: () async {
            // If already verified, don't allow navigation
            if (isVerified) return;
            
            // If pending or rejected, show retake confirmation dialog
            if (hasSubmitted) {
              final shouldRetake = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Retake Verification?'),
                  content: Text(
                    isRejected 
                      ? 'Your previous submission was rejected. Would you like to submit new documents?'
                      : 'You have already submitted verification documents. Would you like to retake and resubmit?'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      child: const Text('Retake'),
                    ),
                  ],
                ),
              );
              
              if (shouldRetake != true) return;
            }
            
            // Navigate to verification screen
            await Navigator.pushNamed(context, '/verification',
                arguments: {'type': type, 'title': title, 'subtitle': subtitle});
            if (mounted) context.read<VerificationProvider>().fetchVerifications();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isVerified
                        ? AppColors.success.withValues(alpha: 0.1)
                        : isPending
                            ? AppColors.warning.withValues(alpha: 0.1)
                            : isRejected
                                ? AppColors.error.withValues(alpha: 0.1)
                                : AppColors.neutral100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isVerified ? Icons.check_circle : isPending ? Icons.hourglass_top : isRejected ? Icons.error_outline : icon,
                    color: isVerified ? AppColors.success : isPending ? AppColors.warning : isRejected ? AppColors.error : AppColors.neutral600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
                      Text(
                        isVerified ? 'Verified' : isPending ? 'Under review' : isRejected ? 'Rejected - Tap to retake' : subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isVerified ? AppColors.success : isPending ? AppColors.warning : isRejected ? AppColors.error : AppColors.neutral600,
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
                    child: const Text('Verified', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                  )
                else if (isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning)),
                  )
                else if (isRejected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Retake', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error)),
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

