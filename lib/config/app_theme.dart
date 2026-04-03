import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Backgrounds
  static const Color backgroundDark = Color(0xFF0F1523); // Deep Petrol Navy
  static const Color backgroundLight = Color(0xFF161F33); // Translucent Metallic Blue

  // Accents & Gradients
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentPink = Color(0xFFF43F5E);

  // Dashboard Specific
  static const Color panelBorder = Color(0xFF2B354C);
  static const Color hoverGlow = Color(0x4406B6D4);

  // Glassmorphism
  static Color glassWhite = Colors.white.withOpacity(0.03);
  static Color glassBorder = Colors.white.withOpacity(0.1);
  
  // Text
  static const Color textWhite = Color(0xFFF8FAFC);
  static const Color textGrey = Color(0xFF94A3B8);
  
  // Status Colors
  static const Color income = Color(0xFF10B981); // Emerald Green
  static const Color expense = Color(0xFFEF4444); // Red
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      primaryColor: AppColors.primaryPurple,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryPurple,
        secondary: AppColors.secondaryBlue,
        surface: AppColors.backgroundLight,
        background: AppColors.backgroundDark,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme.apply(
          bodyColor: AppColors.textWhite,
          displayColor: AppColors.textWhite,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textWhite),
    );
  }
}
