class WorkerSkillModel {
  final int? id;
  final int userId;
  final String skillName;
  final String proficiencyLevel;
  final int yearsOfExperience;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WorkerSkillModel({
    this.id,
    required this.userId,
    required this.skillName,
    required this.proficiencyLevel,
    required this.yearsOfExperience,
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
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'skill_name': skillName,
      'proficiency_level': proficiencyLevel,
      'years_of_experience': yearsOfExperience,
    };
  }
}
