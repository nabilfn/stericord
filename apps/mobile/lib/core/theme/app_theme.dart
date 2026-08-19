import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF0B1F3A);
  static const navyLight = Color(0xFF132C52);
  static const teal = Color(0xFF0F766E);
  static const scBlue = Color(0xFF3B82F6);
  static const scBlueLight = Color(0xFFE6F1FB);
  static const pass = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const fail = Color(0xFFDC2626);
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navy,
        primary: AppColors.navy,
        secondary: AppColors.teal,
        error: AppColors.fail,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
