/// Verification Status Enum
enum VerificationStatus {
  notSubmitted('not_submitted', 'Not Submitted'),
  pending('pending', 'Pending Review'),
  verified('verified', 'Verified'),
  rejected('rejected', 'Rejected');

  final String value;
  final String label;

  const VerificationStatus(this.value, this.label);

  static VerificationStatus fromString(String? value) {
    if (value == null) return VerificationStatus.notSubmitted;
    return VerificationStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => VerificationStatus.notSubmitted,
    );
  }
}

/// Employer Verification Model
/// 
/// Immutable model representing employer verification state
class EmployerVerification {
  final bool identityVerified;
  final String identityStatus;
  final bool businessVerified;
  final String businessStatus;
  final bool requiresBusinessVerification;
  final bool fullyVerified;

  const EmployerVerification({
    required this.identityVerified,
    required this.identityStatus,
    required this.businessVerified,
    required this.businessStatus,
    required this.requiresBusinessVerification,
    required this.fullyVerified,
  });

  /// Parse from API response
  factory EmployerVerification.fromJson(Map<String, dynamic> json) {
    return EmployerVerification(
      identityVerified: json['identity_verified'] as bool? ?? false,
      identityStatus: json['identity_status'] as String? ?? 'unverified',
      businessVerified: json['business_verified'] as bool? ?? false,
      businessStatus: json['business_status'] as String? ?? 'unverified',
      requiresBusinessVerification: json['requires_business_verification'] as bool? ?? false,
      fullyVerified: json['fully_verified'] as bool? ?? false,
    );
  }

  /// Get overall verification status for UI display
  VerificationStatus get status {
    if (fullyVerified) {
      return VerificationStatus.verified;
    } else if (identityStatus == 'pending' || businessStatus == 'pending') {
      return VerificationStatus.pending;
    } else if (identityStatus == 'rejected' || businessStatus == 'rejected') {
      return VerificationStatus.rejected;
    } else {
      return VerificationStatus.notSubmitted;
    }
  }

  /// Get human-readable verification message
  String get statusMessage {
    if (fullyVerified) {
      return 'Your account is fully verified';
    } else if (identityStatus == 'pending') {
      return 'Your government ID is under admin review';
    } else if (identityStatus == 'rejected') {
      return 'Your government ID was rejected. Please submit a new one.';
    } else if (!identityVerified) {
      return 'Submit your government ID to verify your account';
    } else if (requiresBusinessVerification && businessStatus == 'pending') {
      return 'Your business registration is under admin review';
    } else if (requiresBusinessVerification && businessStatus == 'rejected') {
      return 'Your business registration was rejected. Please submit a new one.';
    } else if (requiresBusinessVerification && !businessVerified) {
      return 'Submit your business permit or registration';
    } else {
      return 'Verification in progress';
    }
  }

  /// Copy with new values
  EmployerVerification copyWith({
    bool? identityVerified,
    String? identityStatus,
    bool? businessVerified,
    String? businessStatus,
    bool? requiresBusinessVerification,
    bool? fullyVerified,
  }) {
    return EmployerVerification(
      identityVerified: identityVerified ?? this.identityVerified,
      identityStatus: identityStatus ?? this.identityStatus,
      businessVerified: businessVerified ?? this.businessVerified,
      businessStatus: businessStatus ?? this.businessStatus,
      requiresBusinessVerification: requiresBusinessVerification ?? this.requiresBusinessVerification,
      fullyVerified: fullyVerified ?? this.fullyVerified,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmployerVerification &&
          runtimeType == other.runtimeType &&
          identityVerified == other.identityVerified &&
          identityStatus == other.identityStatus &&
          businessVerified == other.businessVerified &&
          businessStatus == other.businessStatus &&
          requiresBusinessVerification == other.requiresBusinessVerification &&
          fullyVerified == other.fullyVerified;

  @override
  int get hashCode =>
      identityVerified.hashCode ^
      identityStatus.hashCode ^
      businessVerified.hashCode ^
      businessStatus.hashCode ^
      requiresBusinessVerification.hashCode ^
      fullyVerified.hashCode;

  @override
  String toString() {
    return 'EmployerVerification(identityVerified: $identityVerified, identityStatus: $identityStatus, businessVerified: $businessVerified, businessStatus: $businessStatus, requiresBusinessVerification: $requiresBusinessVerification, fullyVerified: $fullyVerified)';
  }
}
