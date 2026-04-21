import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/theme_notifier.dart';

/// Theme Settings: Light, Dark, System; primary color presets. Uses theme colors for contrast.
class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  static const List<Color> _presetColors = [
    Color(0xFF3A3F67),
    Color(0xFF2D3250),
    Color(0xFF1976D2),
    Color(0xFF388E3C),
    Color(0xFF7B1FA2),
    Color(0xFFE53935),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'appTheme'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: Consumer<ThemeNotifier>(
        builder: (context, theme, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                AppStrings.t(context, 'themeMode'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              _modeTile(context, theme, AppStrings.t(context, 'light'),
                  AppThemeMode.light, Icons.light_mode_outlined),
              _modeTile(context, theme, AppStrings.t(context, 'dark'),
                  AppThemeMode.dark, Icons.dark_mode_outlined),
              _modeTile(context, theme, AppStrings.t(context, 'system'),
                  AppThemeMode.system, Icons.brightness_auto_outlined),
              const SizedBox(height: 24),
              Text(
                AppStrings.t(context, 'primaryColorAccent'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _presetColors.map((color) {
                  final selected = theme.primaryColor.value == color.value;
                  return GestureDetector(
                    onTap: () => theme.setPrimaryColor(color),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? colorScheme.onPrimary
                              : colorScheme.outline,
                          width: selected ? 3 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outline),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    AppStrings.t(
                        context, 'themePreferenceSavedAppliedAcrossApp'),
                    style: TextStyle(
                        fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _modeTile(BuildContext context, ThemeNotifier theme, String label,
      AppThemeMode mode, IconData icon) {
    final selected = theme.mode == mode;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outline,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(icon,
            color:
                selected ? colorScheme.primary : colorScheme.onSurfaceVariant),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        trailing: selected
            ? Icon(Icons.check_circle, color: colorScheme.primary)
            : null,
        onTap: () => theme.setMode(mode),
      ),
    );
  }
}
