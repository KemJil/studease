import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Type scale for StudEase. Headings use the bundled Plus Jakarta Sans
/// (as in the prototype), body copy uses the platform sans.
class AppTypography {
  AppTypography._();

  static const String displayFamily = 'PlusJakartaSans';

  static const TextStyle screenTitle = TextStyle(
    fontFamily: displayFamily,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.4,
    color: AppColors.ink,
  );

  static const TextStyle heroTitle = TextStyle(
    fontFamily: displayFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: Colors.white,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: displayFamily,
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.ink,
  );

  static const TextStyle sectionLabel = TextStyle(
    fontFamily: displayFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.9,
    color: AppColors.inkFaint,
  );

  static const TextStyle badge = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static const TextStyle body = TextStyle(
    fontSize: 12.5,
    height: 1.5,
    color: AppColors.inkSoft,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 10.5,
    height: 1.4,
    color: AppColors.inkMuted,
  );

  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: displayFamily,
      fontSize: 30,
      fontWeight: FontWeight.w800,
      height: 1.15,
      letterSpacing: -0.6,
      color: AppColors.ink,
    ),
    displayMedium: TextStyle(
      fontFamily: displayFamily,
      fontSize: 24,
      fontWeight: FontWeight.w800,
      height: 1.18,
      letterSpacing: -0.5,
      color: AppColors.ink,
    ),
    headlineSmall: screenTitle,
    titleLarge: TextStyle(
      fontFamily: displayFamily,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: AppColors.ink,
    ),
    titleMedium: cardTitle,
    titleSmall: TextStyle(
      fontFamily: displayFamily,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    bodyLarge: TextStyle(fontSize: 14, height: 1.5, color: AppColors.inkSoft),
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: TextStyle(
      fontFamily: displayFamily,
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
      color: AppColors.ink,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: AppColors.inkMuted,
    ),
  );
}
