import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/settings_screen.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/edit_gender_screen.dart';

/// Profile screen: avatar, name, role; then Personal Information, Payment Preferences,
/// Banks and Cards, Notifications (badge), Message Center, Address, Settings.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: TokenStorage.getSavedUser(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = user?['username'] ?? user?['email'] ?? 'User';
        final role = (user?['role'] ?? 'customer').toString().toUpperCase();
        if (role == 'PROVIDER') {
          // Show profession if available
        }
        return Scaffold(
          backgroundColor: AppTheme.white,
          appBar: AppBar(
            title: const Text(
              'Profile',
              style: TextStyle(
                color: AppTheme.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: AppTheme.darkGrey,
            foregroundColor: AppTheme.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.person_outline),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit profile — coming soon')),
                  );
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppTheme.lightLavender,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role == 'PROVIDER'
                          ? (user?['profession'] ?? 'Service Provider')
                          : 'Customer',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _profileTile(
                context,
                icon: Icons.person_outline,
                title: 'Personal Information',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditGenderScreen()),
                ),
              ),
              _profileTile(
                context,
                icon: Icons.account_balance_wallet_outlined,
                title: 'Payment Preferences',
                onTap: () => _snack(context, 'Payment Preferences'),
              ),
              _profileTile(
                context,
                icon: Icons.credit_card,
                title: 'Banks and Cards',
                onTap: () => _snack(context, 'Banks and Cards'),
              ),
              _profileTile(
                context,
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '2',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: () => _snack(context, 'Notifications'),
              ),
              _profileTile(
                context,
                icon: Icons.message_outlined,
                title: 'Message Center',
                onTap: () => _snack(context, 'Message Center'),
              ),
              _profileTile(
                context,
                icon: Icons.location_on_outlined,
                title: 'Address',
                onTap: () => _snack(context, 'Address'),
              ),
              _profileTile(
                context,
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _profileTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.lightLavender.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.darkGrey),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppTheme.darkGrey,
          ),
        ),
        trailing: trailing ?? const Icon(Icons.chevron_right, color: AppTheme.darkGrey),
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
