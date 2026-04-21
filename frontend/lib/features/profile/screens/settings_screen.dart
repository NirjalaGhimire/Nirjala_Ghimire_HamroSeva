import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/change_password_screen.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/contact_us_screen.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/language_settings_screen.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/my_profile_screen.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/privacy_policy_screen.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/theme_settings_screen.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

/// Settings: General, Theme, App Language, Notifications (future), Security.
/// Theme and Language open dedicated pages; all use theme colors for contrast.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadLocalSettings();
  }

  Future<void> _loadLocalSettings() async {
    final notifications = await TokenStorage.getNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = notifications;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          AppStrings.t(context, 'settings'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            AppStrings.t(context, 'general'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          _settingsTile(
            context,
            title: AppStrings.t(context, 'myProfile'),
            subtitle: AppStrings.t(context, 'viewProfile'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyProfileScreen()),
            ),
          ),
          _settingsTile(
            context,
            title: AppStrings.t(context, 'contactUs'),
            subtitle: AppStrings.t(context, 'contactUsSubtitle'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ContactUsScreen()),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.t(context, 'theme'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          _settingsTile(
            context,
            title: AppStrings.t(context, 'appTheme'),
            subtitle: AppStrings.t(context, 'lightDarkOrSystemPrimaryColor'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.t(context, 'language'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          _settingsTile(
            context,
            title: AppStrings.t(context, 'language'),
            subtitle: AppStrings.t(context, 'selectYourLanguage'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.t(context, 'notifications'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          _settingsTile(
            context,
            title: AppStrings.t(context, 'notifications'),
            subtitle: AppStrings.t(context, 'pushAndInAppNotifications'),
            value: _notificationsEnabled
                ? AppStrings.t(context, 'on')
                : AppStrings.t(context, 'off'),
            onTap: () => _toggleNotifications(context),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.t(context, 'security'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          _settingsTile(
            context,
            title: AppStrings.t(context, 'changePassword'),
            subtitle: AppStrings.t(context, 'updatePassword'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          _settingsTile(
            context,
            title: AppStrings.t(context, 'privacyPolicy'),
            subtitle: AppStrings.t(context, 'privacyPolicySubtitle'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? value,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline),
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: value != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colorScheme.onSurface),
                ],
              )
            : Icon(Icons.chevron_right, color: colorScheme.onSurface),
        onTap: onTap,
      ),
    );
  }

  Future<void> _toggleNotifications(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final next = !_notificationsEnabled;
    setState(() => _notificationsEnabled = next);
    await TokenStorage.setNotificationsEnabled(next);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          next
              ? AppStrings.t(context, 'notificationsTurnedOn')
              : AppStrings.t(context, 'notificationsTurnedOff'),
        ),
      ),
    );
  }
}
