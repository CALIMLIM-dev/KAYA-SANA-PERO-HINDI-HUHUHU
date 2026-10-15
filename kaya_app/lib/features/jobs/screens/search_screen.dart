import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_mode.dart';
import '../../../core/navigation/app_router.dart';
import '../../../data/models/job_model.dart';
import '../../../data/models/worker_profile_model.dart';
import '../../../data/services/api_client.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/worker_browse_provider.dart';
import '../../../providers/worker_profile_provider.dart';
import '../widgets/job_list_card.dart';
import '../widgets/place_picker_sheet.dart';
import '../widgets/worker_card.dart';

/// Search: jobs for a worker, workers for an employer, either for a hybrid.
///
/// Rebuilt in October 2026. What changed, and why:
///
/// - Every filter is asked of the server. Pay, rating and "verified" used to
///   be applied in the app to the one page of twenty the server had already
///   cut, so a match on page two never appeared and a filtered list could
///   shrink to nothing while more existed. The job "verified" filter also
///   read the wrong field: whether the job asks for a verified worker, not
///   whether the employer is one.
/// - The filters are the ones that decide a search on each side. Jobs: the
///   trade, where, pay, when it starts, urgent, a verified employer. Workers:
///   the trade and a skill in it, where, rating, verified.
/// - More than twenty results can be reached (Show more), the count is the
///   server's total, sort is one tap from the count, recent searches come
///   back, and an empty result says what is narrowing it and offers to undo
///   that rather than "try a different search term".
/// - The filters stay in a bottom sheet: the user chose that for this screen.
///   It searches again however it is closed; it used to search only on its
///   button, so swiping it away left the list answering the old question.
class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  /*
      Opened on a category rather than a search term.

      The home category strip used to push the category's *name* into the
      search box, so tapping Plumbing searched every job title for the word
      "plumbing" - which misses a job called "Fix leaking pipes" and matches
      one called "Plumbing supplies delivery". The id filters server-side.
  */
  final int? initialCategoryId;

  /// 'Jobs' or 'Workers'. Null keeps the default, which is whichever side the
  /// account is acting as.
  final String? initialType;

  const SearchScreen({
    super.key,
    this.initialQuery,
    this.initialCategoryId,
    this.initialType,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  String _searchType = 'Jobs'; // 'Jobs' or 'Workers'
  int? _categoryId;

  /// Workers only: one skill inside the chosen trade.
  int? _skillId;

  /*
      Where. A picked place (a city matches every barangay in it), or a
      distance from the account's own place - one or the other, since "in
      Dagupan" and "within 5 km of me" cannot both be meant.
  */
  int? _placeId;
  String? _placeLabel;
  double? _radiusKm;

  // Jobs.
  double? _payMin;
  int? _startsWithin; // days from today: 0, 7, 30
  bool _urgentOnly = false;

  // Workers.
  double? _minRating;

  bool _verifiedOnly = false;
  String _sort = 'best';

  List<String> _recent = const [];
  bool _loadingMore = false;

  /// Skills per trade, fetched once each, for the worker skill row.
  final Map<int, List<(int, String)>> _skillsByCategory = {};

  static const _jobSorts = {'best': 'Best Match', 'nearest': 'Nearest', 'pay': 'Highest Pay'};
  static const _workerSorts = {
    'best': 'Best Match',
    'rating': 'Top Rated',
    'jobs': 'Most Jobs',
    'nearest': 'Nearest',
    'newest': 'Newest',
  };

  /// A worker cannot apply past 10 km (WorkingDistance), so a wider radius
  /// would only list work they cannot take.
  static const _jobDistances = [2.0, 5.0, 10.0];
  static const _workerDistances = [5.0, 10.0, 25.0, 50.0];
  static const _pays = [500.0, 1000.0, 2000.0, 5000.0];
  static const _starts = {0: 'Today', 7: 'This Week', 30: 'This Month'};
  static const _ratings = [3.0, 4.0, 4.5];

  bool get _jobs => _searchType == 'Jobs';
  Map<String, String> get _sorts => _jobs ? _jobSorts : _workerSorts;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }
    _categoryId = widget.initialCategoryId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      /*
          Open on what this account can actually search for.

          A single-role account has no choice to make, so the side is fixed
          and the Jobs/Workers control is not drawn. A hybrid keeps it,
          seeded from the mode they are in.
      */
      final appMode = context.read<AppModeProvider>();
      _scopedFor = (worker: appMode.hasWorkerProfile, employer: appMode.hasEmployerProfile);
      _searchType = _typeFor(appMode);

      /*
          The account's own town, without being asked for it. The city rather
          than the barangay, since a job two streets away is usually filed
          under the city. Removable from its chip.
      */
      final stored = context.read<AuthProvider>().user?['known_location'] as Map<String, dynamic>?;
      final known = (stored?['city'] as Map<String, dynamic>?) ?? stored;
      if (_placeId == null && known != null && known['location_id'] != null) {
        _placeId = (known['location_id'] as num).toInt();
        _placeLabel = (known['label'] ?? '').toString();
      }

      context.read<WorkerProfileProvider>().fetchCategories();
      if (!_jobs && _categoryId != null) _loadSkills(_categoryId!);
      _loadRecent();
      _runSearch();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ─── searching ─────────────────────────────────────────────────────────────

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  Future<void> _runSearch({int page = 1}) async {
    if (!mounted) return;
    final query = _searchController.text.trim();

    if (_jobs) {
      await context.read<JobProvider>().fetchPublicJobs(
            search: query,
            categoryId: _categoryId,
            locationId: _placeId,
            radiusKm: _radiusKm,
            urgentOnly: _urgentOnly,
            payMin: _payMin,
            verifiedOnly: _verifiedOnly,
            startsWithinDays: _startsWithin,
            sort: _sort == 'best' ? null : _sort,
            page: page,
          );
    } else {
      await context.read<WorkerBrowseProvider>().fetchWorkers(
            q: query,
            categoryId: _categoryId,
            skillId: _skillId,
            locationId: _placeId,
            radiusKm: _radiusKm,
            sort: _sort,
            verifiedOnly: _verifiedOnly,
            minRating: _minRating,
            page: page,
          );
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);

    final next = _jobs
        ? context.read<JobProvider>().publicPage + 1
        : context.read<WorkerBrowseProvider>().workersPage + 1;
    await _runSearch(page: next);

    if (mounted) setState(() => _loadingMore = false);
  }

  /// Changes the search and asks again.
  void _set(VoidCallback change) {
    setState(change);
    _runSearch();
  }

  Future<void> _loadSkills(int categoryId) async {
    if (_skillsByCategory.containsKey(categoryId)) return;
    try {
      final res = await ApiClient().get('/skills', queryParameters: {'category_id': categoryId});
      final rows = (res.data['data'] as List?) ?? const [];
      if (!mounted) return;
      setState(() => _skillsByCategory[categoryId] = [
            for (final r in rows.cast<Map>())
              if (r['id'] != null) ((r['id'] as num).toInt(), (r['name'] ?? '').toString()),
          ]);
    } catch (_) {
      // No row of skills; the trade filter still works on its own.
    }
  }

  // ─── recent searches ───────────────────────────────────────────────────────

  String get _recentKey => 'search_recent_${_jobs ? 'jobs' : 'workers'}';

  Future<void> _loadRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _recent = prefs.getStringList(_recentKey) ?? const []);
    } catch (_) {
      // Recent searches are a convenience; without storage there are none.
    }
  }

  Future<void> _saveRecent(List<String> next) async {
    setState(() => _recent = next);
    try {
      (await SharedPreferences.getInstance()).setStringList(_recentKey, next);
    } catch (_) {}
  }

  /// Kept when a search is submitted or one of its results is opened, so
  /// the list holds what was actually looked for, not every keystroke.
  void _remember() {
    final q = _searchController.text.trim();
    if (q.length < 2) return;
    _saveRecent([q, ..._recent.where((r) => r.toLowerCase() != q.toLowerCase())].take(6).toList());
  }

  // ─── which side ────────────────────────────────────────────────────────────

  /// Which side this account searches: the one it has, or for a hybrid the
  /// mode it is in. An explicit ask wins, as long as the account has that
  /// side at all.
  String _typeFor(AppModeProvider appMode) {
    var type = appMode.hasEmployerProfile && !appMode.hasWorkerProfile
        ? 'Workers'
        : appMode.hasWorkerProfile && !appMode.hasEmployerProfile
            ? 'Jobs'
            : appMode.effectiveMode == AppMode.employer
                ? 'Workers'
                : 'Jobs';

    if (widget.initialType == 'Workers' && appMode.hasEmployerProfile) {
      type = 'Workers';
    } else if (widget.initialType == 'Jobs' && appMode.hasWorkerProfile) {
      type = 'Jobs';
    }
    return type;
  }

  /*
      The profiles the side was chosen for. The tab is built as the app opens,
      before a new account has set anything up, so the side is chosen again
      whenever a profile appears or goes.
  */
  ({bool worker, bool employer})? _scopedFor;

  void _rescopeIfProfilesChanged(AppModeProvider appMode) {
    final now = (worker: appMode.hasWorkerProfile, employer: appMode.hasEmployerProfile);
    if (_scopedFor == null || _scopedFor == now) return;
    _scopedFor = now;

    final type = _typeFor(appMode);
    if (type == _searchType) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _switchTo(type);
    });
  }

  /// The two sides share the query and the place; everything else means
  /// something different on each, so it starts over.
  void _switchTo(String type) {
    setState(() {
      _searchType = type;
      _sort = 'best';
      _categoryId = null;
      _skillId = null;
      _radiusKm = null;
      _payMin = null;
      _startsWithin = null;
      _minRating = null;
      _urgentOnly = false;
      _verifiedOnly = false;
    });
    _loadRecent();
    _runSearch();
  }

  // ─── filters as words ──────────────────────────────────────────────────────

  String _peso(double v) {
    final s = v.toInt().toString();
    final grouped = s.length > 3 ? '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}' : s;
    return '₱$grouped';
  }

  String _km(double v) => '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)} km';

  String _rating(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

  /// Every filter that is on, as a label and a way to take it off. The chips
  /// above the list, the count on the filter button and the empty state all
  /// read this one list, so they cannot disagree.
  List<(String, VoidCallback)> _activeFilters() => [
        if (_placeId != null) (_placeLabel ?? 'Place', () { _placeId = null; _placeLabel = null; }),
        if (_radiusKm != null) ('Within ${_km(_radiusKm!)}', () => _radiusKm = null),
        if (_jobs && _payMin != null) ('${_peso(_payMin!)} and up', () => _payMin = null),
        if (_jobs && _startsWithin != null) ('Starts ${_starts[_startsWithin]!.toLowerCase()}', () => _startsWithin = null),
        if (!_jobs && _minRating != null) ('${_rating(_minRating!)}+ Rating', () => _minRating = null),
        if (_verifiedOnly) (_jobs ? 'Verified Employers' : 'Verified Workers', () => _verifiedOnly = false),
        if (_jobs && _urgentOnly) ('Urgent', () => _urgentOnly = false),
      ];

  // ─── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _rescopeIfProfilesChanged(context.watch<AppModeProvider>());

    return Consumer3<JobProvider, WorkerBrowseProvider, WorkerProfileProvider>(
      builder: (context, jobProvider, workerBrowse, taxonomy, _) {
        final jobs = jobProvider.publicJobs;
        final workers = workerBrowse.workers;
        final isLoading = _jobs ? jobProvider.isPublicLoading : workerBrowse.isLoading;
        final error = _jobs ? jobProvider.publicErrorMessage : workerBrowse.errorMessage;
        final shown = _jobs ? jobs.length : workers.length;
        final hasMore = _jobs ? jobProvider.hasMorePublicJobs : workerBrowse.hasMoreWorkers;
        final total = _jobs ? jobProvider.publicTotal : workerBrowse.workersTotal;
        final filters = _activeFilters();
        final skills = !_jobs && _categoryId != null ? _skillsByCategory[_categoryId] : null;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              // The app's blue header, with the field and the filter button.
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: AppColors.primary,
                surfaceTintColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                titleSpacing: 16,
                title: Row(
                  children: [
                    Expanded(child: _searchField()),
                    const SizedBox(width: 10),
                    _filterButton(filters.length),
                  ],
                ),
              ),

              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Only a hybrid has a side to choose.
                      if (context.watch<AppModeProvider>().isHybrid)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppColors.neutral100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [_segment('Jobs'), _segment('Workers')]),
                          ),
                        ),

                      // The trade.
                      _chipRow([
                        _choice('All', _categoryId == null, () => _set(() {
                              _categoryId = null;
                              _skillId = null;
                            })),
                        for (final c in taxonomy.categories)
                          _choice(c.name, _categoryId == c.id, () {
                            _set(() {
                              _categoryId = _categoryId == c.id ? null : c.id;
                              _skillId = null;
                            });
                            if (!_jobs && _categoryId != null) _loadSkills(_categoryId!);
                          }),
                      ]),

                      // A skill inside it, for workers.
                      if (skills != null && skills.isNotEmpty)
                        _chipRow([
                          _choice('Any Skill', _skillId == null, () => _set(() => _skillId = null), quiet: true),
                          for (final (id, name) in skills)
                            _choice(name, _skillId == id, () => _set(() => _skillId = _skillId == id ? null : id), quiet: true),
                        ]),

                      // What was looked for before, while nothing is typed.
                      if (_recent.isNotEmpty && _searchController.text.isEmpty) _recentRow(),

                      // What is narrowing the list, each removable.
                      if (filters.isNotEmpty)
                        _chipRow([
                          for (final (label, clear) in filters) _removable(label, () => _set(clear)),
                        ]),
                    ],
                  ),
                ),
              ),

              // The count, and the order it is in.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isLoading && shown == 0
                              ? 'Searching'
                              : _countLabel(hasMore ? total : shown),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.neutral500),
                        ),
                      ),
                      _sortButton(),
                    ],
                  ),
                ),
              ),

              if (isLoading && shown == 0)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error != null && shown == 0)
                SliverFillRemaining(hasScrollBody: false, child: _errorState(error))
              else if (shown == 0)
                SliverFillRemaining(hasScrollBody: false, child: _emptyState(filters))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _jobs ? _jobCard(jobs[index]) : _workerCard(workers[index]),
                      ),
                      childCount: shown,
                    ),
                  ),
                ),

              if (shown > 0 && hasMore)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _loadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : OutlinedButton(onPressed: _loadMore, child: const Text('Show More')),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );
  }

  // ─── header pieces ─────────────────────────────────────────────────────────

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: _jobs ? 'Search jobs' : 'Search workers',
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.neutral400),
        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.neutral400),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.neutral400),
                tooltip: 'Clear',
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                  _onQueryChanged('');
                },
              ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      onChanged: (value) {
        setState(() {}); // the clear button and the recent row follow the text
        _onQueryChanged(value);
      },
      onSubmitted: (_) {
        _debounce?.cancel();
        _remember();
        _runSearch();
      },
    );
  }

  Widget _filterButton(int count) {
    final active = count > 0;

    return Semantics(
      button: true,
      label: active ? 'Filters, $count on' : 'Filters',
      child: GestureDetector(
        onTap: _showFilterSheet,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.tune, size: 19, color: active ? AppColors.primary : Colors.white),
              if (active) ...[
                const SizedBox(width: 6),
                Text('$count',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _segment(String type) {
    final selected = _searchType == type;

    return Expanded(
      child: GestureDetector(
        onTap: selected ? null : () => _switchTo(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 3, offset: const Offset(0, 1))]
                : null,
          ),
          child: Text(
            type,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.neutral900 : AppColors.neutral500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipRow(List<Widget> chips) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
      child: Row(children: chips),
    );
  }

  /// A choice in a row. [quiet] for the second row under the trade, so the
  /// two rows do not read as equals.
  Widget _choice(String label, bool selected, VoidCallback onTap, {bool quiet = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: quiet ? 5 : 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? AppColors.primary : AppColors.neutral300),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: quiet ? 12 : 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.neutral700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _removable(String label, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 7, 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
              const SizedBox(width: 4),
              const Icon(Icons.close, size: 13, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
      child: Row(
        children: [
          const Icon(Icons.history, size: 16, color: AppColors.neutral400),
          const SizedBox(width: 6),
          for (final q in _recent)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () {
                  _searchController.text = q;
                  _remember();
                  setState(() {});
                  _runSearch();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(q, style: const TextStyle(fontSize: 12.5, color: AppColors.neutral700)),
                      InkWell(
                        onTap: () => _saveRecent(_recent.where((r) => r != q).toList()),
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(3),
                          child: Icon(Icons.close, size: 13, color: AppColors.neutral400),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          TextButton(
            onPressed: () => _saveRecent(const []),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.neutral500,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 12.5),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  /// The order, one tap from the count rather than inside the filters.
  Widget _sortButton() {
    return PopupMenuButton<String>(
      initialValue: _sort,
      tooltip: 'Sort',
      onSelected: (value) => _set(() => _sort = value),
      itemBuilder: (_) => [
        for (final e in _sorts.entries) PopupMenuItem(value: e.key, child: Text(e.value)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert, size: 16, color: AppColors.neutral600),
            const SizedBox(width: 4),
            Text(_sorts[_sort] ?? 'Best Match',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.neutral700)),
          ],
        ),
      ),
    );
  }

  // ─── results ───────────────────────────────────────────────────────────────

  String _countLabel(int n) =>
      '$n ${_jobs ? (n == 1 ? 'job' : 'jobs') : (n == 1 ? 'worker' : 'workers')}';

  Widget _jobCard(Job job) {
    return JobListCard(
      job: job,
      onTap: () {
        _remember();
        AppRouter.push(context, '/job-details', arguments: {'jobId': job.id});
      },
      onToggleSave: () => context.read<JobProvider>().toggleSave(job.id, job.isSaved),
    );
  }

  Widget _workerCard(WorkerProfile worker) {
    return WorkerCard(
      name: worker.name,
      primarySkill: worker.primarySkill,
      location: worker.location ?? 'Location not set',
      rating: worker.reviewCount > 0 ? worker.rating.toStringAsFixed(1) : '',
      reviews: worker.reviewCount > 0 ? '(${worker.reviewCount} reviews)' : '',
      isAvailable: worker.isAvailable,
      isVerified: worker.isVerified,
      verification: worker.verification,
      skills: worker.skills,
      distanceKm: worker.distance,
      distanceLabel: worker.distanceLabel,
      rateLabel: worker.rateLabel,
      imageUrl: worker.profileImageUrl,
      isBoosted: worker.isBoosted,
      onTap: () {
        _remember();
        AppRouter.push(context, '/worker-profile', arguments: {'workerId': worker.userId ?? worker.id});
      },
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.neutral300),
            const SizedBox(height: 14),
            const Text('Could Not Load Results',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.neutral700)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: AppColors.neutral500)),
            const SizedBox(height: 18),
            OutlinedButton(onPressed: _runSearch, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  /*
      Nothing found, and why.

      "Try a different search term" was the whole of it, under a list that
      was empty because of a town picked automatically or a filter set last
      week. It names what is narrowing the search now and undoes it in a tap.
  */
  Widget _emptyState(List<(String, VoidCallback)> filters) {
    final typed = _searchController.text.trim();
    final narrowing = [
      if (typed.isNotEmpty) '"$typed"',
      if (_categoryId != null)
        context.read<WorkerProfileProvider>().categories.where((c) => c.id == _categoryId).firstOrNull?.name ?? 'one trade',
      for (final (label, _) in filters) label,
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: AppColors.neutral300),
            const SizedBox(height: 14),
            Text(_jobs ? 'No Jobs Match' : 'No Workers Match',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.neutral700)),
            const SizedBox(height: 6),
            Text(
              narrowing.isEmpty
                  ? (_jobs ? 'There are no open jobs here right now.' : 'There are no workers listed here yet.')
                  : 'Searching for ${narrowing.join(', ')}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.neutral500, height: 1.4),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (_placeId != null || _radiusKm != null)
                  OutlinedButton(
                    onPressed: () => _set(() {
                      _placeId = null;
                      _placeLabel = null;
                      _radiusKm = null;
                    }),
                    child: const Text('Search Everywhere'),
                  ),
                if (filters.isNotEmpty || _categoryId != null || typed.isNotEmpty)
                  TextButton(
                    onPressed: () => _set(() {
                      _searchController.clear();
                      _categoryId = null;
                      _skillId = null;
                      _clearFilters();
                    }),
                    child: const Text('Clear Search and Filters'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _clearFilters() {
    _placeId = null;
    _placeLabel = null;
    _radiusKm = null;
    _payMin = null;
    _startsWithin = null;
    _minRating = null;
    _verifiedOnly = false;
    _urgentOnly = false;
  }

  // ─── the filter sheet ──────────────────────────────────────────────────────

  /*
      A bottom sheet, which the user chose for this screen.

      Changes land on the screen's own state as they are made, and the
      search runs again whenever the sheet closes - by its button, a swipe
      or a tap outside. It used to run only on the button.
  */
  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          void change(VoidCallback fn) => setSheet(() => setState(fn));

          final distances = _jobs ? _jobDistances : _workerDistances;

          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Filters',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.neutral900)),
                      ),
                      TextButton(
                        onPressed: () => change(_clearFilters),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    children: [
                      _sheetLabel('Where'),
                      InkWell(
                        onTap: () async {
                          final picked = await showPlacePickerSheet(sheetContext, current: _placeLabel);
                          if (picked == null) return;
                          change(() {
                            _placeId = picked.id;
                            _placeLabel = picked.displayName;
                            _radiusKm = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.neutral300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 18, color: AppColors.neutral500),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _placeLabel ?? 'Any Town',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: _placeId == null ? AppColors.neutral500 : AppColors.neutral900,
                                  ),
                                ),
                              ),
                              if (_placeId != null)
                                GestureDetector(
                                  onTap: () => change(() {
                                    _placeId = null;
                                    _placeLabel = null;
                                  }),
                                  child: const Icon(Icons.close, size: 16, color: AppColors.neutral500),
                                )
                              else
                                const Icon(Icons.expand_more, size: 18, color: AppColors.neutral500),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text('Or within this distance of your place',
                          style: TextStyle(fontSize: 12.5, color: AppColors.neutral500)),
                      const SizedBox(height: 8),
                      _sheetChoices<double>(
                        [for (final d in distances) (d, _km(d))],
                        _radiusKm,
                        (v) => change(() {
                          _radiusKm = v;
                          if (v != null) {
                            _placeId = null;
                            _placeLabel = null;
                          }
                        }),
                        anyLabel: 'Any',
                      ),
                      if (_jobs)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('You can apply to work up to 10 km from your place.',
                              style: TextStyle(fontSize: 12, color: AppColors.neutral500)),
                        ),

                      if (_jobs) ...[
                        const SizedBox(height: 20),
                        _sheetLabel('Pays at Least'),
                        _sheetChoices<double>(
                          [for (final p in _pays) (p, _peso(p))],
                          _payMin,
                          (v) => change(() => _payMin = v),
                          anyLabel: 'Any Pay',
                        ),
                        const SizedBox(height: 20),
                        _sheetLabel('Starts'),
                        _sheetChoices<int>(
                          [for (final e in _starts.entries) (e.key, e.value)],
                          _startsWithin,
                          (v) => change(() => _startsWithin = v),
                          anyLabel: 'Any Time',
                        ),
                      ] else ...[
                        const SizedBox(height: 20),
                        _sheetLabel('Rating'),
                        _sheetChoices<double>(
                          [for (final r in _ratings) (r, '${_rating(r)}+')],
                          _minRating,
                          (v) => change(() => _minRating = v),
                          anyLabel: 'Any',
                        ),
                      ],

                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_jobs ? 'Verified Employers Only' : 'Verified Workers Only',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        value: _verifiedOnly,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => change(() => _verifiedOnly = v),
                      ),
                      if (_jobs)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Urgent Jobs Only',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          value: _urgentOnly,
                          activeThumbColor: AppColors.primary,
                          onChanged: (v) => change(() => _urgentOnly = v),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Show Results', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(_runSearch);
  }

  Widget _sheetLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
      );

  /// One row of choices with an "any" first; null is "any".
  Widget _sheetChoices<T>(List<(T, String)> options, T? value, ValueChanged<T?> onPick, {required String anyLabel}) {
    Widget chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          selectedColor: AppColors.primary.withValues(alpha: 0.12),
          backgroundColor: Colors.white,
          side: BorderSide(color: selected ? AppColors.primary : AppColors.neutral300),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.neutral700,
          ),
        );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(anyLabel, value == null, () => onPick(null)),
        for (final (v, label) in options) chip(label, value == v, () => onPick(v)),
      ],
    );
  }
}
