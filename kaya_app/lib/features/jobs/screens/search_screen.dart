import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../widgets/featured_job_card.dart';

/// Search Screen with Filters and Results
class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  
  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;
  String? _selectedLocation;
  String _selectedSortBy = 'Recent';
  String _searchType = 'Jobs'; // 'Jobs' or 'Workers'
  
  // Filter state
  double _minSalary = 0;
  double _maxSalary = 5000;
  double _maxDistance = 50;
  double _minRating = 0;
  bool _verifiedOnly = false;
  bool _urgentOnly = false;

  final List<String> _locations = ['All', 'Pangasinan', 'Dagupan City', 'Urdaneta City', 'San Carlos City'];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      // Set category if the initial query matches a category
      if (_getCurrentCategories().contains(widget.initialQuery)) {
        _selectedCategory = widget.initialQuery;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Count active filters
  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedLocation != null && _selectedLocation != 'All') count++;
    if (_minSalary > 0 || _maxSalary < 5000) count++;
    if (_maxDistance < 50) count++;
    if (_minRating > 0) count++;
    if (_verifiedOnly) count++;
    if (_urgentOnly) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Search AppBar
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
                            decoration: BoxDecoration(
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (value) {
                  // TODO: Implement search
                },
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
                      subtitle: '156 available',
                      isSelected: _searchType == 'Jobs',
                      onTap: () {
                        setState(() {
                          _searchType = 'Jobs';
                          _selectedSortBy = 'Recent'; // Reset to prevent dropdown error
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SearchTypeButton(
                      title: 'Workers',
                      subtitle: '89 near you',
                      isSelected: _searchType == 'Workers',
                      onTap: () {
                        setState(() {
                          _searchType = 'Workers';
                          _selectedSortBy = 'Recent'; // Reset to prevent dropdown error
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filter Chips
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        ..._getCurrentCategories().map((category) {
                          final isSelected = _selectedCategory == category;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategory = selected ? category : null;
                                });
                              },
                              selectedColor: AppColors.primary.withAlpha(51),
                              checkmarkColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? AppColors.primary : AppColors.neutral700,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
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
                    _searchType == 'Jobs' ? '156 jobs found' : '89 workers found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
                    onChanged: (value) {
                      setState(() {
                        _selectedSortBy = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // Search Results
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FeaturedJobCard(
                      title: _searchType == 'Jobs' ? _getJobTitle(index) : _getWorkerName(index),
                      company: _searchType == 'Jobs' ? _getCompany(index) : _getWorkerSkill(index),
                      location: _getLocation(index),
                      distance: '${(index * 0.5 + 1.5).toStringAsFixed(1)}km away',
                      category: _searchType == 'Jobs' ? _getJobCategory(index) : null,
                      rating: '4.${8 - (index % 3)}',
                      reviews: '(${100 + index * 5} reviews)',
                      salary: _searchType == 'Jobs' 
                        ? '₱${1000 + index * 200}/day'
                        : '₱${300 + index * 50}/hr',
                      isUrgent: _searchType == 'Jobs' ? (index % 5 == 0) : false,
                      requiresVerification: index % 3 == 0,
                      // Pass job's required skills + worker's skills to show match %
                      requiredSkills: _searchType == 'Jobs'
                          ? _getRequiredSkills(index)
                          : [],
                      // TODO: replace with actual worker skills from WorkerProfileProvider
                      workerSkills: _searchType == 'Jobs'
                          ? const ['Plumbing', 'Pipe Repair', 'Carpentry']
                          : [],
                      onTap: () {
                        if (_searchType == 'Jobs') {
                          Navigator.pushNamed(context, '/job-details');
                        } else {
                          Navigator.pushNamed(context, '/worker-profile');
                        }
                      },
                    ),
                  );
                },
                childCount: 20,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  /// Get categories based on current search type
  List<String> _getCurrentCategories() {
    if (_searchType == 'Jobs') {
      // Job categories - what employers need
      return ['All', 'Plumbing', 'Electrical', 'Painting', 'Carpentry', 'Construction', 'Cleaning'];
    } else {
      // Worker skills - what workers offer
      return ['All', 'Skilled', 'Verified', 'Top Rated', 'Available', 'Experienced', 'New'];
    }
  }

  /// Get sort options based on current search type
  List<String> _getCurrentSortOptions() {
    if (_searchType == 'Jobs') {
      return ['Recent', 'Nearest', 'Highest Pay', 'Top Rated Employer'];
    } else {
      return ['Recent', 'Nearest', 'Highest Rate', 'Top Rated Worker', 'Most Experienced'];
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.neutral300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = null;
                        _selectedLocation = null;
                        _minSalary = 0;
                        _maxSalary = 5000;
                        _maxDistance = 50;
                        _minRating = 0;
                        _verifiedOnly = false;
                        _urgentOnly = false;
                      });
                      Navigator.pop(context);
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
                  // Location Filter
                  Text(
                    'Location',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _locations.map((location) {
                      final isSelected = _selectedLocation == location;
                      return FilterChip(
                        label: Text(location),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedLocation = selected ? location : null;
                          });
                        },
                        selectedColor: AppColors.primary.withAlpha(51),
                        checkmarkColor: AppColors.primary,
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Distance Filter
                  Text(
                    'Distance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Up to ${_maxDistance.toStringAsFixed(0)}km away'),
                      Text(
                        _maxDistance >= 50 ? 'No limit' : '${_maxDistance.toStringAsFixed(0)}km',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _maxDistance,
                    min: 1,
                    max: 50,
                    divisions: 49,
                    label: _maxDistance >= 50 ? 'No limit' : '${_maxDistance.toStringAsFixed(0)}km',
                    onChanged: (value) {
                      setState(() {
                        _maxDistance = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Pay Range
                  Text(
                    _searchType == 'Jobs' ? 'Pay Range (per day)' : 'Rate Range (per hour)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('₱${_minSalary.toStringAsFixed(0)} - ₱${_maxSalary.toStringAsFixed(0)}'),
                      Text(
                        '₱${_minSalary.toStringAsFixed(0)} - ₱${_maxSalary.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: RangeValues(_minSalary, _maxSalary),
                    min: 0,
                    max: 5000,
                    divisions: 50,
                    labels: RangeLabels('₱${_minSalary.toStringAsFixed(0)}', '₱${_maxSalary.toStringAsFixed(0)}'),
                    onChanged: (values) {
                      setState(() {
                        _minSalary = values.start;
                        _maxSalary = values.end;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Rating Filter (for Jobs: employer rating, for Workers: worker rating)
                  Text(
                    _searchType == 'Jobs' ? 'Minimum Employer Rating' : 'Minimum Worker Rating',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < _minRating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 20,
                          );
                        }),
                      ),
                      Text(
                        _minRating == 0 ? 'Any rating' : '${_minRating.toStringAsFixed(1)}+',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _minRating,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    label: _minRating == 0 ? 'Any' : '${_minRating.toStringAsFixed(1)}+',
                    onChanged: (value) {
                      setState(() {
                        _minRating = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Verification & Urgency Checkboxes
                  CheckboxListTile(
                    title: Text(_searchType == 'Jobs' ? 'Verified Employers Only' : 'Verified Workers Only'),
                    value: _verifiedOnly,
                    onChanged: (value) {
                      setState(() {
                        _verifiedOnly = value ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (_searchType == 'Jobs')
                    CheckboxListTile(
                      title: const Text('Urgent Jobs Only'),
                      value: _urgentOnly,
                      onChanged: (value) {
                        setState(() {
                          _urgentOnly = value ?? false;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ],
              ),
            ),
            // Apply Button
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
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getJobTitle(int index) {
    final titles = ['Emergency Pipe Repair', 'Electrician Needed', 'House Painting', 'Carpenter for Kitchen', 'AC Repair'];
    return titles[index % titles.length];
  }

  String _getJobCategory(int index) {
    final categories = ['Plumbing', 'Electrical', 'Painting', 'Carpentry', 'AC Repair'];
    return categories[index % categories.length];
  }

  String _getCompany(int index) {
    final companies = ['Plumbing Services Inc.', 'Tech Solutions', 'Private Homeowner', 'Baliwag Construction', 'Cool Air Services'];
    return companies[index % companies.length];
  }

  String _getWorkerName(int index) {
    final names = ['Juan Dela Cruz', 'Maria Santos', 'Pedro Gonzales', 'Ana Reyes', 'Carlos Mendoza'];
    return names[index % names.length];
  }

  String _getWorkerSkill(int index) {
    final skills = ['Professional Plumber', 'Electrical Specialist', 'Painting Expert', 'Master Carpenter', 'AC Technician'];
    return skills[index % skills.length];
  }

  String _getLocation(int index) {
    final locations = ['Pangasinan', 'Dagupan City', 'Urdaneta City', 'San Carlos City'];
    return locations[index % locations.length];
  }

  List<String> _getRequiredSkills(int index) {
    final skillSets = [
      ['Plumbing', 'Pipe Repair', 'Leak Detection'],
      ['Wiring', 'Circuit Repair', 'Lighting'],
      ['Interior Painting', 'Surface Preparation'],
      ['Cabinet Making', 'Framing', 'Carpentry'],
      ['AC Repair', 'Maintenance', 'Duct Cleaning'],
    ];
    return skillSets[index % skillSets.length];
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
