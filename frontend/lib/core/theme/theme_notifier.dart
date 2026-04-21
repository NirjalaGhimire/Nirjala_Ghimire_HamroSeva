import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode: light, dark, or system.
enum AppThemeMode { light, dark, system }

/// Contrast-safe semantic colors for the app.
class AppThemeColors {
  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.onPrimary,
  });
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color onPrimary;
}

/// Persisted theme preference and notifier for global app theme.
/// Light: off-white bg (#F7F5F0), white cards; Dark: #121212 bg, #1E1E1E cards.
class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier({
    AppThemeMode initialMode = AppThemeMode.light,
    Color? initialPrimaryColor,
  })  : _mode = initialMode,
        _primaryColor = initialPrimaryColor ?? const Color(0xFF3A3F67);

  static const String _keyMode = 'app_theme_mode';
  static const String _keyPrimaryColor = 'app_theme_primary_color';

  // Light theme: soft off-white, not pure white (WCAG-friendly).
  static const Color _lightBackground = Color(0xFFF7F5F0);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightTextPrimary = Color(0xFF1A1A1A);
  static const Color _lightTextSecondary = Color(0xFF5C5C5C);
  static const Color _lightBorder = Color(0xFFE0DDD8);

  // Dark theme: modern dark grey, not pure black.
  static const Color _darkBackground = Color(0xFF121212);
  static const Color _darkSurface = Color(0xFF1E1E1E);
  static const Color _darkTextPrimary = Color(0xFFF5F5F5);
  static const Color _darkTextSecondary = Color(0xFFB0B0B0);
  static const Color _darkBorder = Color(0xFF2C2C2C);

  AppThemeMode _mode;
  Color _primaryColor;

  AppThemeMode get mode => _mode;
  Color get primaryColor => _primaryColor;

  bool get isDark => _mode == AppThemeMode.dark;
  bool get isLight => _mode == AppThemeMode.light;
  bool get isSystem => _mode == AppThemeMode.system;

  /// Generate a lighter shade of [color] (for chips, highlights).
  static Color primaryLightShade(Color color) {
    final hsv = HSVColor.fromColor(color);
    return hsv.withSaturation(hsv.saturation * 0.5).withValue(0.95).toColor();
  }

  /// Generate a darker shade of [color] (for pressed states).
  static Color primaryDarkShade(Color color) {
    final hsv = HSVColor.fromColor(color);
    return hsv.withValue((hsv.value * 0.85).clamp(0.0, 1.0)).toColor();
  }

  static Future<AppThemeMode> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_keyMode);
    if (v == null) return AppThemeMode.light;
    if (v == 1) return AppThemeMode.dark;
    if (v == 2) return AppThemeMode.system;
    return AppThemeMode.light;
  }

  static Future<Color?> _loadPrimaryColor() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_keyPrimaryColor);
    if (v == null) return null;
    return Color(v);
  }

  static Future<ThemeNotifier> load() async {
    final mode = await _loadMode();
    final color = await _loadPrimaryColor();
    return ThemeNotifier(initialMode: mode, initialPrimaryColor: color);
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMode, mode == AppThemeMode.light ? 0 : mode == AppThemeMode.dark ? 1 : 2);
    notifyListeners();
  }

  Future<void> setPrimaryColor(Color color) async {
    if (_primaryColor.value == color.value) return;
    _primaryColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPrimaryColor, color.value);
    notifyListeners();
  }

  /// Semantic colors for current effective brightness (for use in widgets that need explicit values).
  AppThemeColors themeColors(bool isDark) {
    return AppThemeColors(
      background: isDark ? _darkBackground : _lightBackground,
      surface: isDark ? _darkSurface : _lightSurface,
      textPrimary: isDark ? _darkTextPrimary : _lightTextPrimary,
      textSecondary: isDark ? _darkTextSecondary : _lightTextSecondary,
      border: isDark ? _darkBorder : _lightBorder,
      primary: _primaryColor,
      primaryLight: primaryLightShade(_primaryColor),
      primaryDark: primaryDarkShade(_primaryColor),
      onPrimary: Colors.white,
    );
  }

  ThemeData themeData(Brightness platformBrightness) {
    final brightness = _mode == AppThemeMode.system
        ? platformBrightness
        : (_mode == AppThemeMode.dark ? Brightness.dark : Brightness.light);
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? _darkBackground : _lightBackground;
    final surface = isDark ? _darkSurface : _lightSurface;
    final onSurface = isDark ? _darkTextPrimary : _lightTextPrimary;
    final onSurfaceVariant = isDark ? _darkTextSecondary : _lightTextSecondary;
    final outline = isDark ? _darkBorder : _lightBorder;
    final primaryLight = primaryLightShade(_primaryColor);
    final primaryDark = primaryDarkShade(_primaryColor);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: _primaryColor,
      onPrimary: Colors.white,
      primaryContainer: primaryLight,
      onPrimaryContainer: isDark ? _darkTextPrimary : _lightTextPrimary,
      secondary: primaryLight,
      onSecondary: isDark ? _darkTextPrimary : _lightTextPrimary,
      tertiary: _primaryColor,
      onTertiary: Colors.white,
      error: const Color(0xFFB00020),
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      shadow: isDark ? Colors.black54 : Colors.black26,
      inverseSurface: isDark ? _lightSurface : _darkSurface,
      onInverseSurface: isDark ? _lightTextPrimary : _darkTextPrimary,
      surfaceTint: _primaryColor,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: _primaryColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryColor,
          side: BorderSide(color: _primaryColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _primaryColor),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: outline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryColor, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: onSurfaceVariant),
        hintStyle: TextStyle(color: onSurfaceVariant),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: outline)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: _primaryColor,
        unselectedItemColor: onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
      ),
      dividerColor: outline,
      listTileTheme: ListTileThemeData(
        textColor: onSurface,
        iconColor: _primaryColor,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primaryLight.withOpacity(0.4),
        selectedColor: primaryLight,
        labelStyle: TextStyle(color: isDark ? _darkTextPrimary : _lightTextPrimary),
        side: BorderSide(color: outline),
      ),
    );
  }
}
