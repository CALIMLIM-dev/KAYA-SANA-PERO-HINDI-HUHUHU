import '../../core/utils/json_parse.dart';

/// Worker Profile Model for KAYA app
class WorkerProfile {
  final int id;
  final String name;
  final String primarySkill;
  final List<String> skills;
  final String? location;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final bool isAvailable;
  final double? distance; // in kilometers
  final String? bio;
  final int yearsOfExperience;
  final double? hourlyRate;
  final String? profileImageUrl;
  final List<String> certifications;
  final DateTime? lastActive;
  final int completedJobs;

  /// Set when this worker came from a browse call scoped to a specific job
  /// (e.g. suggested-workers-for-this-job), mirroring Job.matchScore.
  final int? matchScore;
  final int? userId;
  final int? categoryId;
  final int? locationId;

  /// What the worker charges. `rateLabel` is the server's phrasing — always
  /// prefer it over reassembling the numbers, so every screen reads the same.
  /// Null when the worker has not set a rate; show nothing rather than "₱0".
  final double? rateMin;
  final double? rateMax;
  final String? rateUnit;
  final String? rateLabel;

  const WorkerProfile({
    required this.id,
    required this.name,
    required this.primarySkill,
    this.skills = const [],
    this.location,
    required this.rating,
    required this.reviewCount,
    this.isVerified = false,
    this.isAvailable = true,
    this.distance,
    this.bio,
    this.yearsOfExperience = 0,
    this.hourlyRate,
    this.profileImageUrl,
    this.certifications = const [],
    this.lastActive,
    this.completedJobs = 0,
    this.matchScore,
    this.userId,
    this.categoryId,
    this.locationId,
    this.rateMin,
    this.rateMax,
    this.rateUnit,
    this.rateLabel,
  });

  /// Maps a raw worker row from the real API (GET /workers, or the `data` array
  /// inside GET /jobs/{job}/matches) to this model. `fromJson` above expects a
  /// mock shape ('primary_skill', 'is_available', 'hourly_rate') the backend
  /// never returns.
  factory WorkerProfile.fromApi(Map<String, dynamic> json) {
    final skills = (json['skills'] as List?)?.map((s) => s.toString()).toList() ??
        const <String>[];

    return WorkerProfile(
      id: (json['user_id'] ?? json['id']) as int,
      userId: json['user_id'] as int?,
      name: (json['name'] ?? '').toString(),
      primarySkill: skills.isNotEmpty ? skills.first : (json['category'] ?? '').toString(),
      skills: skills,
      location: json['location'] as String?,
      locationId: json['location_id'] as int?,
      categoryId: json['category_id'] as int?,
      // rating_avg is a Laravel decimal cast — arrives as the string "0.00".
      rating: asDouble(json['rating_avg']),
      reviewCount: asInt(json['rating_count']),
      // Straight-line km from whoever is browsing, computed server-side.
      distance: asDoubleOrNull(json['distance_km']),
      isVerified: json['is_verified'] as bool? ?? false,
      isAvailable: (json['availability_status'] ?? 'available') == 'available',
      bio: json['bio'] as String?,
      profileImageUrl: json['avatar'] as String?,
      matchScore: (json['match_score'] as num?)?.toInt(),
      // Decimal casts arrive as strings, same as rating_avg above.
      rateMin: asDoubleOrNull(json['rate_min']),
      rateMax: asDoubleOrNull(json['rate_max']),
      rateUnit: json['rate_unit'] as String?,
      rateLabel: json['rate_label'] as String?,
    );
  }

  factory WorkerProfile.fromJson(Map<String, dynamic> json) {
    return WorkerProfile(
      id: json['id'],
      name: json['name'],
      primarySkill: json['primary_skill'],
      skills: List<String>.from(json['skills'] ?? []),
      location: json['location'],
      rating: json['rating']?.toDouble() ?? 0.0,
      reviewCount: json['review_count'] ?? 0,
      isVerified: json['is_verified'] ?? false,
      isAvailable: json['is_available'] ?? true,
      distance: json['distance_km']?.toDouble(),
      bio: json['bio'],
      yearsOfExperience: json['years_of_experience'] ?? 0,
      hourlyRate: json['hourly_rate']?.toDouble(),
      profileImageUrl: json['profile_image_url'],
      certifications: List<String>.from(json['certifications'] ?? []),
      lastActive: json['last_active'] != null ? DateTime.parse(json['last_active']) : null,
      completedJobs: json['completed_jobs'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'primary_skill': primarySkill,
      'skills': skills,
      'location': location,
      'rating': rating,
      'review_count': reviewCount,
      'is_verified': isVerified,
      'is_available': isAvailable,
      'distance_km': distance,
      'bio': bio,
      'years_of_experience': yearsOfExperience,
      'hourly_rate': hourlyRate,
      'profile_image_url': profileImageUrl,
      'certifications': certifications,
      'last_active': lastActive?.toIso8601String(),
      'completed_jobs': completedJobs,
    };
  }

  WorkerProfile copyWith({
    int? id,
    String? name,
    String? primarySkill,
    List<String>? skills,
    String? location,
    double? rating,
    int? reviewCount,
    bool? isVerified,
    bool? isAvailable,
    double? distance,
    String? bio,
    int? yearsOfExperience,
    double? hourlyRate,
    String? profileImageUrl,
    List<String>? certifications,
    DateTime? lastActive,
    int? completedJobs,
  }) {
    return WorkerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      primarySkill: primarySkill ?? this.primarySkill,
      skills: skills ?? this.skills,
      location: location ?? this.location,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isVerified: isVerified ?? this.isVerified,
      isAvailable: isAvailable ?? this.isAvailable,
      distance: distance ?? this.distance,
      bio: bio ?? this.bio,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      certifications: certifications ?? this.certifications,
      lastActive: lastActive ?? this.lastActive,
      completedJobs: completedJobs ?? this.completedJobs,
    );
  }

  /// Get initials for avatar display
  String get initials {
    final names = name.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Get display name for availability status
  String get availabilityText {
    if (!isAvailable) return 'Busy';
    if (lastActive != null) {
      final difference = DateTime.now().difference(lastActive!);
      if (difference.inMinutes < 30) return 'Online';
      if (difference.inHours < 24) return 'Recently active';
    }
    return 'Available';
  }

  /// Get color for availability status
  int get availabilityColorValue {
    if (!isAvailable) return 0xFF9E9E9E; // neutral400
    if (lastActive != null) {
      final difference = DateTime.now().difference(lastActive!);
      if (difference.inMinutes < 30) return 0xFF4CAF50; // success
      if (difference.inHours < 24) return 0xFFFF9800; // warning
    }
    return 0xFF4CAF50; // success
  }

  /// Format rating display
  String get ratingDisplay {
    return '${rating.toStringAsFixed(1)} ($reviewCount+ reviews)';
  }

  /// Format experience display
  String get experienceDisplay {
    if (yearsOfExperience == 0) return 'New to platform';
    if (yearsOfExperience == 1) return '1 year experience';
    return '$yearsOfExperience years experience';
  }
}