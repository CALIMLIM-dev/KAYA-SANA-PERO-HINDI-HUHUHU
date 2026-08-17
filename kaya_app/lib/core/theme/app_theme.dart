import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// KAYA Material 3 Theme
class AppTheme {
  /*
      The type scale.

      Twenty-four distinct font sizes were in use across the feature screens,
      seven of them — 12, 12.5, 13, 13.5, 14, 14.5, 15 — inside a three-pixel
      band. Nobody can see the difference between 13 and 13.5 on a phone. What
      they can see is that nothing is clearly a heading and nothing is clearly
      a caption, because every piece of text carries roughly the same weight.

      Six roles, plus two display sizes for figures that are meant to dominate.
      New code should reference these rather than typing a number, so the scale
      does not drift back.
  */
  static const double textDisplay = 32.0;   // hero figures
  static const double textNumber = 24.0;    // stat tiles
  static const double textTitle = 20.0;     // screen title
  static const double textHeading = 16.0;   // section heading
  static const double textCardTitle = 14.0; // card / row title
  static const double textBody = 13.5;      // body copy
  static const double textSecondary = 12.0; // supporting text
  static const double textCaption = 11.0;   // labels, chips, timestamps

  // Radii already exist below as radiusSmall / radiusMedium / radiusLarge.
  // Ten distinct values are in use across the screens (2, 4, 5, 6, 8, 10, 12,
  // 16, 20, 28) — 12 accounts for 279 of them, so the rest are noise. New code
  // should use the three constants rather than a literal.

  // Spacing
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  
  // Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double buttonRadius = 12.0;
  static const double pillRadius = 28.0;
  static const double cardRadius = 16.0;
  
  // Color aliases for backward compatibility
  static const Color primaryColor = AppColors.primary;
  static const Color primaryLight = AppColors.primaryLight;
  static const Color accentColor = AppColors.accent;
  static const Color successColor = AppColors.success;
  static const Color warningColor = AppColors.warning;
  static const Color dangerColor = AppColors.error;
  static const Color surfaceColor = AppColors.surface;
  static const Color neutral200 = AppColors.neutral200;
  static const Color neutral600 = AppColors.neutral600;
  static const Color neutral900 = AppColors.neutral900;
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(fontSize: 16),
        bodyMedium: GoogleFonts.inter(fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
        ),
      ),
    );
  }
}
