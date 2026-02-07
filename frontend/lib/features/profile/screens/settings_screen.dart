import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/change_password_screen.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/contact_us_screen.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/my_profile_screen.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/privacy_policy_screen.dart';

/// Settings screen: General (Language, My Profile, Contact Us),
/// Security (Change Password, Privacy Policy, Biometric toggle).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightLavender,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Print — coming soon')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'General',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          _settingsTile(
            context,
            title: 'Language',
            subtitle: null,
            value: 'English',
            onTap: () => _snack(context, 'Language'),
          ),
          _settingsTile(
            context,
            title: 'My Profile',
            subtitle: 'View your account information',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyProfileScreen()),
            ),
          ),
          _settingsTile(
            context,
            title: 'Contact Us',
            subtitle: 'Phone, email and support',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ContactUsScreen()),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Security',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          _settingsTile(
            context,
            title: 'Change Password',
            subtitle: 'Update your password',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          _settingsTile(
            context,
            title: 'Privacy Policy',
            subtitle: 'How we use your data',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            color: AppTheme.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: const Text(
                'Biometric',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.darkGrey,
                ),
              ),
              value: _biometricEnabled,
              onChanged: (v) => setState(() => _biometricEnabled = v),
              activeThumbColor: AppTheme.darkGrey,
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
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppTheme.darkGrey,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
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
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.darkGrey),
                ],
              )
            : const Icon(Icons.chevron_right, color: AppTheme.darkGrey),
        onTap: onTap,
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$msg — coming soon')),
    );
  }
}
