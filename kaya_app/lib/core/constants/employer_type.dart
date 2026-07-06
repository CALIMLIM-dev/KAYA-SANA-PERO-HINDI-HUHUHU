import 'package:flutter/material.dart';

/// Employer Type Enum
/// 
/// Matches backend EmployerType enum
enum EmployerType {
  company('company', 'Company'),
  individual('individual', 'Individual');

  final String value;
  final String label;

  const EmployerType(this.value, this.label);

  /// Parse from API string value
  static EmployerType? fromString(String? value) {
    if (value == null) return null;
    return EmployerType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => EmployerType.individual,
    );
  }

  /// Check if this employer type requires business verification
  bool get requiresBusinessVerification {
    return switch (this) {
      EmployerType.company => true,
      EmployerType.individual => false,
    };
  }

  /// Get icon for this employer type
  IconData get icon {
    return switch (this) {
      EmployerType.company => Icons.business_center,
      EmployerType.individual => Icons.person,
    };
  }

  /// Get description for onboarding
  String get description {
    return switch (this) {
      EmployerType.company =>
        'Perfect for businesses and organizations looking to hire skilled workers for projects and ongoing work. You\'ll be able to post multiple jobs and manage a team.',
      EmployerType.individual =>
        'Ideal for homeowners and individuals hiring workers for personal projects like home repairs, renovations, or one-time tasks.',
    };
  }
}
