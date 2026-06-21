import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../data/models/job_model.dart';
import '../../../data/models/worker_profile_model.dart';
import '../../help/screens/faq_screen.dart';
import '../widgets/unified_search_bar.dart';
import '../widgets/jobs_near_you_section.dart';
import '../widgets/people_who_can_help_section.dart';

/// Unified Home Screen - Shows both jobs and workers simultaneously
/// No mode switching required - users see everything and use what they need
class UnifiedHomeScreen extends StatefulWidget {
  const UnifiedHomeScreen({super.key});

  @override
  State<UnifiedHomeScreen> createState() => _UnifiedHomeScreenState();
}

class _UnifiedHomeScreenState extends State<UnifiedHomeScreen> {
  // State variables
  SearchFilter _searchFilter = SearchFilter.all;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  bool _isOpenToWork = true; // User status toggle
  bool _isOpenToHire = false; // User status toggle

  // Mock user data
  final String _userName = 'Eddison';
  final int _activeJobs = 3;
  final int _pendingApplications = 1;
  
  // Profile completion status
  bool _isProfileIncomplete = true; // Set to false once profile is complete
  bool _isEmptyStateVisible = true; // Can be dismissed

  // Mock data (TODO: Replace with provider when available)
  late List<Job> _allJobs;
  late List<WorkerProfile> _allWorkers;
  List<Job> _filteredJobs = [];
  List<WorkerProfile> _filteredWorkers = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    _allJobs = _getMockJobs();
    _allWorkers = _getMockWorkers();
    _applyFilters();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 800));
    
    setState(() {
      _allJobs = _getMockJobs();
      _allWorkers = _getMockWorkers();
      _applyFilters();
      _isLoading = false;
    });
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query.trim();
      _applyFilters();
    });
  }

  void _updateSearchFilter(SearchFilter filter) {
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

  bool get _showJobsSection => _searchFilter == SearchFilter.all || _searchFilter == SearchFilter.workers;
  bool get _showWorkersSection => _searchFilter == SearchFilter.all || _searchFilter == SearchFilter.jobs;

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
          // Dismiss button
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: Icon(Icons.close, size: 20, color: AppColors.neutral600),
              onPressed: () {
                setState(() {
                  _isEmptyStateVisible = false;
                });
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          
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
          
          // Heading
          Text(
            'You have no recommended jobs yet',
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
            'Update your profile or start searching for jobs to get personalised job recommendations here.',
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
                  onPressed: () async {
                    final result = await Navigator.pushNamed(context, AppRouter.myWorkerProfile);
                    if (result == true) {
                      setState(() {
                        _isProfileIncomplete = false;
                      });
                    }
                  },
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final result = await Navigator.pushNamed(context, AppRouter.myEmployerProfile);
                    if (result == true) {
                      setState(() {
                        _isProfileIncomplete = false;
                      });
                    }
                  },
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
                      fontSize: 13,
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
              expandedHeight: 160,
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
                                          text: ', $_userName',
                                          style: TextStyle(color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Status indicators
                                  Row(
                                    children: [
                                      if (_isOpenToWork)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.success.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: AppColors.success.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: 14,
                                                color: AppColors.success,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Open to work',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.success,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (_isOpenToWork && _isOpenToHire) const SizedBox(width: 8),
                                      if (_isOpenToHire)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: AppColors.primary.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.business_center,
                                                size: 14,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Hiring now',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
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
                                  child: IconButton(
                                    icon: const Icon(Icons.notifications_outlined, size: 20),
                                    onPressed: () => AppRouter.toNotifications(context),
                                  ),
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
                  currentFilter: _searchFilter,
                  onSearch: _updateSearchQuery,
                  onFilterChanged: _updateSearchFilter,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Empty State Card - When shown, this is the ONLY content
            if (_isProfileIncomplete && _isEmptyStateVisible) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildEmptyStateCard(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],

            // ALL OTHER CONTENT - Only show when profile is complete or empty state is dismissed
            if (!_isProfileIncomplete || !_isEmptyStateVisible) ...[
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
                            _getCategoryIcon(),
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getCategoriesTitle(),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.neutral900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildCategories(),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Smart Action Prompts based on current filter
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSmartActionPrompts(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Your Activity Section - Quick access to active jobs and applications
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
                      Row(
                        children: [
                          // Active Jobs Card
                          Expanded(
                            child: _ActivityCard(
                              icon: Icons.work,
                              iconColor: AppColors.accent,
                              count: _activeJobs,
                              label: 'Active Jobs',
                              onTap: _navigateToActiveJobs,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Pending Applications Card
                          Expanded(
                            child: _ActivityCard(
                              icon: Icons.description,
                              iconColor: AppColors.primary,
                              count: _pendingApplications,
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
              if (_showJobsSection) ...[
                SliverToBoxAdapter(
                  child: JobsNearYouSection(
                    jobs: _filteredJobs,
                    isLoading: _isLoading,
                    userLocation: 'Urdaneta City, Pangasinan',
                    onSeeAll: () => AppRouter.toSearchJobs(context),
                    onJobTap: _onJobTap,
                    onJobContact: _contactEmployer,
                    // TODO: replace with actual worker skills from WorkerProfileProvider
                    workerSkills: const ['Plumbing', 'Pipe Repair', 'Wiring', 'Carpentry', 'Painting'],
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],

              // People Who Can Help Section (conditional based on filter)
              if (_showWorkersSection) ...[
                SliverToBoxAdapter(
                  child: PeopleWhoCanHelpSection(
                    workers: _filteredWorkers,
                    isLoading: _isLoading,
                    userLocation: 'Urdaneta City, Pangasinan',
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

  void _contactEmployer(Job job) {
    // Show contact options instead of application
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contact Employer'),
        content: Text('Contact employer about "${job.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to messaging or show contact info
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Contacting employer for ${job.title}')),
              );
            },
            child: const Text('Message'),
          ),
        ],
      ),
    );
  }

  void _onWorkerTap(WorkerProfile worker) {
    AppRouter.toWorkerProfile(context, worker);
  }

  void _inviteWorker(WorkerProfile worker) {
    // Show job selection for invitation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite to Job'),
        content: Text('Invite ${worker.name} to apply for a job?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Handle actual worker invitation
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Invitation sent to ${worker.name}')),
              );
            },
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );
  }

  /// Mock jobs data - TODO: Replace with API integration
  List<Job> _getMockJobs() {
    return [
      Job(
        id: 1,
        title: 'Emergency Pipe Repair',
        company: 'Plumbing Services',
        description: 'Urgent plumbing repair needed. Kitchen sink pipe burst, water damage concern.',
        location: 'Urdaneta City',
        salaryMin: 1200,
        salaryMax: 1500,
        salaryPeriod: 'day',
        isUrgent: true,
        requiresVerification: true,
        distance: 2.5,
        isActive: true,
        category: 'Plumbing',
        requiredSkills: ['Pipe Repair', 'Emergency Response'],
        applicantCount: 12,
        postedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Job(
        id: 2,
        title: 'House Rewiring',
        company: 'ElectroFix',
        description: 'Complete house electrical rewiring project. Old wiring needs replacement.',
        location: 'Urdaneta City',
        salaryMin: 1800,
        salaryMax: 2200,
        salaryPeriod: 'day',
        requiresVerification: true,
        distance: 4.2,
        isActive: true,
        category: 'Electrical',
        requiredSkills: ['Electrical Wiring', 'Circuit Installation'],
        applicantCount: 8,
        postedAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      Job(
        id: 3,
        title: 'Room Painting',
        company: 'Paint Masters',
        description: 'Interior painting for 3 bedrooms and living room.',
        location: 'Urdaneta City',
        salaryMin: 1000,
        salaryMax: 1300,
        salaryPeriod: 'day',
        distance: 1.8,
        isActive: true,
        category: 'Painting',
        requiredSkills: ['Interior Painting', 'Surface Preparation'],
        applicantCount: 15,
        postedAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      Job(
        id: 4,
        title: 'Kitchen Cabinet Installation',
        company: 'Wood Craft Solutions',
        description: 'Custom kitchen cabinet installation. Precision work required.',
        location: 'Urdaneta City',
        salaryMin: 1600,
        salaryMax: 2000,
        salaryPeriod: 'day',
        requiresVerification: true,
        distance: 3.1,
        isActive: true,
        category: 'Carpentry',
        requiredSkills: ['Cabinet Installation', 'Precision Carpentry'],
        applicantCount: 6,
        postedAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),
    ];
  }

  /// Mock workers data - TODO: Replace with API integration
  List<WorkerProfile> _getMockWorkers() {
    return [
      WorkerProfile(
        id: 1,
        name: 'Juan Dela Cruz',
        primarySkill: 'Professional Plumber',
        skills: ['Plumbing', 'Pipe Repair', 'Installation'],
        location: 'Urdaneta City',
        rating: 4.8,
        reviewCount: 120,
        isVerified: true,
        isAvailable: true,
        distance: 3.2,
        yearsOfExperience: 8,
        hourlyRate: 350,
        completedJobs: 95,
        lastActive: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      WorkerProfile(
        id: 2,
        name: 'Maria Santos',
        primarySkill: 'Electrical Specialist',
        skills: ['Electrical', 'Wiring', 'Circuit Installation'],
        location: 'Urdaneta City',
        rating: 4.9,
        reviewCount: 85,
        isVerified: true,
        isAvailable: true,
        distance: 5.1,
        yearsOfExperience: 6,
        hourlyRate: 400,
        completedJobs: 78,
        lastActive: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      WorkerProfile(
        id: 3,
        name: 'Pedro Gonzales',
        primarySkill: 'Painting Expert',
        skills: ['Interior Painting', 'Exterior Painting'],
        location: 'Urdaneta City',
        rating: 4.7,
        reviewCount: 65,
        isVerified: true,
        isAvailable: false,
        distance: 2.8,
        yearsOfExperience: 4,
        hourlyRate: 280,
        completedJobs: 52,
        lastActive: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      WorkerProfile(
        id: 4,
        name: 'Ana Reyes',
        primarySkill: 'Master Carpenter',
        skills: ['Carpentry', 'Cabinet Making', 'Custom Woodwork'],
        location: 'Urdaneta City',
        rating: 4.9,
        reviewCount: 110,
        isVerified: true,
        isAvailable: true,
        distance: 4.5,
        yearsOfExperience: 12,
        hourlyRate: 420,
        completedJobs: 134,
        lastActive: DateTime.now().subtract(const Duration(minutes: 45)),
      ),
    ];
  }

  /// Get categories title based on current filter
  String _getCategoriesTitle() {
    switch (_searchFilter) {
      case SearchFilter.jobs:
        return 'Job Categories';
      case SearchFilter.workers:
        return 'Worker Skills';
      case SearchFilter.all:
        return 'Browse Categories';
    }
  }

  /// Build appropriate categories based on current filter
  Widget _buildCategories() {
    // Worker filters — keep original full-width Row layout with Expanded
    if (_searchFilter == SearchFilter.workers) {
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

    // Job categories + All — horizontal scroll with all 18
    const allCategories = [
      {'name': 'Plumbing',         'icon': Icons.plumbing},
      {'name': 'Electrical',       'icon': Icons.electrical_services},
      {'name': 'Painting',         'icon': Icons.format_paint},
      {'name': 'Carpentry',        'icon': Icons.carpenter},
      {'name': 'Construction',     'icon': Icons.construction},
      {'name': 'HVAC',             'icon': Icons.ac_unit},
      {'name': 'Landscaping',      'icon': Icons.grass},
      {'name': 'Cleaning',         'icon': Icons.cleaning_services},
      {'name': 'Roofing',          'icon': Icons.roofing},
      {'name': 'Flooring',         'icon': Icons.layers},
      {'name': 'Automotive',       'icon': Icons.car_repair},
      {'name': 'Appliance Repair', 'icon': Icons.kitchen},
      {'name': 'Security',         'icon': Icons.security},
      {'name': 'Moving',           'icon': Icons.local_shipping},
      {'name': 'Pest Control',     'icon': Icons.bug_report},
      {'name': 'Pool Services',    'icon': Icons.pool},
      {'name': 'Delivery',         'icon': Icons.delivery_dining},
      {'name': 'Other',            'icon': Icons.build},
    ];

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: allCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = allCategories[i];
          return _CategoryButton(
            icon: item['icon'] as IconData,
            label: item['name'] as String,
            color: AppColors.categoryIcon,
            onTap: () => _onCategoryTap(item['name'] as String),
          );
        },
      ),
    );
  }

  /// Build smart action prompts based on current filter context
  Widget _buildSmartActionPrompts() {
    if (_searchFilter == SearchFilter.jobs) {
      // When viewing jobs - show employer actions
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
              onPressed: () => _navigateToPostJob(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Post Job'),
            ),
          ],
        ),
      );
    } else if (_searchFilter == SearchFilter.workers) {
      // When viewing workers - show worker actions  
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary.withValues(alpha: 0.1), Colors.transparent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.person_outline, color: AppColors.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Looking for work?',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.neutral900,
                    ),
                  ),
                  Text(
                    'Create your worker profile to get hired',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.neutral600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => _navigateToEditProfile(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('My Profile'),
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
  void _navigateToPostJob() {
    AppRouter.toPostJob(context);
  }

  void _navigateToEditProfile() {
    AppRouter.toEditWorkerProfile(context);
  }

  void _navigateToActiveJobs() {
    Navigator.pushNamed(context, '/manage-jobs');
  }

  void _navigateToPendingApplications() {
    Navigator.pushNamed(context, '/applications');
  }

  /// Get time-based greeting
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  /// Get category icon based on filter
  IconData _getCategoryIcon() {
    switch (_searchFilter) {
      case SearchFilter.jobs:
        return Icons.work_outline;
      case SearchFilter.workers:
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

  const _CategoryButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.neutral800,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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