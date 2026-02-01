import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Backgrounds
  static const Color backgroundDark = Color(0xFF181920); // Deep Void Blue
  static const Color backgroundLight = Color(0xFF252630); // Slightly lighter for cards

  // Accents & Gradients
  static const Color primaryPurple = Color(0xFF6C63FF);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color accentPink = Color(0xFFFF2E63);

  // Glassmorphism
  static Color glassWhite = Colors.white.withOpacity(0.05);
  static Color glassBorder = Colors.white.withOpacity(0.1);
  
  // Text
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFFA0A0A0);
  
  // Status Colors
  static const Color income = Color(0xFF00C853); // Green Accent
  static const Color expense = Color(0xFFFF5252); // Red Accent
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
