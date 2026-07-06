class WorkerExperienceModel {
  final int? id;
  final int? userId;
  final String jobTitle;
  final String companyName;
  final String? description;
  final String startDate;
  final String? endDate;
  final bool isCurrent;
  final String? createdAt;
  final String? updatedAt;

  WorkerExperienceModel({
    this.id,
    this.userId,
    required this.jobTitle,
    required this.companyName,
    this.description,
    required this.startDate,
    this.endDate,
    this.isCurrent = false,
    this.createdAt,
    this.updatedAt,
  });

  factory WorkerExperienceModel.fromJson(Map<String, dynamic> json) {
    return WorkerExperienceModel(
      id: json['id'] as int?,
      userId: json['user_id'] as int?,
      jobTitle: json['job_title'] as String? ?? '',
      companyName: json['company_name'] as String? ?? '',
      description: json['description'] as String?,
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String?,
      isCurrent: json['is_current'] == 1 || json['is_current'] == true,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      'job_title': jobTitle,
      'company_name': companyName,
      'description': description,
      'start_date': startDate,
      'end_date': endDate,
      'is_current': isCurrent,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }
}
