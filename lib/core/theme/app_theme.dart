import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  /// LIGHT THEME
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    primaryColor: AppColors.primaryLight,
    fontFamily: 'Poppins',

    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.lightText),
      bodyMedium: TextStyle(color: AppColors.lightText),
    ),

    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryLight,
      secondary: AppColors.primaryLight,
      surface: AppColors.lightBackground,
      onPrimary: Colors.white,
      onSurface: AppColors.lightText,
    ),
  );

  /// DARK THEME
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    primaryColor: AppColors.primaryDark,
    fontFamily: 'Poppins',

    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.darkText),
      bodyMedium: TextStyle(color: AppColors.darkText),
    ),

    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryDark,
      secondary: AppColors.primaryDark,
      surface: AppColors.darkBackground,
      onPrimary: Colors.white,
      onSurface: AppColors.darkText,
    ),
  );
}
