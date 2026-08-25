import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../data/models/job_model.dart';
import '../../../data/models/worker_profile_model.dart';
import '../../../core/constants/app_mode.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/worker_browse_provider.dart';
import '../../../providers/worker_profile_provider.dart';
import '../widgets/featured_job_card.dart';
import '../widgets/worker_card.dart';

/// Search Screen — Jobs and Workers, backed by GET /jobs and GET /workers.
///
/// Previously every result on this screen (titles, companies, salaries, worker
/// names, skills, "156 jobs found") was generated from an index via
/// `_getJobTitle(index)`-style helpers cycling through five fake names. No
/// search box, filter, or count reflected anything real.
class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  int? _selectedCategoryId;
  String? _selectedLocation;
  String _selectedSortBy = 'Recent';
  String _searchType = 'Jobs'; // 'Jobs' or 'Workers'

  // Filter state
  double _minSalary = 0;
  double _maxSalary = 5000;
  double _minRating = 0;
  bool _verifiedOnly = false;
  bool _urgentOnly = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      /*
          Open on what the current mode is for.

          This defaulted to 'Jobs' for everyone, so an employer opening Search
          was handed a list of jobs to apply to and had to notice the toggle to
          get the workers they came for. The toggle stays — a hybrid account
          legitimately wants both — but it starts on the side the person is
          actually acting as.
      */
      final mode = context.read<AppModeProvider>().effectiveMode;
      if (mode == AppMode.employer) {
        _searchType = 'Workers';
      }

      context.read<WorkerProfileProvider>().fetchCategories();
      _runSearch();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  Future<void> _runSearch() async {
    if (!mounted) return;
    final query = _searchController.text.trim();

    if (_searchType == 'Jobs') {
      await context.read<JobProvider>().fetchPublicJobs(
            search: query,
            categoryId: _selectedCategoryId,
          );
    } else {
      // Pay is a column on the worker profile, so it filters server-side.
      // Doing it here would silently drop workers who never stated a rate
      // without the employer knowing a filter was responsible.
      final bounded = _minSalary > 0 || _maxSalary < 5000;

      await context.read<WorkerBrowseProvider>().fetchWorkers(
            q: query,
            categoryId: _selectedCategoryId,
            rateMin: bounded && _minSalary > 0 ? _minSalary : null,
            rateMax: bounded && _maxSalary < 5000 ? _maxSalary : null,
          );
    }
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedLocation != null && _selectedLocation != 'All') count++;
    if (_minSalary > 0 || _maxSalary < 5000) count++;
    if (_minRating > 0) count++;
    if (_verifiedOnly) count++;
    if (_urgentOnly) count++;
    return count;
  }

  /// Filters already fetch by category/query server-side; these remaining
  /// facets (rating, verified, urgent, price range, location text) are applied
  /// client-side since they are cheap over an already-small result set.
  List<Job> _applyJobFilters(List<Job> jobs) {
    return jobs.where((j) {
      if (_verifiedOnly && !j.requiresVerification) return false;
      if (_urgentOnly && !j.isUrgent) return false;
      final price = j.salaryMax ?? j.salaryMin;
      if (price != null && (price < _minSalary || price > _maxSalary)) {
        return false;
      }
      if (_selectedLocation != null && _selectedLocation != 'All') {
        final loc = (j.location ?? '').toLowerCase();
        if (!loc.contains(_selectedLocation!.toLowerCase())) return false;
      }
      return true;
    }).toList()
      ..sort(_jobComparator);
  }

  List<WorkerProfile> _applyWorkerFilters(List<WorkerProfile> workers) {
    return workers.where((w) {
      if (_verifiedOnly && !w.isVerified) return false;
      if (_minRating > 0 && w.rating < _minRating) return false;
      if (_selectedLocation != null && _selectedLocation != 'All') {
        final loc = (w.location ?? '').toLowerCase();
        if (!loc.contains(_selectedLocation!.toLowerCase())) return false;
      }
      return true;
    }).toList()
      ..sort(_workerComparator);
  }

  int _jobComparator(Job a, Job b) {
    switch (_selectedSortBy) {
      case 'Highest Pay':
        return (b.salaryMax ?? b.salaryMin ?? 0)
            .compareTo(a.salaryMax ?? a.salaryMin ?? 0);
      default: // Recent — the API already orders latest() first.
        return 0;
    }
  }

  int _workerComparator(WorkerProfile a, WorkerProfile b) {
    switch (_selectedSortBy) {
      case 'Highest Rate':
      case 'Top Rated Worker':
        return b.rating.compareTo(a.rating);
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<JobProvider, WorkerBrowseProvider, WorkerProfileProvider>(
      builder: (context, jobProvider, workerBrowse, taxonomy, _) {
        final jobs = _applyJobFilters(jobProvider.publicJobs);
        final workers = _applyWorkerFilters(workerBrowse.workers);
        final isLoading =
            _searchType == 'Jobs' ? jobProvider.isPublicLoading : workerBrowse.isLoading;
        final error = _searchType == 'Jobs'
            ? jobProvider.publicErrorMessage
            : workerBrowse.errorMessage;
        final resultCount = _searchType == 'Jobs' ? jobs.length : workers.length;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              /*
                  One white header block instead of four stacked bars.

                  The filter button used to live inside the text field's
                  suffixIcon with its count badge absolutely positioned over it,
                  so the badge sat on top of the tap target and the field had no
                  edge of its own. It is now a button beside the field, sized
                  like one, and it turns solid when filters are on — a control
                  that is doing something should look different from one that
                  is not.
              */
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                elevation: 0,
                titleSpacing: 16,
                title: Row(
                  children: [
                    Expanded(child: _searchField()),
                    const SizedBox(width: 10),
                    _filterButton(),
                  ],
                ),
              ),

              // Jobs / Workers as a segmented control. Two large cards took a
              // third of the screen to say one word each.
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.neutral100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              _segment('Jobs'),
                              _segment('Workers'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$resultCount ${_searchType == 'Jobs' ? 'jobs' : 'workers'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Category chips — real categories from the server, the same
              // list job posting and worker onboarding use.
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _categoryChip(null, 'All'),
                        ...taxonomy.categories.map(
                          (c) => _categoryChip(c.id, c.name),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Active filters, shown as removable chips. Previously the only
              // sign a filter was on was a number on an icon, so people forgot
              // why their results were empty.
              if (_getActiveFilterCount() > 0 || _selectedSortBy != 'Recent')
                SliverToBoxAdapter(child: _activeFilterBar()),

              if (isLoading && resultCount == 0)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error != null && resultCount == 0)
                SliverFillRemaining(child: _errorState(error))
              else if (resultCount == 0)
                SliverFillRemaining(child: _emptyState())
              else if (_searchType == 'Jobs')
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _jobCard(jobs[index]),
                      ),
                      childCount: jobs.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _workerCard(workers[index]),
                      ),
                      childCount: workers.length,
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

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: _searchType == 'Jobs' ? 'Search jobs' : 'Search workers',
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.neutral400),
        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.neutral400),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        // Clearing a search should not require selecting the text and deleting
        // it, which is what it took before.
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.neutral400),
                onPressed: () {
                  _searchController.clear();
                  _onQueryChanged('');
                },
              ),
        filled: true,
        fillColor: AppColors.neutral100,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      onChanged: (value) {
        // Rebuilds so the clear button appears on the first character.
        setState(() {});
        _onQueryChanged(value);
      },
    );
  }

  Widget _filterButton() {
    final count = _getActiveFilterCount();
    final active = count > 0;

    return GestureDetector(
      onTap: _showFilterSheet,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.neutral100,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Icon(Icons.tune,
                size: 19,
                color: active ? Colors.white : AppColors.neutral600),
            if (active) ...[
              const SizedBox(width: 6),
              Text('$count',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segment(String type) {
    final selected = _searchType == type;

    return Expanded(
      child: GestureDetector(
        onTap: selected
            ? null
            : () {
                setState(() {
                  _searchType = type;
                  _selectedSortBy = 'Recent';
                  _selectedCategoryId = null;
                });
                _runSearch();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
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

  /// Every active filter as a chip you can tap to remove.
  ///
  /// A count on an icon told you *that* something was filtered but never what,
  /// so an empty result looked like there was simply nothing to find.
  Widget _activeFilterBar() {
    final chips = <Widget>[];

    void chip(String label, VoidCallback onRemove) {
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: () {
            setState(onRemove);
            _runSearch();
          },
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
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                const SizedBox(width: 4),
                const Icon(Icons.close, size: 13, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ));
    }

    if (_selectedSortBy != 'Recent') {
      chip('Sort: $_selectedSortBy', () => _selectedSortBy = 'Recent');
    }
    if (_selectedLocation != null && _selectedLocation != 'All') {
      chip(_selectedLocation!, () => _selectedLocation = null);
    }
    if (_minSalary > 0 || _maxSalary < 5000) {
      chip('₱${_minSalary.toInt()}–${_maxSalary.toInt()}', () {
        _minSalary = 0;
        _maxSalary = 5000;
      });
    }
    if (_minRating > 0) {
      chip('${_minRating.toStringAsFixed(1)}+ rating', () => _minRating = 0);
    }
    if (_verifiedOnly) chip('Verified only', () => _verifiedOnly = false);
    if (_urgentOnly) chip('Urgent only', () => _urgentOnly = false);

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: chips),
      ),
    );
  }

  Widget _categoryChip(int? id, String name) {
    final isSelected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(name),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategoryId = selected ? id : null;
          });
          _runSearch();
        },
        selectedColor: AppColors.primary.withAlpha(51),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.neutral700,
        ),
      ),
    );
  }

  Widget _jobCard(Job job) {
    return FeaturedJobCard(
      title: job.title,
      company: job.company.isEmpty ? 'Private Employer' : job.company,
      location: job.location ?? 'Location not set',
      // Employer rating is not part of the job payload yet — left blank
      // rather than inventing a number.
      rating: '',
      reviews: '',
      salary: _formatSalary(job.salaryMin, job.salaryMax),
      category: job.category,
      distance: job.distance == null ? null : formatDistance(job.distance!),
      isUrgent: job.isUrgent,
      requiresVerification: job.requiresVerification,
      requiredSkills: job.requiredSkills,
      matchScore: job.matchScore,
      onTap: () => Navigator.pushNamed(context, '/job-details',
          arguments: {'jobId': job.id}),
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
      skills: worker.skills,
      matchScore: worker.matchScore,
      distanceKm: worker.distance,
      rateLabel: worker.rateLabel,
      onTap: () => Navigator.pushNamed(context, '/worker-profile',
          arguments: {'workerId': worker.userId ?? worker.id}),
    );
  }

  String _formatSalary(double? min, double? max) {
    if (min == null && max == null) return 'Negotiable';
    if (min != null && max != null && max != min) {
      return '₱${min.toStringAsFixed(0)}-${max.toStringAsFixed(0)}';
    }
    return '₱${(min ?? max)!.toStringAsFixed(0)}';
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: AppColors.neutral300),
            const SizedBox(height: 16),
            const Text('Could not load results',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral600)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: AppColors.neutral400)),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: _runSearch, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 56, color: AppColors.neutral300),
            const SizedBox(height: 16),
            Text(
              _searchType == 'Jobs' ? 'No jobs found' : 'No workers found',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral600),
            ),
            const SizedBox(height: 8),
            const Text('Try a different search term or clear your filters',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.neutral400)),
          ],
        ),
      ),
    );
  }

  List<String> _getCurrentSortOptions() {
    if (_searchType == 'Jobs') {
      return ['Recent', 'Highest Pay'];
    }
    return ['Recent', 'Top Rated Worker'];
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filters', style: Theme.of(context).textTheme.headlineSmall),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          setState(() {
                            _selectedLocation = null;
                            _minSalary = 0;
                            _maxSalary = 5000;
                            _minRating = 0;
                            _verifiedOnly = false;
                            _urgentOnly = false;
                          });
                        });
                      },
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Sort lives here now. It used to be a dropdown in its own
                    // bar above the results, which cost a full row of height to
                    // show one value that is changed rarely.
                    const Text('Sort by',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _getCurrentSortOptions().map((option) {
                        final selected = _selectedSortBy == option;
                        return GestureDetector(
                          onTap: () => setSheetState(() {
                            setState(() => _selectedSortBy = option);
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : AppColors.neutral100,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: selected ? AppColors.primary : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: selected ? AppColors.primary : AppColors.neutral600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _searchType == 'Jobs' ? 'Pay Range (per day)' : 'Rate (per day)',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    // Both sides now have money to filter on: jobs carry a
                    // budget, workers carry a rate. Workers had only a rating
                    // filter because the rate columns did not exist.
                    Text('₱${_minSalary.toStringAsFixed(0)} - ₱${_maxSalary.toStringAsFixed(0)}'),
                    RangeSlider(
                      values: RangeValues(_minSalary, _maxSalary),
                      min: 0,
                      max: 5000,
                      divisions: 50,
                      labels: RangeLabels(
                          '₱${_minSalary.toStringAsFixed(0)}', '₱${_maxSalary.toStringAsFixed(0)}'),
                      onChanged: (values) => setSheetState(() => setState(() {
                        _minSalary = values.start;
                        _maxSalary = values.end;
                      })),
                    ),
                    if (_searchType == 'Workers') ...[
                      const SizedBox(height: 8),
                      Text(
                        'Workers who have not set a rate are hidden while this is narrowed.',
                        style: TextStyle(fontSize: 11, color: AppColors.neutral500),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Minimum Rating',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < _minRating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 20,
                          ),
                        ),
                      ),
                      Slider(
                        value: _minRating,
                        min: 0,
                        max: 5,
                        divisions: 10,
                        label: _minRating == 0 ? 'Any' : '${_minRating.toStringAsFixed(1)}+',
                        onChanged: (value) => setSheetState(() => setState(() => _minRating = value)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    CheckboxListTile(
                      title: Text(_searchType == 'Jobs'
                          ? 'Verified Employers Only'
                          : 'Verified Workers Only'),
                      value: _verifiedOnly,
                      onChanged: (value) => setSheetState(
                          () => setState(() => _verifiedOnly = value ?? false)),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (_searchType == 'Jobs')
                      CheckboxListTile(
                        title: const Text('Urgent Jobs Only'),
                        value: _urgentOnly,
                        onChanged: (value) => setSheetState(
                            () => setState(() => _urgentOnly = value ?? false)),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Apply Filters',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search Type Toggle Button Widget
