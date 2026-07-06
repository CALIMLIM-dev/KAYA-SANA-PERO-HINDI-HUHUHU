import '../../../core/constants/employer_type.dart';

/// Employer Profile Model
/// 
/// Immutable model representing an employer profile
class EmployerProfile {
  final int id;
  final int userId;
  final EmployerType employerType;
  final String? companyName;
  final String? industry;
  final String? website;
  final String? description;
  final String location;
  final String? imagePath;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmployerProfile({
    required this.id,
    required this.userId,
    required this.employerType,
    this.companyName,
    this.industry,
    this.website,
    this.description,
    required this.location,
    this.imagePath,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Parse from API response
  factory EmployerProfile.fromJson(Map<String, dynamic> json) {
    return EmployerProfile(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      employerType: EmployerType.fromString(json['employer_type'] as String?) ?? EmployerType.individual,
      companyName: json['company_name'] as String?,
      industry: json['industry'] as String?,
      website: json['website'] as String?,
      description: json['description'] as String?,
      location: json['location'] as String? ?? '',
      imagePath: json['image_path'] as String?,
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'employer_type': employerType.value,
      if (companyName != null) 'company_name': companyName,
      if (industry != null) 'industry': industry,
      if (website != null) 'website': website,
      if (description != null) 'description': description,
      'location': location,
    };
  }

  /// Get display name based on employer type
  String get displayName {
    return switch (employerType) {
      EmployerType.company => companyName ?? 'Company Name',
      EmployerType.individual => 'Individual Employer', // Will use users.name from auth
    };
  }

  /// Check if profile is complete (all required fields filled)
  bool get isComplete {
    return switch (employerType) {
      EmployerType.company => 
        companyName != null && 
        companyName!.isNotEmpty &&
        industry != null && 
        industry!.isNotEmpty &&
        location.isNotEmpty,
      EmployerType.individual => 
        location.isNotEmpty,
    };
  }

  /// Get list of missing required fields
  List<String> get missingFields {
    final missing = <String>[];
    
    if (location.isEmpty) {
      missing.add('Location');
    }

    if (employerType == EmployerType.company) {
      if (companyName == null || companyName!.isEmpty) {
        missing.add('Company Name');
      }
      if (industry == null || industry!.isEmpty) {
        missing.add('Industry');
      }
    }

    return missing;
  }

  /// Copy with new values
  EmployerProfile copyWith({
    int? id,
    int? userId,
    EmployerType? employerType,
    String? companyName,
    String? industry,
    String? website,
    String? description,
    String? location,
    String? imagePath,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployerProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      employerType: employerType ?? this.employerType,
      companyName: companyName ?? this.companyName,
      industry: industry ?? this.industry,
      website: website ?? this.website,
      description: description ?? this.description,
      location: location ?? this.location,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmployerProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          employerType == other.employerType &&
          companyName == other.companyName &&
          industry == other.industry &&
          website == other.website &&
          description == other.description &&
          location == other.location &&
          imagePath == other.imagePath &&
          imageUrl == other.imageUrl;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      employerType.hashCode ^
      companyName.hashCode ^
      industry.hashCode ^
      website.hashCode ^
      description.hashCode ^
      location.hashCode ^
      imagePath.hashCode ^
      imageUrl.hashCode;

  @override
  String toString() {
    return 'EmployerProfile(id: $id, userId: $userId, employerType: $employerType, companyName: $companyName, location: $location)';
  }
}
