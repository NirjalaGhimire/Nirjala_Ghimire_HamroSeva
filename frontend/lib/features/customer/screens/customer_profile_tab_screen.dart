import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/delete_account_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/favourite_provider_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/favourite_services_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/help_desk_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/helpline_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/my_reviews_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/rate_us_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/referral_loyalty_screen.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/about_screen.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/settings_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/wallet_history_screen.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

/// Customer Profile tab: avatar, name, email, Wallet Balance, GENERAL, ABOUT APP, DANGER ZONE, Logout.
class CustomerProfileTabScreen extends StatelessWidget {
  const CustomerProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: TokenStorage.getSavedUser(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = user?['username'] ?? user?['email'] ?? 'User';
        final email = user?['email'] ?? 'demo@user.com';
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
            backgroundColor: AppTheme.customerPrimary,
            foregroundColor: AppTheme.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _userCard(name, email),
              const SizedBox(height: 12),
              _walletCard(),
              const SizedBox(height: 20),
              _sectionHeader('GENERAL'),
              _profileTile(context, icon: Icons.history, title: 'Wallet History', onTap: () => _push(context, const WalletHistoryScreen())),
              _profileTile(context, icon: Icons.favorite_border, title: 'Favourite Services', onTap: () => _push(context, const FavouriteServicesScreen())),
              _profileTile(context, icon: Icons.person_outline, title: 'Favourite Provider', onTap: () => _push(context, const FavouriteProviderScreen())),
              _profileTile(context, icon: Icons.card_giftcard, title: 'Referral & Loyalty', onTap: () => _push(context, const ReferralLoyaltyScreen())),
              _profileTile(context, icon: Icons.star_border, title: 'Rate Us', onTap: () => _push(context, const RateUsScreen())),
              _profileTile(context, icon: Icons.rate_review_outlined, title: 'My Reviews', onTap: () => _push(context, const MyReviewsScreen())),
              _profileTile(context, icon: Icons.headset_mic_outlined, title: 'Help Desk', onTap: () => _push(context, const HelpDeskScreen())),
              const SizedBox(height: 20),
              _sectionHeader('ABOUT APP'),
              _profileTile(context, icon: Icons.phone_in_talk, title: 'Helpline Number', onTap: () => _push(context, const HelplineScreen())),
              _profileTile(context, icon: Icons.info_outline, title: 'About', onTap: () => _push(context, const AboutScreen())),
              const SizedBox(height: 20),
              _sectionHeader('DANGER ZONE', color: Colors.red),
              _profileTile(
                context,
                icon: Icons.person_remove_outlined,
                title: 'Delete Account',
                onTap: () => _push(context, const DeleteAccountScreen()),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => _showLogoutDialog(context),
                  child: const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.customerPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
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
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.customerPrimary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _walletCard() {
    return Material(
      color: AppTheme.customerPrimary,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: AppTheme.white.withOpacity(0.9), size: 28),
            const SizedBox(width: 12),
            const Text(
              'Wallet Balance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.white,
              ),
            ),
            const Spacer(),
            const Text(
              'Rs 0.00',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: (color ?? Colors.grey[300])!.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.grey[700],
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _profileTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.darkGrey, size: 22),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppTheme.darkGrey,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.darkGrey, size: 20),
        onTap: onTap,
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
            const Text(
              'Come back soon!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Are you sure you want to logout?',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.darkGrey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  TokenStorage.clearTokens();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPrototypeScreen()),
                    (route) => false,
                  );
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
              child: const Text('Cancel', style: TextStyle(color: AppTheme.linkRed)),
            ),
          ],
        ),
      ),
    );
  }
}
