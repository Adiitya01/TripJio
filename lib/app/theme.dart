import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF003F7D); // Sapphire Navy
  static const Color secondaryColor = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
      ),
      scaffoldBackgroundColor: primaryColor,
    );
  }
}
