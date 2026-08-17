class WorkerSkillModel {
  final int? id;
  final int userId;
  final String skillName;
  /// Null means the worker never stated it.
  ///
  /// Nothing in the app asks for either yet. They used to be required, so the
  /// provider filled in "intermediate" and "1 year" for every skill just to
  /// satisfy the API — and the public profile showed that to employers as a
  /// claim the worker had made. On a hiring platform that is a fabricated
  /// credential, so null now means "not stated" and renders as nothing.
  final String? proficiencyLevel;
  final int? yearsOfExperience;
  final int? categoryId;
  final int? skillId;
  final String? categoryName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WorkerSkillModel({
    this.id,
    required this.userId,
    required this.skillName,
    this.proficiencyLevel,
    this.yearsOfExperience,
    this.categoryId,
    this.skillId,
    this.categoryName,
    this.createdAt,
    this.updatedAt,
  });

  factory WorkerSkillModel.fromJson(Map<String, dynamic> json) {
    return WorkerSkillModel(
      id: json['id'],
      userId: json['user_id'],
      skillName: json['skill_name'],
      proficiencyLevel: json['proficiency_level'],
      yearsOfExperience: json['years_of_experience'],
      categoryId: json['category_id'],
      skillId: json['skill_id'],
      categoryName: json['category_name'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'skill_name': skillName,
      // Omitted when unset, so the server stores null rather than a default.
      if (proficiencyLevel != null) 'proficiency_level': proficiencyLevel,
      if (yearsOfExperience != null) 'years_of_experience': yearsOfExperience,
      if (categoryId != null) 'category_id': categoryId,
      if (skillId != null) 'skill_id': skillId,
    };
  }
  
  String get displayName => categoryName != null ? '$categoryName: $skillName' : skillName;
}
