import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

/// My Profile: display user info (from token storage). Opens as separate page from Settings.
class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('My Profile', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: TokenStorage.getSavedUser(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          final name = user?['username'] ?? user?['email'] ?? '—';
          final email = user?['email'] ?? '—';
          final phone = (user?['phone'] ?? '').toString().trim().isEmpty ? '—' : (user?['phone'] ?? '—');
          final role = (user?['role'] ?? 'customer').toString();
          final roleLabel = role == 'provider' ? 'Service Provider' : role == 'admin' ? 'Admin' : 'Customer';

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.darkGrey));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: AppTheme.darkGrey.withOpacity(0.2),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Account information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
                const SizedBox(height: 12),
                _infoCard(context, 'Name', name),
                _infoCard(context, 'Email', email),
                _infoCard(context, 'Phone', phone),
                _infoCard(context, 'Account type', roleLabel),
                const SizedBox(height: 24),
                Text(
                  'To update your name, email or phone, use the profile section in the main app (Home → Profile).',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoCard(BuildContext context, String label, String value) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600]))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
          ],
        ),
      ),
    );
  }
}
