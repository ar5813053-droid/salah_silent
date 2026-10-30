import 'package:flutter/material.dart';

class AppColors {
  static const Color deepNavy = Color(0xFF101B2A);
  static const Color softGold = Color(0xFFD8B875);
  static const Color white = Color(0xFFFFFFFF);
  static const Color mutedGrey = Color(0xFF8994A3);
  static const Color cardDark = Color(0xFF1A2536);
  static const Color surface = Color(0xFF162032);

  /// Glass fills (no heavy blur required)
  static const Color glassFill = Color(0x331A2536);
  static const Color glassFillStrong = Color(0x99121C2B);
  static const Color glassBorder = Color(0x40D8B875);
  static const Color glassHighlight = Color(0x22FFFFFF);
}

class AppRadii {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double pill = 28;
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.deepNavy,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.softGold,
        secondary: AppColors.softGold,
        surface: AppColors.surface,
        onPrimary: AppColors.deepNavy,
        onSurface: AppColors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.glassFillStrong,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: const BorderSide(color: AppColors.glassBorder, width: 0.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.softGold,
          foregroundColor: AppColors.deepNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: TextStyle(color: AppColors.mutedGrey),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
