import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/job_model.dart';
import '../../../data/models/worker_profile_model.dart';
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

  String? _selectedCategory;
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
      await context.read<WorkerBrowseProvider>().fetchWorkers(
            q: query,
            categoryId: _selectedCategoryId,
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
              SliverAppBar(
                floating: true,
                snap: true,
                title: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _searchType == 'Jobs'
                          ? 'Search jobs and services...'
                          : 'Search workers by name or skill...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.tune),
                            onPressed: _showFilterSheet,
                          ),
                          if (_getActiveFilterCount() > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '${_getActiveFilterCount()}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: _onQueryChanged,
                  ),
                ),
              ),

              // Search Type Toggle
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: _SearchTypeButton(
                          title: 'Jobs',
                          subtitle: _searchType == 'Jobs'
                              ? '$resultCount available'
                              : '',
                          isSelected: _searchType == 'Jobs',
                          onTap: () {
                            setState(() {
                              _searchType = 'Jobs';
                              _selectedSortBy = 'Recent';
                              _selectedCategory = null;
                              _selectedCategoryId = null;
                            });
                            _runSearch();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SearchTypeButton(
                          title: 'Workers',
                          subtitle: _searchType == 'Workers'
                              ? '$resultCount near you'
                              : '',
                          isSelected: _searchType == 'Workers',
                          onTap: () {
                            setState(() {
                              _searchType = 'Workers';
                              _selectedSortBy = 'Recent';
                              _selectedCategory = null;
                              _selectedCategoryId = null;
                            });
                            _runSearch();
                          },
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: Colors.white,
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

              // Sort and Results Count
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _searchType == 'Jobs'
                            ? '$resultCount jobs found'
                            : '$resultCount workers found',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      DropdownButton<String>(
                        value: _selectedSortBy,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down),
                        items: _getCurrentSortOptions().map((option) {
                          return DropdownMenuItem(
                            value: option,
                            child: Text(option, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedSortBy = value!),
                      ),
                    ],
                  ),
                ),
              ),

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

  Widget _categoryChip(int? id, String name) {
    final isSelected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(name),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? name : null;
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
      distance: job.distance != null ? '${job.distance!.toStringAsFixed(1)}km away' : null,
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
                style: const TextStyle(fontSize: 13, color: AppColors.neutral400)),
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
                    Text(
                      _searchType == 'Jobs' ? 'Pay Range (per day)' : 'Minimum Rating',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_searchType == 'Jobs') ...[
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
                    ] else ...[
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
class _SearchTypeButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _SearchTypeButton({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.neutral300,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.neutral700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.neutral500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
