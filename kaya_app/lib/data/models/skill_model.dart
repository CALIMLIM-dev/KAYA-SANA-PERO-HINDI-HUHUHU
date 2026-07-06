class SkillModel {
  final int id;
  final String name;
  final int categoryId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SkillModel({
    required this.id,
    required this.name,
    required this.categoryId,
    this.createdAt,
    this.updatedAt,
  });

  factory SkillModel.fromJson(Map<String, dynamic> json) {
    return SkillModel(
      id: json['id'],
      name: json['name'],
      categoryId: json['category_id'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
    };
  }
}
