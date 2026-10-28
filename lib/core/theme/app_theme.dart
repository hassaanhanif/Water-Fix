import 'package:flutter/material.dart';

class WaterFixColors {
  // Exact palette from WaterFix-UI-Screens.pdf
  static const Color scaffoldBg = Color(0xFFF8F8F6);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFEBEBE6);
  static const Color primaryBlack = Color(0xFF111111);
  static const Color darkSurface = Color(0xFF141414);
  static const Color darkMetricCard = Color(0xFF222222);
  static const Color skyBlue = Color(0xFF8AD6F8);
  static const Color skyBlueLight = Color(0xFFE3F5FD);
  static const Color tankerBlue = Color(0xFF25537A);
  static const Color pastelBlueCard = Color(0xFFDCEAF3);
  static const Color pastelSageCard = Color(0xFFE6E8DE);
  static const Color coralAlertBg = Color(0xFFFDF0ED);
  static const Color coralAlertText = Color(0xFFD93829);
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF686863);
  static const Color textMuted = Color(0xFF969690);
  static const Color successGreen = Color(0xFF1F8A4C);
  static const Color emeraldSuccessBg = Color(0xFFE8F7EE);
  static const Color emeraldSuccessText = Color(0xFF1F8A4C);
  static const Color amberWarningBg = Color(0xFFFFF6E5);
  static const Color amberWarningText = Color(0xFFB45309);
  static const Color skyIce = Color(0xFFE3F5FD);
  static const Color deepBrandBlue = Color(0xFF25537A);
}

class WaterFixTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: WaterFixColors.scaffoldBg,
      colorScheme: ColorScheme.light(
        primary: WaterFixColors.primaryBlack,
        secondary: WaterFixColors.skyBlue,
        surface: WaterFixColors.cardBg,
        error: WaterFixColors.coralAlertText,
      ),
      fontFamily: 'Segoe UI',
      appBarTheme: const AppBarTheme(
        backgroundColor: WaterFixColors.scaffoldBg,
        foregroundColor: WaterFixColors.primaryBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: WaterFixColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: WaterFixColors.cardBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WaterFixColors.cardBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: WaterFixColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: WaterFixColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: WaterFixColors.primaryBlack,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: WaterFixColors.coralAlertText,
            width: 1.2,
          ),
        ),
      ),
    );
  }
}
