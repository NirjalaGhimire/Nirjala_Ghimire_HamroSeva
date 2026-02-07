import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/help_desk_screen.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/about_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/all_shops_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/blogs_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/placeholder_data_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/promotional_banners_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_notifications_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_personal_info_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_reviews_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_services_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/verify_id_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/widgets/provider_app_bar.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/settings_screen.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

/// Provider Profile: user card, GENERAL (Shop, Services, Verify Id, etc.), OTHER (Push Notification), SETTING, DANGER ZONE.
class ProviderProfileTabScreen extends StatefulWidget {
  const ProviderProfileTabScreen({super.key});

  @override
  State<ProviderProfileTabScreen> createState() =>
      _ProviderProfileTabScreenState();
}

class _ProviderProfileTabScreenState extends State<ProviderProfileTabScreen> {
  bool _pushNotification = true;
  bool _optionalUpdateNotify = true;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: TokenStorage.getSavedUser(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = user?['username'] ?? user?['email'] ?? 'Provider';
        final email = user?['email'] ?? 'demo@provider.com';
        return Scaffold(
          backgroundColor: AppTheme.white,
          appBar: AppBar(
            title: const Text(
              'Profile',
              style:
                  TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppTheme.customerPrimary,
            foregroundColor: AppTheme.white,
            elevation: 0,
            shape: providerAppBarShape,
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ProviderNotificationsScreen()),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _userCard(name, email),
              const SizedBox(height: 12),
              _providerTypeCard(user?['profession']?.toString()),
              const SizedBox(height: 20),
              _sectionHeader('GENERAL'),
              _tile(context, Icons.person_outline, 'Personal Information',
                  onTap: () => _push(context, const ProviderPersonalInfoScreen())),
              _tile(context, Icons.account_balance_wallet, 'Wallet Balance',
                  trailing: 'Rs 0.00', isGreen: true),
              _tile(context, Icons.store, 'Shop',
                  onTap: () => _push(context, const AllShopsScreen())),
              _tile(context, Icons.description, 'Shop Document',
                  onTap: () => _push(context, const PlaceholderDataScreen(title: 'Shop Document', icon: Icons.description, message: 'Shop documents will appear here when added.'))),
              _tile(context, Icons.assignment, 'Services',
                  onTap: () => _push(context, const ProviderServicesScreen())),
              _tile(context, Icons.badge, 'Verify Your Id',
                  onTap: () => _push(context, const VerifyIdScreen())),
              _tile(context, Icons.article, 'Blogs',
                  onTap: () => _push(context, const BlogsScreen())),
              _tile(context, Icons.headset_mic_outlined, 'Help Desk',
                  onTap: () => _push(context, const HelpDeskScreen())),
              _tile(context, Icons.star_outline, 'Ratings & Reviews',
                  onTap: () => _push(context, const ProviderReviewsScreen())),
              _tile(context, Icons.attach_money, 'Handyman Earning List',
                  onTap: () => _push(context, const PlaceholderDataScreen(title: 'Handyman Earning List', icon: Icons.attach_money, message: 'Your earnings from completed bookings will appear here.'))),
              _tile(context, Icons.inventory_2_outlined, 'Packages',
                  onTap: () => _push(context, const PlaceholderDataScreen(title: 'Packages', icon: Icons.inventory_2_outlined, message: 'Service packages will appear here when added.'))),
              _tile(context, Icons.build_circle_outlined, 'Addon Services',
                  onTap: () => _push(context, const PlaceholderDataScreen(title: 'Addon Services', icon: Icons.build_circle_outlined, message: 'Add-on services will appear here when available.'))),
              _tile(context, Icons.schedule, 'Time Slots',
                  onTap: () => _push(context, const PlaceholderDataScreen(title: 'Time Slots', icon: Icons.schedule, message: 'Your available time slots will appear here when set.'))),
              _tile(context, Icons.account_balance, 'Bank Details',
                  onTap: () => _push(context, const PlaceholderDataScreen(title: 'Bank Details', icon: Icons.account_balance, message: 'Bank account details for payouts will appear here when added.'))),
              _tile(context, Icons.campaign_outlined, 'Promotional Banners',
                  onTap: () => _push(context, const PromotionalBannersScreen())),
              const SizedBox(height: 20),
              _sectionHeader('OTHER'),
              _switchTile('Push Notification', _pushNotification,
                  (v) => setState(() => _pushNotification = v)),
              _switchTile('Optional Update Notify', _optionalUpdateNotify,
                  (v) => setState(() => _optionalUpdateNotify = v),
                  icon: Icons.cloud_download_outlined),
              const SizedBox(height: 20),
              _sectionHeader('SETTING'),
              _tile(context, Icons.light_mode_outlined, 'App Theme',
                  onTap: () => _push(context, const SettingsScreen())),
              _tile(context, Icons.language, 'App Language'),
              _tile(context, Icons.lock_outline, 'Change Password'),
              _tile(context, Icons.info_outline, 'About',
                  onTap: () => _push(context, const AboutScreen())),
              const SizedBox(height: 20),
              _sectionHeader('DANGER ZONE', color: Colors.red),
              _tile(context, Icons.delete_outline, 'Delete Account',
                  isDanger: true),
              _tile(context, Icons.logout, 'Logout',
                  isDanger: true, onTap: () => _showLogoutDialog(context)),
              const SizedBox(height: 16),
              const Center(
                  child: Text('v1.0.0',
                      style: TextStyle(fontSize: 12, color: Colors.grey))),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _userCard(String name, String email) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppTheme.customerPrimary.withOpacity(0.2),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'P',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.customerPrimary),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(email,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _providerTypeCard(String? providerType) {
    final displayType = (providerType ?? '').trim().isEmpty ? '—' : providerType!;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: AppTheme.customerPrimary.withOpacity(0.15),
          child: const Icon(Icons.settings, color: AppTheme.customerPrimary),
        ),
        title: Text('Provider Type: $displayType'),
      ),
    );
  }

  Widget _sectionHeader(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color ?? AppTheme.customerPrimary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title, {
    String? trailing,
    bool isGreen = false,
    bool isDanger = false,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon,
            color: isDanger ? Colors.red : AppTheme.darkGrey, size: 22),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDanger ? Colors.red : AppTheme.darkGrey,
          ),
        ),
        trailing: trailing != null
            ? Text(trailing,
                style: TextStyle(
                    color: isGreen ? Colors.green : Colors.grey[600],
                    fontWeight: FontWeight.w600))
            : const Icon(Icons.chevron_right,
                color: AppTheme.darkGrey, size: 20),
        onTap: onTap ?? (isDanger && title == 'Logout' ? null : () {}),
      ),
    );
  }

  Widget _switchTile(String title, bool value, ValueChanged<bool> onChanged,
      {IconData icon = Icons.notifications_outlined}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SwitchListTile(
        secondary: Icon(icon, color: AppTheme.darkGrey, size: 22),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppTheme.customerPrimary,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: AppTheme.customerPrimary,
              child: Icon(Icons.logout, color: AppTheme.white, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Come back soon!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Are you sure you want to logout?',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await TokenStorage.clearTokens();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const LoginPrototypeScreen()),
                      (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.customerPrimary,
                  foregroundColor: AppTheme.white,
                ),
                child: const Text('Yes, Logout'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.linkRed)),
            ),
          ],
        ),
      ),
    );
  }
}
