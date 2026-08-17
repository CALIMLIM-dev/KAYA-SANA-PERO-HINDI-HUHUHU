/// Job Model for KAYA app
class Job {
  final int id;
  final String title;
  final String company;
  final String? description;
  final String? location;
  final double? salaryMin;
  final double? salaryMax;
  final String salaryPeriod; // 'hour', 'day', 'month'
  final bool isUrgent;
  final bool isNegotiable;
  final bool requiresVerification;
  final double? distance; // in kilometers
  final DateTime? postedAt;
  final bool isActive;
  final ApplicationStatus? applicationStatus;
  final String? category;
  final List<String> requiredSkills;
  final int applicantCount;

  /// Server-computed match (0-100) for the signed-in worker, from
  /// JobMatchService — same scoring an employer sees on their applicant list.
  /// Null when the account has no worker profile to score against.
  final int? matchScore;
  final List<String> matchedSkills;
  final int? jobId;
  final int? categoryId;
  final int? locationId;

  // Populated by GET /jobs/{id} only — the list endpoints don't compute these
  // per-row to keep the query cheap.
  final int? employerId;
  final String? employerAvatar;
  final bool hasApplied;
  final bool isSaved;
  final bool isOwnJob;
  final List<String> photoUrls;

  const Job({
    required this.id,
    required this.title,
    required this.company,
    this.description,
    this.location,
    this.salaryMin,
    this.salaryMax,
    this.salaryPeriod = 'project',
    this.isUrgent = false,
    this.isNegotiable = false,
    this.requiresVerification = false,
    this.distance,
    this.postedAt,
    this.isActive = true,
    this.applicationStatus,
    this.category,
    this.requiredSkills = const [],
    this.applicantCount = 0,
    this.matchScore,
    this.matchedSkills = const [],
    this.jobId,
    this.categoryId,
    this.locationId,
    this.employerId,
    this.employerAvatar,
    this.hasApplied = false,
    this.isSaved = false,
    this.isOwnJob = false,
    this.photoUrls = const [],
  });

  /// Maps a raw `jobs_posts` row from the Laravel API (GET /jobs, /jobs/my,
  /// /jobs/{id}) to this model. The mock `fromJson` above expects different
  /// field names ('company', 'salary_min', 'posted_at') that the real API
  /// never sends, so it silently produced blank cards if pointed at live data.
  factory Job.fromApi(Map<String, dynamic> json) {
    double? asDouble(Object? v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

    final category = json['category'] as Map<String, dynamic>?;
    final employer = json['employer'] as Map<String, dynamic>?;
    // GET /jobs/{id} nests the same info under employer_information instead.
    final employerInfo = json['employer_information'] as Map<String, dynamic>?;
    final skills = json['skills'] as List?;

    final status = (json['application_status'] as String?);

    return Job(
      id: json['id'] as int,
      title: (json['title'] ?? '').toString(),
      company: (employer?['name'] ?? employerInfo?['name'] ?? '').toString(),
      description: json['description'] as String?,
      location: (json['city'] ?? json['location']) as String?,
      salaryMin: asDouble(json['budget_min']),
      salaryMax: asDouble(json['budget_max']),
      salaryPeriod: (json['budget_period'] as String?) ?? 'project',
      isUrgent: json['is_urgent'] as bool? ?? false,
      isNegotiable: json['is_negotiable'] as bool? ?? false,
      requiresVerification: (employer?['is_verified'] as bool?) ??
          (employerInfo?['verification_status'] as bool?) ??
          false,
      postedAt:
          json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      isActive: json['status'] == 'open',
      category: category?['name'] as String?,
      categoryId: category?['id'] as int? ?? json['category_id'] as int?,
      locationId: json['location_id'] as int?,
      requiredSkills: skills == null
          ? const []
          : skills
              .map((s) => (s as Map<String, dynamic>)['name']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList(),
      applicantCount: (json['application_count'] as num?)?.toInt() ?? 0,
      matchScore: (json['match_score'] as num?)?.toInt(),
      matchedSkills: (json['matched_skills'] as List?)
              ?.map((s) => s.toString())
              .toList() ??
          const [],
      employerId: (employerInfo?['employer_id'] ?? json['employer_id']) as int?,
      employerAvatar: employerInfo?['profile_photo_path'] as String?,
      hasApplied: json['has_applied'] as bool? ?? (status != null),
      applicationStatus: status == null
          ? null
          : ApplicationStatus.values.firstWhere(
              (e) => e.name == status,
              orElse: () => ApplicationStatus.pending,
            ),
      isSaved: json['is_saved'] as bool? ?? false,
      isOwnJob: json['is_own_job'] as bool? ?? false,
      photoUrls: (json['photo_urls'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'],
      title: json['title'],
      company: json['company'],
      description: json['description'],
      location: json['location'],
      salaryMin: json['salary_min']?.toDouble(),
      salaryMax: json['salary_max']?.toDouble(),
      salaryPeriod: json['salary_period'] ?? 'day',
      isUrgent: json['is_urgent'] ?? false,
      requiresVerification: json['requires_verification'] ?? false,
      distance: json['distance_km']?.toDouble(),
      postedAt: json['posted_at'] != null ? DateTime.parse(json['posted_at']) : null,
      isActive: json['is_active'] ?? true,
      applicationStatus: json['application_status'] != null 
          ? ApplicationStatus.values.firstWhere((e) => e.name == json['application_status'])
          : null,
      category: json['category'],
      requiredSkills: List<String>.from(json['required_skills'] ?? []),
      applicantCount: json['applicant_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'company': company,
      'description': description,
      'location': location,
      'salary_min': salaryMin,
      'salary_max': salaryMax,
      'salary_period': salaryPeriod,
      'is_urgent': isUrgent,
      'requires_verification': requiresVerification,
      'distance_km': distance,
      'posted_at': postedAt?.toIso8601String(),
      'is_active': isActive,
      'application_status': applicationStatus?.name,
      'category': category,
      'required_skills': requiredSkills,
      'applicant_count': applicantCount,
    };
  }

  Job copyWith({
    int? id,
    String? title,
    String? company,
    String? description,
    String? location,
    double? salaryMin,
    double? salaryMax,
    String? salaryPeriod,
    bool? isUrgent,
    bool? requiresVerification,
    double? distance,
    DateTime? postedAt,
    bool? isActive,
    ApplicationStatus? applicationStatus,
    String? category,
    List<String>? requiredSkills,
    int? applicantCount,
  }) {
    return Job(
      id: id ?? this.id,
      title: title ?? this.title,
      company: company ?? this.company,
      description: description ?? this.description,
      location: location ?? this.location,
      salaryMin: salaryMin ?? this.salaryMin,
      salaryMax: salaryMax ?? this.salaryMax,
      salaryPeriod: salaryPeriod ?? this.salaryPeriod,
      isUrgent: isUrgent ?? this.isUrgent,
      requiresVerification: requiresVerification ?? this.requiresVerification,
      distance: distance ?? this.distance,
      postedAt: postedAt ?? this.postedAt,
      isActive: isActive ?? this.isActive,
      applicationStatus: applicationStatus ?? this.applicationStatus,
      category: category ?? this.category,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      applicantCount: applicantCount ?? this.applicantCount,
    );
  }
}

enum ApplicationStatus {
  pending,
  accepted,
  rejected,
  withdrawn,
}