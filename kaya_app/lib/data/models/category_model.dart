class CategoryModel {
  final int id;
  final String name;
  final String? icon;
  final bool isActive;
  final bool isCustom;
  final int? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.isActive = true,
    this.isCustom = false,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
      isActive: json['is_active'] ?? true,
      isCustom: json['is_custom'] ?? false,
      createdBy: json['created_by'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (icon != null) 'icon': icon,
      'is_active': isActive,
      'is_custom': isCustom,
      if (createdBy != null) 'created_by': createdBy,
    };
  }
}
