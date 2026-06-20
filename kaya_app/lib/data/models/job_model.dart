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
  final bool requiresVerification;
  final double? distance; // in kilometers
  final DateTime? postedAt;
  final bool isActive;
  final ApplicationStatus? applicationStatus;
  final String? category;
  final List<String> requiredSkills;
  final int applicantCount;

  const Job({
    required this.id,
    required this.title,
    required this.company,
    this.description,
    this.location,
    this.salaryMin,
    this.salaryMax,
    this.salaryPeriod = 'day',
    this.isUrgent = false,
    this.requiresVerification = false,
    this.distance,
    this.postedAt,
    this.isActive = true,
    this.applicationStatus,
    this.category,
    this.requiredSkills = const [],
    this.applicantCount = 0,
  });

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