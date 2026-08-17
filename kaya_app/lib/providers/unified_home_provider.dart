import 'package:flutter/foundation.dart';
import '../data/models/job_model.dart';
import '../data/models/worker_profile_model.dart';
import '../features/jobs/widgets/unified_search_bar.dart';

/// Provider for managing unified home screen state
/// Handles jobs, workers, search, and filtering in a single provider
class UnifiedHomeProvider with ChangeNotifier {
  // Loading states
  bool _isJobsLoading = false;
  bool _isWorkersLoading = false;
  bool _isRefreshing = false;

  // Data
  List<Job> _jobs = [];
  List<WorkerProfile> _workers = [];
  List<Job> _filteredJobs = [];
  List<WorkerProfile> _filteredWorkers = [];

  // Search and filter
  String _searchQuery = '';
  SearchFilter _searchFilter = SearchFilter.all;

  // User location (for distance calculations)
  String? _userLocation = 'Villanis, Pangasinan';

  // Error handling
  String? _errorMessage;

  // Getters
  bool get isJobsLoading => _isJobsLoading;
  bool get isWorkersLoading => _isWorkersLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isLoading => _isJobsLoading || _isWorkersLoading;

  List<Job> get jobs => _filteredJobs;
  List<WorkerProfile> get workers => _filteredWorkers;
  
  String get searchQuery => _searchQuery;
  SearchFilter get searchFilter => _searchFilter;
  String? get userLocation => _userLocation;
  String? get errorMessage => _errorMessage;

  // Computed properties
  bool get hasJobsData => _jobs.isNotEmpty;
  bool get hasWorkersData => _workers.isNotEmpty;
  bool get showJobsSection => _searchFilter == SearchFilter.all || _searchFilter == SearchFilter.showJobs;
  bool get showWorkersSection => _searchFilter == SearchFilter.all || _searchFilter == SearchFilter.showWorkers;

  /// Initialize provider with mock data
  /// TODO: Replace with actual API calls
  void initialize() {
    _loadMockData();
    _applyFilters();
  }

  /// Handle pull-to-refresh
  Future<void> refreshData() async {
    _isRefreshing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 800));
      
      // TODO: Replace with actual API calls
      await _fetchJobs();
      await _fetchWorkers();
      
      _applyFilters();
    } catch (e) {
      _errorMessage = 'Failed to refresh data. Please try again.';
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Update search query and apply filters
  void updateSearchQuery(String query) {
    _searchQuery = query.trim();
    _applyFilters();
    notifyListeners();
  }

  /// Update search filter and apply filters
  void updateSearchFilter(SearchFilter filter) {
    _searchFilter = filter;
    _applyFilters();
    notifyListeners();
  }

  /// Clear search and reset filters
  void clearSearch() {
    _searchQuery = '';
    _searchFilter = SearchFilter.all;
    _applyFilters();
    notifyListeners();
  }

  /// Update user location
  void updateUserLocation(String location) {
    _userLocation = location;
    // TODO: Refetch data based on new location
    _applyFilters();
    notifyListeners();
  }

  /// Apply current search query and filter to data
  void _applyFilters() {
    _filteredJobs = _filterJobs(_jobs);
    _filteredWorkers = _filterWorkers(_workers);
  }

  /// Filter jobs based on search query
  List<Job> _filterJobs(List<Job> jobs) {
    if (_searchQuery.isEmpty) return jobs;
    
    return jobs.where((job) {
      return job.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             job.company.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (job.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
             (job.location?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
             job.requiredSkills.any((skill) => skill.toLowerCase().contains(_searchQuery.toLowerCase()));
    }).toList();
  }

  /// Filter workers based on search query
  List<WorkerProfile> _filterWorkers(List<WorkerProfile> workers) {
    if (_searchQuery.isEmpty) return workers;
    
    return workers.where((worker) {
      return worker.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             worker.primarySkill.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (worker.location?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
             worker.skills.any((skill) => skill.toLowerCase().contains(_searchQuery.toLowerCase()));
    }).toList();
  }

  /// Fetch jobs from API
  Future<void> _fetchJobs() async {
    _isJobsLoading = true;
    notifyListeners();

    try {
      // TODO: Replace with actual API service call
      await Future.delayed(const Duration(milliseconds: 500));
      _jobs = _getMockJobs();
    } catch (e) {
      _errorMessage = 'Failed to load jobs: $e';
    } finally {
      _isJobsLoading = false;
    }
  }

  /// Fetch workers from API
  Future<void> _fetchWorkers() async {
    _isWorkersLoading = true;
    notifyListeners();

    try {
      // TODO: Replace with actual API service call
      await Future.delayed(const Duration(milliseconds: 500));
      _workers = _getMockWorkers();
    } catch (e) {
      _errorMessage = 'Failed to load workers: $e';
    } finally {
      _isWorkersLoading = false;
    }
  }

  /// Load mock data immediately (for demo purposes)
  void _loadMockData() {
    _jobs = _getMockJobs();
    _workers = _getMockWorkers();
  }

  /// Mock jobs data
  /// TODO: Remove when API integration is complete
  List<Job> _getMockJobs() {
    return [
      Job(
        id: 1,
        title: 'Emergency Pipe Repair',
        company: 'Plumbing Services',
        description: 'Urgent plumbing repair needed. Kitchen sink pipe burst, water damage concern. Professional plumber required immediately.',
        location: 'Dagupan City',
        salaryMin: 1200,
        salaryMax: 1500,
        salaryPeriod: 'day',
        isUrgent: true,
        requiresVerification: true,
        distance: 2.5,
        isActive: true,
        category: 'Plumbing',
        requiredSkills: ['Pipe Repair', 'Emergency Response', 'Plumbing'],
        applicantCount: 12,
        postedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Job(
        id: 2,
        title: 'House Rewiring',
        company: 'ElectroFix',
        description: 'Complete house electrical rewiring project. Old wiring needs replacement, new circuit installation required.',
        location: 'Pangasinan',
        salaryMin: 1800,
        salaryMax: 2200,
        salaryPeriod: 'day',
        requiresVerification: true,
        distance: 4.2,
        isActive: true,
        category: 'Electrical',
        requiredSkills: ['Electrical Wiring', 'Circuit Installation', 'Safety Protocols'],
        applicantCount: 8,
        postedAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      Job(
        id: 3,
        title: 'Room Painting',
        company: 'Paint Masters',
        description: 'Interior painting for 3 bedrooms and living room. Quality finish required, color consultation included.',
        location: 'Villanis',
        salaryMin: 1000,
        salaryMax: 1300,
        salaryPeriod: 'day',
        distance: 1.8,
        isActive: true,
        category: 'Painting',
        requiredSkills: ['Interior Painting', 'Color Consultation', 'Surface Preparation'],
        applicantCount: 15,
        postedAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      Job(
        id: 4,
        title: 'Kitchen Cabinet Installation',
        company: 'Wood Craft Solutions',
        description: 'Custom kitchen cabinet installation. Precision work required, cabinet assembly and mounting included.',
        location: 'Dagupan City',
        salaryMin: 1600,
        salaryMax: 2000,
        salaryPeriod: 'day',
        requiresVerification: true,
        distance: 3.1,
        isActive: true,
        category: 'Carpentry',
        requiredSkills: ['Cabinet Installation', 'Precision Carpentry', 'Hardware Mounting'],
        applicantCount: 6,
        postedAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),
      Job(
        id: 5,
        title: 'Garden Landscaping',
        company: 'Green Thumb Landscaping',
        description: 'Complete garden redesign and landscaping. Plant installation, pathway creation, and irrigation setup.',
        location: 'Villanis',
        salaryMin: 1400,
        salaryMax: 1800,
        salaryPeriod: 'day',
        distance: 2.2,
        isActive: true,
        category: 'Landscaping',
        requiredSkills: ['Garden Design', 'Plant Installation', 'Irrigation Systems'],
        applicantCount: 9,
        postedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  /// Mock workers data
  /// TODO: Remove when API integration is complete
  List<WorkerProfile> _getMockWorkers() {
    return [
      WorkerProfile(
        id: 1,
        name: 'Juan Dela Cruz',
        primarySkill: 'Professional Plumber',
        skills: ['Plumbing', 'Pipe Repair', 'Installation', 'Emergency Response'],
        location: 'Pangasinan',
        rating: 4.8,
        reviewCount: 120,
        isVerified: true,
        isAvailable: true,
        distance: 3.2,
        yearsOfExperience: 8,
        hourlyRate: 350,
        completedJobs: 95,
        bio: 'Experienced plumber with 8+ years in residential and commercial projects. Specializes in emergency repairs and new installations.',
        certifications: ['Licensed Plumber', 'Safety Certified'],
        lastActive: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      WorkerProfile(
        id: 2,
        name: 'Maria Santos',
        primarySkill: 'Electrical Specialist',
        skills: ['Electrical', 'Wiring', 'Circuit Installation', 'Safety Protocols'],
        location: 'Dagupan City',
        rating: 4.9,
        reviewCount: 85,
        isVerified: true,
        isAvailable: true,
        distance: 5.1,
        yearsOfExperience: 6,
        hourlyRate: 400,
        completedJobs: 78,
        bio: 'Certified electrician specializing in residential wiring and commercial electrical systems. Safety-first approach to all projects.',
        certifications: ['Master Electrician License', 'OSHA Safety Certified'],
        lastActive: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      WorkerProfile(
        id: 3,
        name: 'Pedro Gonzales',
        primarySkill: 'Painting Expert',
        skills: ['Interior Painting', 'Exterior Painting', 'Wall Preparation', 'Color Consultation'],
        location: 'Villanis',
        rating: 4.7,
        reviewCount: 65,
        isVerified: true,
        isAvailable: false,
        distance: 2.8,
        yearsOfExperience: 4,
        hourlyRate: 280,
        completedJobs: 52,
        bio: 'Professional painter with expertise in both residential and commercial projects. Known for clean work and attention to detail.',
        certifications: ['Painting Contractor License'],
        lastActive: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      WorkerProfile(
        id: 4,
        name: 'Ana Reyes',
        primarySkill: 'Master Carpenter',
        skills: ['Carpentry', 'Cabinet Making', 'Furniture Repair', 'Custom Woodwork'],
        location: 'Dagupan City',
        rating: 4.9,
        reviewCount: 110,
        isVerified: true,
        isAvailable: true,
        distance: 4.5,
        yearsOfExperience: 12,
        hourlyRate: 420,
        completedJobs: 134,
        bio: 'Master carpenter with over 12 years experience in custom woodwork and furniture making. Precision craftsmanship guaranteed.',
        certifications: ['Master Carpenter Certification', 'Custom Furniture Maker'],
        lastActive: DateTime.now().subtract(const Duration(minutes: 45)),
      ),
      WorkerProfile(
        id: 5,
        name: 'Roberto Silva',
        primarySkill: 'Landscape Designer',
        skills: ['Garden Design', 'Plant Installation', 'Irrigation', 'Hardscaping'],
        location: 'Villanis',
        rating: 4.6,
        reviewCount: 42,
        isVerified: true,
        isAvailable: true,
        distance: 1.9,
        yearsOfExperience: 5,
        hourlyRate: 320,
        completedJobs: 38,
        bio: 'Creative landscape designer with passion for sustainable garden solutions. Specializes in tropical and drought-resistant designs.',
        certifications: ['Landscape Design Certificate'],
        lastActive: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ];
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Handle job application
  void applyToJob(Job job) {
    // TODO: Implement job application logic
    // This would typically:
    // 1. Send application to backend
    // 2. Update job's application status
    // 3. Show success feedback
    print('Applying to job: ${job.title}');
  }

  /// Handle worker invitation
  void inviteWorker(WorkerProfile worker) {
    // TODO: Implement worker invitation logic
    // This would typically:
    // 1. Show job selection dialog (which job to invite for)
    // 2. Send invitation to backend
    // 3. Show success feedback
    print('Inviting worker: ${worker.name}');
  }

  /// Handle job tap (navigation to job details)
  void onJobTap(Job job) {
    // TODO: Implement navigation to job details screen
    print('Navigating to job details: ${job.title}');
  }

  /// Handle worker tap (navigation to worker profile)
  void onWorkerTap(WorkerProfile worker) {
    // TODO: Implement navigation to worker profile screen
    print('Navigating to worker profile: ${worker.name}');
  }

  /// Handle category tap
  void onCategoryTap(String category) {
    // TODO: Implement navigation to category search
    // This would filter jobs/workers by category
    print('Browsing category: $category');
  }
}