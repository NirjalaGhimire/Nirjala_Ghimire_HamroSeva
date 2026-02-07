import 'package:flutter/material.dart';

/// Prototype colors: light lavender bg, dark grey for headers/buttons.
/// Customer UI uses blue (customerPrimary) for app bar, nav, and accents.
class AppTheme {
  static const Color darkGrey = Color(0xFF2D3250);
  static const Color lightLavender = Color(0xFFE0E0EB);
  static const Color primaryButton = Color(0xFF2D3250);
  static const Color linkRed = Color(0xFFE53935);
  static const Color white = Colors.white;
  /// Customer UI primary (deep indigo/slate blue) - headers, selected nav, buttons, accents.
  static const Color customerPrimary = Color(0xFF3A3F67);
  static const Color customerPrimaryDark = Color(0xFF2A2E4A);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: darkGrey,
          primary: darkGrey,
          surface: lightLavender,
          onPrimary: white,
          onSurface: darkGrey,
        ),
        scaffoldBackgroundColor: lightLavender,
        appBarTheme: const AppBarTheme(
          backgroundColor: darkGrey,
          foregroundColor: white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryButton,
            foregroundColor: white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: darkGrey,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
      );
}
