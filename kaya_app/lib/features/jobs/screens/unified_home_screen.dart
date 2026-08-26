import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_mode.dart';
import '../../../core/constants/credits.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../data/models/job_model.dart';
import '../../../data/models/worker_profile_model.dart';
import '../../../data/services/suspension_check_service.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/credits_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/worker_profile_provider.dart';
import '../../../providers/worker_browse_provider.dart';
import '../../help/screens/faq_screen.dart';
import '../widgets/unified_search_bar.dart';
import '../widgets/jobs_near_you_section.dart';
import '../widgets/people_who_can_help_section.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../../core/utils/realtime_refresh.dart';
import '../../../data/services/realtime_service.dart';

/// Home screen for both sides of the marketplace.
///
/// Content is driven by the active AppMode (worker → jobs, employer → workers).
/// Accounts with no profile yet are in "neutral" mode and see everything plus
/// the dual setup card.
class UnifiedHomeScreen extends StatefulWidget {
  const UnifiedHomeScreen({super.key});

  @override
  State<UnifiedHomeScreen> createState() => _UnifiedHomeScreenState();
}

class _UnifiedHomeScreenState extends State<UnifiedHomeScreen>
    with RealtimeRefresh {
  // State variables
  SearchFilter _searchFilter = SearchFilter.all;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  // (The old _isOpenToWork / _isOpenToHire booleans lived here. They were
  // hardcoded and never mutated, so the header badges were purely decorative.
  // The badges are now driven by AppModeProvider — see _statusBadges.)

  // (The hardcoded _activeJobs = 3 / _pendingApplications = 1 stats lived here.
  // The activity cards now read real counts from JobProvider and
  // ApplicationProvider — see _loadActivityCounts.)
  
  // Empty state dismissal flag
  bool _isEmptyStateVisible = true; // Can be dismissed

  // Sourced from JobProvider.publicJobs / WorkerBrowseProvider.workers — see
  // _initializeData(). Previously these were populated from _getMockJobs() /
  // _getMockWorkers() below, so nothing you posted ever appeared here.
  List<Job> _allJobs = [];
  List<WorkerProfile> _allWorkers = [];
  List<Job> _filteredJobs = [];
  List<WorkerProfile> _filteredWorkers = [];

  /// How far "near you" reaches for the worker directory.
  ///
  /// 50 km covers a province comfortably without pulling in the next region.
  /// The server drops anyone whose position cannot be worked out, so this is a
  /// real bound rather than a hint.
  static const double _nearbyRadiusKm = 50;

  @override
  void initState() {
    super.initState();

    // Start periodic suspension checks
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        SuspensionCheckService.startPeriodicCheck(context);
        _loadActivityCounts();
        _initializeData();
        // The category row reads these; without the fetch it renders empty.
        final taxonomy = context.read<WorkerProfileProvider>();
        if (taxonomy.categories.isEmpty) taxonomy.fetchCategories();
        _watchNewJobs();
        bindRealtimeRefresh();
      }
    });
  }

  /// Activity counts follow the user's own events.
  @override
  List<String> get refreshOn => const ['application.', 'invitation.', 'job.'];

  @override
  void onRealtimeRefresh() => _loadActivityCounts();

  VoidCallback? _disposeJobsListener;

  /// New job postings, on the app's one public channel.
  ///
  /// Only in worker mode: a freshly posted job is noise to someone who is
  /// currently hiring, and reloading their worker feed underneath them would be
  /// worse than not knowing.
  ///
  /// It re-fetches rather than inserting the broadcast payload. The feed is
  /// filtered by category, distance-scored against the viewer's location and
  /// sorted server-side — a broadcast has no idea where any given listener is
  /// standing, so splicing the row in locally would put it in the wrong place
  /// or show it to someone the filters exclude.
  void _watchNewJobs() {
    _disposeJobsListener = RealtimeService.instance.on(
      'jobs',
      'job.published',
      (_) {
        if (!mounted) return;
        final appMode = context.read<AppModeProvider>();
        if (!appMode.hasWorkerProfile) return;
        if (appMode.mode == AppMode.employer) return;
        _initializeData();
      },
      private: false,
    );
  }

  /// Loads the real counts behind the "Your Activity" cards, fetching only the
  /// side(s) this account actually has.
  Future<void> _loadActivityCounts() async {
    if (!mounted) return;
    final appMode = context.read<AppModeProvider>();

    await Future.wait([
      if (appMode.hasEmployerProfile) context.read<JobProvider>().fetchMyJobs(),
      if (appMode.hasWorkerProfile)
        context.read<ApplicationProvider>().fetchMyApplications(),
    ]);
  }

  @override
  void dispose() {
    // Stop suspension checks when leaving home screen
    SuspensionCheckService.stopPeriodicCheck();
    _disposeJobsListener?.call();
    // RealtimeRefresh releases its own subscription via super.dispose().
    super.dispose();
  }

  /// Loads whichever feed(s) the active mode needs. A hybrid/neutral account
  /// loads both since either section may be shown.
  Future<void> _initializeData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final appMode = context.read<AppModeProvider>();
    final jobProvider = context.read<JobProvider>();
    final workerBrowse = context.read<WorkerBrowseProvider>();

    // Fetch based on what the account *owns*, not what it is focused on.
    //
    // Gating on the current mode meant a hybrid focused on worker never loaded
    // the worker directory — so clearing the focus, or picking the "All" chip,
    // showed an empty "people who can help" section until a manual refresh. A
    // hybrid can switch at any moment, so both lists have to be ready.
    final employerOnly = appMode.hasEmployerProfile && !appMode.hasWorkerProfile;
    final workerOnly = appMode.hasWorkerProfile && !appMode.hasEmployerProfile;

    /*
        "Jobs near you" now actually is.

        These sections are headed "Open jobs in {your city}" and "people who can
        help", but both were fed the unfiltered feed — the server computed a
        distance per row and nothing ever used it. Asking for nearest-first, and
        for workers within a radius, makes the heading true.

        Jobs are sorted rather than cut off: a worker in a quiet town would
        otherwise open the app to an empty screen. Workers are cut off, because
        an employer hiring for a specific site genuinely cannot use someone
        eighty kilometres away.
    */
    await Future.wait([
      if (!employerOnly) jobProvider.fetchPublicJobs(nearestFirst: true),
      if (!workerOnly) workerBrowse.fetchWorkers(radiusKm: _nearbyRadiusKm),
    ]);

    if (!mounted) return;
    setState(() {
      _allJobs = jobProvider.publicJobs;
      _allWorkers = workerBrowse.workers;
      _errorMessage = jobProvider.publicErrorMessage ?? workerBrowse.errorMessage;
      _isLoading = false;
      _applyFilters();
    });
  }

  Future<void> _refreshData() async {
    await _initializeData();
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query.trim();
      _applyFilters();
    });
  }

  /*
      The chips are the mode switch.

      They used to set a private filter that only the feed read, while the mode
      lived somewhere else and drove the activity cards - so picking Jobs
      narrowed the feed and left both sets of activity on screen underneath it,
      saying two different things about which side you were on.

      One control now. Choosing a side changes what the whole screen is about.
  */
  void _updateSearchFilter(SearchFilter filter) {
    final appMode = context.read<AppModeProvider>();

    final wanted = switch (filter) {
      SearchFilter.showJobs => AppMode.worker,
      SearchFilter.showWorkers => AppMode.employer,
      SearchFilter.all => AppMode.all,
    };

    // Only a hybrid has a choice; for anyone else the mode is structural and
    // the chips are not shown.
    if (appMode.isHybrid) {
      if (wanted == AppMode.all) {
        appMode.clearFocus();
      } else {
        appMode.setMode(wanted);
      }
    }

    setState(() {
      _searchFilter = filter;
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredJobs = _filterJobs(_allJobs);
    _filteredWorkers = _filterWorkers(_allWorkers);
  }

  List<Job> _filterJobs(List<Job> jobs) {
    if (_searchQuery.isEmpty) return jobs;
    return jobs.where((job) {
      return job.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             job.company.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (job.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
             (job.location?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  List<WorkerProfile> _filterWorkers(List<WorkerProfile> workers) {
    if (_searchQuery.isEmpty) return workers;
    return workers.where((worker) {
      return worker.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             worker.primarySkill.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (worker.location?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  bool _showJobsSection(SearchFilter filter) => filter == SearchFilter.all || filter == SearchFilter.showJobs;
  bool _showWorkersSection(SearchFilter filter) => filter == SearchFilter.all || filter == SearchFilter.showWorkers;

  /// Whether to show the dual "set up worker / set up employer" card.
  ///
  /// Requires BOTH sources to agree the account has no profile. `auth` is the
  /// authoritative server flag from /me; `appMode` is derived state that lags by
  /// a frame after onboarding. Checking only the latter left the card on screen
  /// after a user had finished setting up.
  bool _shouldShowProfileSetupPrompt(
    AuthProvider auth,
    AppModeProvider appMode,
  ) {
    if (auth.hasAnyProfile) return false;
    return appMode.isNeutral && _isEmptyStateVisible;
  }

  /// The "Open to work" / "Hiring now" badges in the header.
  ///
  /// Single profile → one badge, plain status, not tappable (nothing to focus).
  /// Both profiles  → both badges lit, because the home is showing jobs AND
  ///                  workers. Tapping one narrows the view to that side;
  ///                  tapping the lit one again returns to the unified view.
  /// No profile     → nothing; the dual setup card covers that case.
  /*
      The badges, as a list rather than a Row.

      They used to be a Row with its own spacing baked in, which meant putting
      anything beside them nested a Row inside a Row with a second, different
      gap — nothing lined up, and on a narrow screen it overflowed rather than
      wrapping. Handing back the pieces lets the caller lay everything out in
      one flow with one spacing.
  */
  List<Widget> _statusBadges(AppModeProvider appMode) {
    if (appMode.isNeutral) return const [];

    // Unfocused hybrid: both sides are on screen, so light both badges.
    final workerLit = appMode.isUnfocused || appMode.isWorkerMode;
    final employerLit = appMode.isUnfocused || appMode.isEmployerMode;

    return [
        if (appMode.canActivate(AppMode.worker))
          _statusBadge(
            label: 'Open to work',
            icon: Icons.check_circle,
            color: AppColors.success,
            isActive: workerLit,
            onTap: appMode.isHybrid
                ? () => appMode.isWorkerMode
                    ? appMode.clearFocus()
                    : appMode.setMode(AppMode.worker)
                : null,
          ),
        if (appMode.canActivate(AppMode.employer))
          _statusBadge(
            label: 'Hiring now',
            icon: Icons.business_center,
            color: AppColors.primary,
            isActive: employerLit,
            onTap: appMode.isHybrid
                ? () => appMode.isEmployerMode
                    ? appMode.clearFocus()
                    : appMode.setMode(AppMode.employer)
                : null,
          ),
    ];
  }

  Widget _statusBadge({
    required String label,
    required IconData icon,
    required Color color,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    // Inactive side is desaturated so the active mode is unambiguous at a glance.
    final foreground = isActive ? color : AppColors.neutral400;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.3)
                : AppColors.neutral300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Extract first name from full name
  String _getFirstName(String? fullName) {
    if (fullName == null || fullName.isEmpty) return 'User';
    return fullName.trim().split(' ').first;
  }

  /// What the home screen shows, driven by which profiles the account holds.
  ///
  /// This is the "unified" behaviour:
  ///   worker profile only   → JOBS only
  ///   employer profile only → WORKERS only
  ///   BOTH profiles         → HYBRID, jobs and workers together
  ///   neither               → everything, plus the dual setup card
  ///
  /// A hybrid user may optionally focus one side (see the header badges); that
  /// narrows the view until they clear it. Focus is never applied automatically
  /// — defaulting a dual-profile account to one side would defeat the point of
  /// a unified home.
  ///
  /// Which filter chips this account is even allowed to use.
  ///
  /// A worker-only account has no business browsing workers, and an
  /// employer-only account has no business browsing jobs — so those chips (and
  /// "All") are not offered at all. Only a hybrid account gets the full set.
  List<SearchFilter>? _allowedFilters(AppModeProvider appMode) {
    if (appMode.isHybrid) return null; // null = show every chip
    if (appMode.isNeutral) return null; // no profile yet: browsing is fine

    return appMode.isWorkerMode
        ? const [SearchFilter.showJobs]
        : const [SearchFilter.showWorkers];
  }

  /// What the home actually renders.
  ///
  /// The manual chips are a secondary override **within what the account is
  /// allowed to see** — they can never widen it. Previously `_searchFilter`
  /// short-circuited this method, which let an employer select "Jobs" or "All"
  /// and see the worker-side content.
  SearchFilter _getFilterForMode(AppModeProvider appMode) {
    // Single-profile account: the profile decides, full stop.
    final allowed = _allowedFilters(appMode);
    if (allowed != null) return allowed.first;

    // Hybrid that focused one side via the header badges.
    if (appMode.mode == AppMode.worker) return SearchFilter.showJobs;
    if (appMode.mode == AppMode.employer) return SearchFilter.showWorkers;

    // All, or a neutral account: both halves.
    if (appMode.mode == AppMode.all) return SearchFilter.all;

    return _searchFilter;
  }

  /// Build empty state card for incomplete profiles
  Widget _buildEmptyStateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Illustration
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_add_alt_1,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Heading. This card is only ever shown to an account with NO profile
          // yet, so the copy is about choosing a side — not about missing
          // recommendations, which made no sense before the user had picked one.
          Text(
            'Welcome to KAYA',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Subtext
          Text(
            'Set up a profile to get started. Looking for work? Create a worker profile. Hiring? Set up as an employer. You can do both.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 20),
          
          // Two Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, AppRouter.setupWorkerProfile),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Set up Worker Profile',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, AppRouter.setupEmployerProfile),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Set up as Employer',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<AuthProvider, AppModeProvider, JobProvider,
        ApplicationProvider>(
      builder: (context, authProvider, appMode, jobProvider,
          applicationProvider, _) {
        // Dual setup card only for accounts on neither side of the marketplace
        final shouldShowOverlay =
            _shouldShowProfileSetupPrompt(authProvider, appMode);

        // Content follows the active mode (worker → jobs, employer → workers)
        final currentFilter = _getFilterForMode(appMode);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            onRefresh: _refreshData,
            child: CustomScrollView(
              slivers: [
            // Enhanced Header with Gradient Background
            SliverAppBar(
              floating: true,
              snap: true,
              /*
                  Scaled, and roomier than it was.

                  A flat 160 for a header holding a greeting, a name, status
                  badges and a balance chip - all of which grow with the font
                  setting, and none of which the number knew about. It fitted
                  on the phone it was measured on and spilled on a narrower
                  one, where the same text needs another line.
              */
              expandedHeight: 184 * MediaQuery.textScalerOf(context).scale(1.0),
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false, // Remove back button
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.1),
                      AppColors.background,
                    ],
                  ),
                ),
                child: FlexibleSpaceBar(
                  background: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Welcome Text with Time-based Greeting + Name + Stats
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.neutral900,
                                      ),
                                      children: [
                                        TextSpan(text: _getGreeting()),
                                        TextSpan(
                                          text: ', ${_getFirstName(authProvider.user?['name'] as String?)}',
                                          style: TextStyle(color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Status badges double as the mode switch.
                                  // These were previously driven by two dead
                                  // local booleans that nothing ever changed;
                                  // they now reflect and control the active mode.
                                  /*
                                      The balance sits with the status badges
                                      rather than up in the icon row, which was
                                      built for two buttons — a third element
                                      there took width from the greeting and
                                      squeezed the name.

                                      Wrap rather than Row so everything shares
                                      one spacing and one baseline, and so a
                                      hybrid account with two badges and a
                                      balance drops onto a second line instead
                                      of overflowing.
                                  */
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      ..._statusBadges(appMode),
                                      const _BalanceChip(),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Action Icons
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.help_outline, size: 20),
                                    onPressed: _showFAQPopup,
                                    tooltip: 'FAQ',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const NotificationBell(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),



            // Unified Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: UnifiedSearchBar(
                  currentFilter: currentFilter,
                  onSearch: _updateSearchQuery,
                  onFilterChanged: _updateSearchFilter,
                  // Restricted to what this account may browse. A worker-only
                  // account sees only the Jobs chip, an employer-only account
                  // only Workers; "All" exists solely for hybrid accounts.
                  visibleFilters: _allowedFilters(appMode),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Empty State Card - When shown, this is the ONLY content
            if (shouldShowOverlay) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildEmptyStateCard(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],

            // ALL OTHER CONTENT - Only show when profile is complete or empty state is dismissed
            if (!shouldShowOverlay) ...[
              // Smart Categories based on filter
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getCategoryIcon(currentFilter),
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getCategoriesTitle(currentFilter),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.neutral900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildCategories(currentFilter),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Smart Action Prompts based on current filter
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSmartActionPrompts(currentFilter),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Your Activity Section — hidden entirely for accounts with no
              // profile yet, since there is no activity to summarise.
              if (!appMode.isNeutral)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.dashboard,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Your Activity',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.neutral900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Activity cards follow the profiles the account holds:
                      //   worker only   → My Applications
                      //   employer only → Active Jobs
                      //   both          → both
                      // These were previously hardcoded to 3 and 1 and shown to
                      // everyone regardless of role.
                      Row(
                        children: [
                          /*
                              Both conditions, not just the profile.

                              These were gated on having the profile alone, so
                              a hybrid saw both cards no matter which side they
                              had selected - the feed narrowed and the activity
                              did not. Now Worker shows what you applied to,
                              Employer shows what you posted, and All shows
                              both.
                          */
                          if (appMode.hasEmployerProfile &&
                              appMode.effectiveMode.showsEmployerSide) ...[
                            Expanded(
                              child: _ActivityCard(
                                icon: Icons.work,
                                iconColor: AppColors.accent,
                                count: jobProvider.jobs
                                    .where((j) =>
                                        j['status'] == 'open' ||
                                        j['status'] == 'in_progress')
                                    .length,
                                label: 'Active Jobs',
                                onTap: _navigateToActiveJobs,
                              ),
                            ),
                            if (appMode.hasWorkerProfile &&
                                appMode.effectiveMode.showsWorkerSide)
                              const SizedBox(width: 12),
                          ],
                          if (appMode.hasWorkerProfile &&
                              appMode.effectiveMode.showsWorkerSide)
                            Expanded(
                              child: _ActivityCard(
                                icon: Icons.description,
                                iconColor: AppColors.primary,
                                count: applicationProvider.applications
                                    .where((a) => a['status'] == 'pending')
                                    .length,
                                label: 'My Applications',
                                onTap: _navigateToPendingApplications,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // Jobs Near You Section (conditional based on filter)
              if (_showJobsSection(currentFilter)) ...[
                SliverToBoxAdapter(
                  child: JobsNearYouSection(
                    jobs: _filteredJobs,
                    isLoading: _isLoading,
                    userLocation: authProvider.user?['city'] as String?,
                    onSeeAll: () => AppRouter.toSearchJobs(context),
                    onJobTap: _onJobTap,
                    onJobContact: _contactEmployer,
                    // Match % now comes from each Job's server-computed
                    // matchScore (JobMatchService), not a client-side skill
                    // comparison — see CompactJobCard._matchPercent.
                    workerSkills: const [],
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],

              // People Who Can Help Section (conditional based on filter)
              if (_showWorkersSection(currentFilter)) ...[
                SliverToBoxAdapter(
                  child: PeopleWhoCanHelpSection(
                    workers: _filteredWorkers,
                    isLoading: _isLoading,
                    userLocation: authProvider.user?['city'] as String?,
                    // Same bound the fetch used, so the heading cannot drift
                    // away from what was actually asked for.
                    radiusKm: _nearbyRadiusKm,
                    onSeeAll: () => AppRouter.toSearchJobs(context),
                    onWorkerTap: _onWorkerTap,
                    onWorkerInvite: _inviteWorker,
                  ),
                ),
              ],
            ],

            // Error message if any
            if (_errorMessage != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.dangerColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppTheme.dangerColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: AppTheme.dangerColor),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _errorMessage = null),
                          child: Text('Dismiss', style: TextStyle(color: AppTheme.dangerColor)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
        },
    );
  }

  void _showFAQPopup() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 500),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.help_outline, color: AppColors.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Help',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.neutral900,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FAQItem(
                        question: 'How do I apply for jobs?',
                        answer: 'Browse the "Jobs Near You" section and tap "Apply" on jobs that interest you.',
                      ),
                      _FAQItem(
                        question: 'How do I find workers to hire?',
                        answer: 'Check out "People Who Can Help" section and tap "Invite" to send job invitations.',
                      ),
                      _FAQItem(
                        question: 'How do I filter content?',
                        answer: 'Use the "All | Jobs | People" filter in the search bar to focus on specific content.',
                      ),
                      _FAQItem(
                        question: 'What does verification mean?',
                        answer: 'Verified users have confirmed their identity and skills through our verification process.',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FAQScreen(),
                              ),
                            );
                          },
                          child: const Text('View All FAQs'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onCategoryTap(String category) {
    AppRouter.toSearchJobs(context, query: category);
  }

  void _onJobTap(Job job) {
    AppRouter.toJobDetails(context, job);
  }

  /// Opens the job so the worker can read it and apply.
  ///
  /// This popped a dialog offering to "Message" the employer and then showed
  /// "Contacting employer for X" — no navigation, no conversation created.
  /// Messaging an employer is not possible before applying anyway: a
  /// conversation only exists once an application is accepted, which is the
  /// rule that stops the inbox becoming a cold-contact channel.
  void _contactEmployer(Job job) {
    Navigator.pushNamed(context, '/job-details', arguments: {'jobId': job.id});
  }

  void _onWorkerTap(WorkerProfile worker) {
    AppRouter.toWorkerProfile(context, worker);
  }

  /// Sends the worker to their profile, where the invitation is actually made.
  ///
  /// This asked "Invite X to apply for a job?" — without ever asking *which*
  /// job — and then reported "Invitation sent". Nothing was sent, and the
  /// worker saw nothing, while the receiving half of invitations was fully
  /// built. Choosing a job is not optional, so the flow belongs on the profile
  /// screen that can present one.
  void _inviteWorker(WorkerProfile worker) {
    AppRouter.toWorkerProfile(context, worker);
  }


  /// Get categories title based on current filter
  String _getCategoriesTitle(SearchFilter filter) {
    switch (filter) {
      case SearchFilter.showWorkers:
        return 'Job Categories';
      case SearchFilter.showJobs:
        return 'Worker Skills';
      case SearchFilter.all:
        return 'Browse Categories';
    }
  }

  /// Build appropriate categories based on current filter
  Widget _buildCategories(SearchFilter filter) {
    // When showing jobs (worker view) — keep original full-width Row layout with Expanded
    if (filter == SearchFilter.showJobs) {
      return Row(
        children: [
          Expanded(child: _CategoryButton(icon: Icons.build,    label: 'Skilled',   color: AppColors.primary,  onTap: () => _onCategoryTap('Skilled'))),
          const SizedBox(width: 8),
          Expanded(child: _CategoryButton(icon: Icons.verified, label: 'Verified',  color: AppColors.success,  onTap: () => _onCategoryTap('Verified'))),
          const SizedBox(width: 8),
          Expanded(child: _CategoryButton(icon: Icons.star,     label: 'Top Rated', color: AppColors.accent,   onTap: () => _onCategoryTap('Top Rated'))),
          const SizedBox(width: 8),
          Expanded(child: _CategoryButton(icon: Icons.schedule, label: 'Available', color: AppColors.success,  onTap: () => _onCategoryTap('Available'))),
        ],
      );
    }

    /*
        Categories come from the server, not from a list in this file.

        The hardcoded version carried an "Other" entry that does not exist in
        the categories table, and any category added in the admin panel would
        never have appeared here. Icons stay client-side because the table has
        no icon column; anything unmapped falls back to a generic tool.
    */
    final categories = context.watch<WorkerProfileProvider>().categories;

    // The strip and the empty placeholder have to agree, or the row jumps
    // height the moment the categories finish loading.
    final rowHeight = 120 * MediaQuery.textScalerOf(context).scale(1.0);

    if (categories.isEmpty) {
      return SizedBox(height: rowHeight);
    }

    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final category = categories[i];
          return _CategoryButton(
            icon: _iconForCategory(category.name),
            label: category.name,
            color: AppColors.categoryIcon,
            // Fixed here on purpose: in a horizontal list nothing else is
            // deciding, and equal widths are what keep the icons aligned.
            width: 84,
            onTap: () => _onCategoryTap(category.name),
          );
        },
      ),
    );
  }

  /// Maps a category name to an icon. Unknown names get a generic tool rather
  /// than a blank space, so a category added later still renders.
  static IconData _iconForCategory(String name) {
    const icons = {
      'plumbing': Icons.plumbing,
      'electrical': Icons.electrical_services,
      'painting': Icons.format_paint,
      'carpentry': Icons.carpenter,
      'construction': Icons.construction,
      'hvac': Icons.ac_unit,
      'landscaping': Icons.grass,
      'cleaning': Icons.cleaning_services,
      'roofing': Icons.roofing,
      'flooring': Icons.layers,
      'automotive': Icons.car_repair,
      'appliance repair': Icons.kitchen,
      'security': Icons.security,
      'moving': Icons.local_shipping,
      'pest control': Icons.bug_report,
      'pool services': Icons.pool,
      'delivery': Icons.delivery_dining,
    };
    return icons[name.toLowerCase().trim()] ?? Icons.build;
  }

  /// Build smart action prompts based on current filter context
  Widget _buildSmartActionPrompts(SearchFilter filter) {
    if (filter == SearchFilter.showJobs) {
      // When viewing jobs (WORKER mode) - NO button needed, workers browse jobs
      return const SizedBox.shrink(); // Remove button entirely for workers
    } else if (filter == SearchFilter.showWorkers) {
      // When viewing workers (EMPLOYER mode) - show Post a Job action
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.accent.withValues(alpha: 0.1), Colors.transparent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.work_outline, color: AppColors.accent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need to hire someone?',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.neutral900,
                    ),
                  ),
                  Text(
                    'Post your job to find skilled workers',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.neutral600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => AppRouter.toPostJob(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Post a Job'),
            ),
          ],
        ),
      );
    } else {
      // When viewing all - show clear, specific actions with full color buttons
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => AppRouter.toPostJob(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_business, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Post a Job',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Hire workers',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
  }

  // Simple navigation methods - always go to screens
  void _navigateToActiveJobs() {
    Navigator.pushNamed(context, '/manage-jobs');
  }

  void _navigateToPendingApplications() {
    Navigator.pushNamed(context, '/applications');
  }

  /// Get time-based greeting
  String _getGreeting() {
    final hour = DateTime.now().hour;

    /*
        The small hours are not morning.

        Anything before noon used to count as morning, so at half past midnight
        the app said Good Morning to somebody who had not been to bed. Hours
        zero to four belong to the night before, which is how people actually
        talk about them.
    */
    if (hour < 5) return 'Good Evening';
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  /// Get category icon based on filter
  IconData _getCategoryIcon(SearchFilter filter) {
    switch (filter) {
      case SearchFilter.showJobs:
        return Icons.work_outline;
      case SearchFilter.showWorkers:
        return Icons.people_outline;
      case SearchFilter.all:
        return Icons.dashboard_outlined;
    }
  }
}

class _CategoryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  /*
      Null when the parent is already deciding.

      This used to be a hardcoded 84 in every case, including the four tiles
      below that sit in a Row of Expandeds. Expanded hands each of them a
      quarter of the screen - about 74 pixels on a small phone - and the tile
      then demanded 84 regardless, so it ran off the right and its label,
      squeezed into less width than it was laid out for, wrapped to a third
      line and spilled out of the bottom. Both of the overflows reported on
      the home screen, from one number.

      The horizontal list still passes a width, because there the tile has to
      choose its own.
  */
  final double? width;

  const _CategoryButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    /*
        Fixed width, deliberately.

        These sit in a horizontal list, where an unsized tile takes its width
        from its widest child — the label. "Appliance Repair" produced a wide
        tile and "Moving" a narrow one, and because the icon stayed 50px in
        both, it read as oversized in the narrow tiles and lost in the wide
        ones. The row looked like the icons were different sizes when only the
        words were.

        84 fits "Appliance Repair" on two lines at 11.5px without clipping.
    */
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            /*
                Two lines of label, whatever size those lines are.

                The height is what keeps a one-word tile and a two-word tile
                the same size, so every icon in the row sits on one baseline —
                that part was right. Writing it as a flat 30 was not: the box
                stayed 30 while the text inside grew with the font setting, so
                at a larger size "Appliance Repair" lost its second line and the
                labels quietly went missing. Scaling it keeps the alignment and
                keeps the words.
            */
            SizedBox(
              height: 34 * MediaQuery.textScalerOf(context).scale(1.0),
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  height: 1.25,
                  color: AppColors.neutral800,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FAQItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.neutral700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final int count;
  final String label;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.icon,
    required this.iconColor,
    required this.count,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.neutral200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.neutral500,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.neutral900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.neutral600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
/// The credit balance, in the home header.
///
/// Here rather than only in Profile because this is where people are when they
/// decide to apply for something, and a balance they have to go looking for is
/// one they discover is empty at the worst possible moment — halfway through
/// tapping Apply.
///
/// Loads once and then reads whatever the provider holds, so applying for a
/// job updates it without this widget knowing anything about applications.
class _BalanceChip extends StatefulWidget {
  const _BalanceChip();

  @override
  State<_BalanceChip> createState() => _BalanceChipState();
}

class _BalanceChipState extends State<_BalanceChip> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CreditsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final credits = context.watch<CreditsProvider>();

    // Nothing at all until the number is known. A chip that says zero and then
    // corrects itself is worse than one that arrives a moment later, because
    // the first thing it does is tell you something untrue about your money.
    if (!credits.hasLoadedOnce) return const SizedBox.shrink();

    // Shaped like the mode badges it now sits beside, rather than like the
    // shadowed icon buttons it used to sit between.
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await Navigator.pushNamed(context, AppRouter.wallet);
        if (context.mounted) context.read<CreditsProvider>().refresh();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Credits.icon, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '${credits.balance}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                /*
                    A dot when free credits are waiting.

                    This is the whole reason claiming beats depositing: the
                    chip is what tells somebody there is something to collect,
                    on the screen they are already looking at. Without it they
                    would have to think to open the wallet to find out, which
                    nobody does.
                */
                if (credits.hasSomethingToClaim) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ),
    );
  }
}