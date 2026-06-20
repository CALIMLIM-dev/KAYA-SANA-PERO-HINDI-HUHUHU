import 'package:flutter/material.dart';

/// KAYA App Colors - Material 3 Design
class AppColors {
  // Primary Brand Colors
  static const Color primary = Color(0xFF3D5CFF);
  static const Color primaryLight = Color(0xFF6B7FFF);
  static const Color primaryDark = Color(0xFF2541E8);
  
  // Accent Colors
  static const Color accent = Color(0xFFFFD600);
  static const Color accentLight = Color(0xFFFFE54C);
  static const Color accentDark = Color(0xFFFFC400);
  
  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Neutral Colors
  static const Color neutral900 = Color(0xFF212121);
  static const Color neutral800 = Color(0xFF424242);
  static const Color neutral700 = Color(0xFF616161);
  static const Color neutral600 = Color(0xFF757575);
  static const Color neutral500 = Color(0xFF9E9E9E);
  static const Color neutral400 = Color(0xFFBDBDBD);
  static const Color neutral300 = Color(0xFFE0E0E0);
  static const Color neutral200 = Color(0xFFEEEEEE);
  static const Color neutral100 = Color(0xFFF5F5F5);
  static const Color neutral50 = Color(0xFFFAFAFA);
  
  // Text Colors (aliases for compatibility)
  static const Color textPrimary = neutral900;
  static const Color textSecondary = neutral600;
  
  // Background Colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F5);
  
  // Category Colors - All use primary color for consistency
  static const Color categoryIcon = primary; // Single color for all categories
  
  // Legacy category colors (deprecated - use categoryIcon instead)
  @Deprecated('Use categoryIcon instead for consistency')
  static const Color plumbing = primary;
  @Deprecated('Use categoryIcon instead for consistency')
  static const Color electrical = primary;
  @Deprecated('Use categoryIcon instead for consistency')
  static const Color painting = primary;
  @Deprecated('Use categoryIcon instead for consistency')
  static const Color carpentry = primary;
  @Deprecated('Use categoryIcon instead for consistency')
  static const Color construction = primary;
  @Deprecated('Use categoryIcon instead for consistency')
  static const Color cleaning = primary;
  
  // Verification Badge
  static const Color verified = Color(0xFF4CAF50);
  static const Color unverified = Color(0xFF9E9E9E);
  
  // Application Status Colors
  static const Color pending = Color(0xFFFF9800);
  static const Color accepted = Color(0xFF4CAF50);
  static const Color rejected = Color(0xFFF44336);
  static const Color completed = Color(0xFF2196F3);
}
