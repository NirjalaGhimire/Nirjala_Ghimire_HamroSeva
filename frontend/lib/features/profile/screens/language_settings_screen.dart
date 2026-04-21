import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/locale/locale_notifier.dart';

/// Dedicated App Language settings page: English / नेपाली. Uses theme colors.
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          AppStrings.t(context, 'language'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: Consumer<LocaleNotifier>(
        builder: (context, localeNotifier, _) {
          final isNe = localeNotifier.languageCode == 'ne';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                AppStrings.t(context, 'selectYourLanguage'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _languageTile(
                context,
                title: AppStrings.t(context, 'english'),
                subtitle: AppStrings.t(context, 'useEnglishForApp'),
                selected: !isNe,
                onTap: () => localeNotifier.setLocale(const Locale('en')),
                colorScheme: colorScheme,
              ),
              _languageTile(
                context,
                title: AppStrings.t(context, 'nepali'),
                subtitle: 'ऐपको लागि नेपाली प्रयोग गर्नुहोस्',
                selected: isNe,
                onTap: () => localeNotifier.setLocale(const Locale('ne')),
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 24),
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
                        context, 'languagePreferenceSavedAppliedAcrossApp'),
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

  Widget _languageTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
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
        leading: Icon(
          Icons.language,
          color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        trailing: selected
            ? Icon(Icons.check_circle, color: colorScheme.primary)
            : null,
        onTap: onTap,
      ),
    );
  }
}
