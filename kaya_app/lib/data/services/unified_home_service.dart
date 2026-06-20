import '../models/job_model.dart';
import '../models/worker_profile_model.dart';

/// Service for fetching combined home screen data (jobs + workers)
/// Handles API calls for the unified home screen experience
class UnifiedHomeService {
  // TODO: Inject ApiClient when it's available
  // final ApiClient _apiClient;
  
  // UnifiedHomeService(this._apiClient);

  /// Fetch jobs near the user's location
  /// Returns jobs sorted by distance and relevance
  Future<List<Job>> fetchNearbyJobs({
    String? location,
    double? latitude,
    double? longitude,
    int limit = 10,
    String? category,
  }) async {
    try {
      // TODO: Replace with actual API call
      // final response = await _apiClient.get('/api/v1/jobs/nearby', queryParameters: {
      //   'location': location,
      //   'lat': latitude,
      //   'lng': longitude,
      //   'limit': limit,
      //   'category': category,
      // });
      
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Mock data for now
      return _getMockJobs();
    } catch (e) {
      throw Exception('Failed to fetch nearby jobs: $e');
    }
  }

  /// Fetch workers available in the user's area
  /// Returns workers sorted by distance, rating, and availability
  Future<List<WorkerProfile>> fetchNearbyWorkers({
    String? location,
    double? latitude,
    double? longitude,
    int limit = 10,
    List<String>? skills,
    bool? availableOnly,
  }) async {
    try {
      // TODO: Replace with actual API call
      // final response = await _apiClient.get('/api/v1/workers/nearby', queryParameters: {
      //   'location': location,
      //   'lat': latitude,
      //   'lng': longitude,
      //   'limit': limit,
      //   'skills': skills?.join(','),
      //   'available_only': availableOnly,
      // });
      
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 600));
      
      // Mock data for now
      return _getMockWorkers();
    } catch (e) {
      throw Exception('Failed to fetch nearby workers: $e');
    }
  }

  /// Search jobs and workers simultaneously
  /// Optimized for unified search experience
  Future<UnifiedSearchResults> searchJobsAndWorkers({
    required String query,
    String? location,
    double? latitude,
    double? longitude,
    String? category,
    List<String>? skills,
    int jobsLimit = 20,
    int workersLimit = 20,
  }) async {
    try {
      // TODO: Replace with actual API call
      // final response = await _apiClient.get('/api/v1/search/unified', queryParameters: {
      //   'q': query,
      //   'location': location,
      //   'lat': latitude,
      //   'lng': longitude,
      //   'category': category,
      //   'skills': skills?.join(','),
      //   'jobs_limit': jobsLimit,
      //   'workers_limit': workersLimit,
      // });
      
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Mock search results
      final allJobs = _getMockJobs();
      final allWorkers = _getMockWorkers();
      
      final filteredJobs = allJobs.where((job) => 
        job.title.toLowerCase().contains(query.toLowerCase()) ||
        job.company.toLowerCase().contains(query.toLowerCase()) ||
        (job.description?.toLowerCase().contains(query.toLowerCase()) ?? false)
      ).toList();
      
      final filteredWorkers = allWorkers.where((worker) => 
        worker.name.toLowerCase().contains(query.toLowerCase()) ||
        worker.primarySkill.toLowerCase().contains(query.toLowerCase()) ||
        worker.skills.any((skill) => skill.toLowerCase().contains(query.toLowerCase()))
      ).toList();
      
      return UnifiedSearchResults(
        jobs: filteredJobs,
        workers: filteredWorkers,
        totalJobsCount: filteredJobs.length,
        totalWorkersCount: filteredWorkers.length,
      );
    } catch (e) {
      throw Exception('Failed to search: $e');
    }
  }

  /// Apply to a job
  Future<bool> applyToJob(int jobId, {String? message}) async {
    try {
      // TODO: Replace with actual API call
      // final response = await _apiClient.post('/api/v1/jobs/$jobId/apply', data: {
      //   'message': message,
      // });
      
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Mock success
      return true;
    } catch (e) {
      throw Exception('Failed to apply to job: $e');
    }
  }

  /// Send job invitation to worker
  Future<bool> inviteWorkerToJob({
    required int workerId,
    required int jobId,
    String? message,
  }) async {
    try {
      // TODO: Replace with actual API call
      // final response = await _apiClient.post('/api/v1/workers/$workerId/invite', data: {
      //   'job_id': jobId,
      //   'message': message,
      // });
      
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Mock success
      return true;
    } catch (e) {
      throw Exception('Failed to invite worker: $e');
    }
  }

  /// Get trending categories based on current activity
  Future<List<JobCategory>> getTrendingCategories() async {
    try {
      // TODO: Replace with actual API call
      // final response = await _apiClient.get('/api/v1/categories/trending');
      
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Mock trending categories
      return [
        JobCategory(
          id: 1,
          name: 'Plumbing',
          icon: 'plumbing',
          activeJobsCount: 45,
          availableWorkersCount: 23,
        ),
        JobCategory(
          id: 2,
          name: 'Electrical',
          icon: 'electrical_services',
          activeJobsCount: 32,
          availableWorkersCount: 18,
        ),
        JobCategory(
          id: 3,
          name: 'Painting',
          icon: 'format_paint',
          activeJobsCount: 28,
          availableWorkersCount: 31,
        ),
        JobCategory(
          id: 4,
          name: 'Carpentry',
          icon: 'construction',
          activeJobsCount: 19,
          availableWorkersCount: 12,
        ),
      ];
    } catch (e) {
      throw Exception('Failed to fetch trending categories: $e');
    }
  }

  /// Mock jobs data - TODO: Remove when API is integrated
  List<Job> _getMockJobs() {
    return [
      Job(
        id: 1,
        title: 'Emergency Pipe Repair',
        company: 'Plumbing Services',
        description: 'Urgent plumbing repair needed. Kitchen sink pipe burst, water damage concern.',
        location: 'Dagupan City',
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
        location: 'Pangasinan',
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
        location: 'Villanis',
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
    ];
  }

  /// Mock workers data - TODO: Remove when API is integrated
  List<WorkerProfile> _getMockWorkers() {
    return [
      WorkerProfile(
        id: 1,
        name: 'Juan Dela Cruz',
        primarySkill: 'Professional Plumber',
        skills: ['Plumbing', 'Pipe Repair', 'Installation'],
        location: 'Pangasinan',
        rating: 4.8,
        reviewCount: 120,
        isVerified: true,
        isAvailable: true,
        distance: 3.2,
        yearsOfExperience: 8,
        hourlyRate: 350,
        completedJobs: 95,
      ),
      WorkerProfile(
        id: 2,
        name: 'Maria Santos',
        primarySkill: 'Electrical Specialist',
        skills: ['Electrical', 'Wiring', 'Circuit Installation'],
        location: 'Dagupan City',
        rating: 4.9,
        reviewCount: 85,
        isVerified: true,
        isAvailable: true,
        distance: 5.1,
        yearsOfExperience: 6,
        hourlyRate: 400,
        completedJobs: 78,
      ),
      WorkerProfile(
        id: 3,
        name: 'Pedro Gonzales',
        primarySkill: 'Painting Expert',
        skills: ['Interior Painting', 'Exterior Painting'],
        location: 'Villanis',
        rating: 4.7,
        reviewCount: 65,
        isVerified: true,
        isAvailable: false,
        distance: 2.8,
        yearsOfExperience: 4,
        hourlyRate: 280,
        completedJobs: 52,
      ),
    ];
  }
}

/// Results from unified search API
class UnifiedSearchResults {
  final List<Job> jobs;
  final List<WorkerProfile> workers;
  final int totalJobsCount;
  final int totalWorkersCount;

  const UnifiedSearchResults({
    required this.jobs,
    required this.workers,
    required this.totalJobsCount,
    required this.totalWorkersCount,
  });

  factory UnifiedSearchResults.fromJson(Map<String, dynamic> json) {
    return UnifiedSearchResults(
      jobs: (json['jobs'] as List).map((e) => Job.fromJson(e)).toList(),
      workers: (json['workers'] as List).map((e) => WorkerProfile.fromJson(e)).toList(),
      totalJobsCount: json['total_jobs_count'],
      totalWorkersCount: json['total_workers_count'],
    );
  }

  bool get hasResults => jobs.isNotEmpty || workers.isNotEmpty;
  bool get hasJobs => jobs.isNotEmpty;
  bool get hasWorkers => workers.isNotEmpty;
}

/// Job category for trending categories display
class JobCategory {
  final int id;
  final String name;
  final String icon;
  final int activeJobsCount;
  final int availableWorkersCount;

  const JobCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.activeJobsCount,
    required this.availableWorkersCount,
  });

  factory JobCategory.fromJson(Map<String, dynamic> json) {
    return JobCategory(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
      activeJobsCount: json['active_jobs_count'],
      availableWorkersCount: json['available_workers_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'active_jobs_count': activeJobsCount,
      'available_workers_count': availableWorkersCount,
    };
  }
}