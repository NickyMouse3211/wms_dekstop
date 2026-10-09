import 'package:flutter/material.dart';

abstract final class WmsColors {
  static const primary = Color(0xFFE60012);
  static const primaryDark = Color(0xFFC40010);
  static const primaryLight = Color(0xFFFFE5E8);
  static const textPrimary = Color(0xFF111111);
  static const textSecondary = Color(0xFF666666);
  static const textLight = Color(0xFF999999);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF8F8F8);
  static const border = Color(0xFFE2E2E2);
  static const success = Color(0xFF28A745);
  static const warning = Color(0xFFF59E0B);
}

abstract final class WmsTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: WmsColors.primary,
      primary: WmsColors.primary,
      surface: WmsColors.surface,
      onSurface: WmsColors.textPrimary,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: WmsColors.surfaceSoft,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w700,
          color: WmsColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: WmsColors.textPrimary,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: WmsColors.textPrimary),
        bodySmall: TextStyle(fontSize: 12, color: WmsColors.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: WmsColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: WmsColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WmsColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: WmsColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: WmsColors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: WmsColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WmsColors.primary,
          side: const BorderSide(color: WmsColors.primary),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: WmsColors.textPrimary,
        contentTextStyle: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
      ),
    );
  }
}
