import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/delete_account_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/favourite_provider_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/favourite_services_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/help_desk_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/helpline_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/my_reviews_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_personal_profile_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/rate_us_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/referral_loyalty_screen.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/about_screen.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/settings_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/wallet_history_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/esewa_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

/// Customer Profile tab: avatar, name, email, Wallet Balance, GENERAL, ABOUT APP, DANGER ZONE, Logout.
class CustomerProfileTabScreen extends StatefulWidget {
  const CustomerProfileTabScreen({super.key});

  @override
  State<CustomerProfileTabScreen> createState() => _CustomerProfileTabScreenState();
}

class _CustomerProfileTabScreenState extends State<CustomerProfileTabScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final profile = await ApiService.getCurrentCustomerProfile();
      final saved = await TokenStorage.getSavedUser() ?? <String, dynamic>{};
      final merged = <String, dynamic>{
        ...saved,
        ...profile,
        'username': (profile['full_name'] ?? saved['username'] ?? '').toString(),
        'profile_image_url':
            (profile['profile_image_url'] ?? saved['profile_image_url'] ?? '').toString(),
      };
      await TokenStorage.saveUser(merged);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (_) {
      final saved = await TokenStorage.getSavedUser();
      if (!mounted) return;
      setState(() {
        _profile = saved;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_profile?['full_name'] ?? _profile?['username'] ?? _profile?['email'] ?? 'User')
        .toString();
    final email = (_profile?['email'] ?? '—').toString();
    final imageUrl = (_profile?['profile_image_url'] ?? '').toString().trim();
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          AppStrings.t(context, 'profileTab'),
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
      body: _loading
          ? const Center(
              child: AppShimmerLoader(color: AppTheme.customerPrimary),
            )
          : RefreshIndicator(
              onRefresh: _loadProfile,
              color: AppTheme.customerPrimary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _userCard(name, email, imageUrl),
                  const SizedBox(height: 12),
                  const WalletBalanceCard(),
                  const SizedBox(height: 20),
                  _sectionHeader(AppStrings.t(context, 'generalSection')),
                  _profileTile(
                    context,
                    icon: Icons.person_outline,
                    title: 'Personal Information',
                    onTap: () async {
                      await _push(context, const CustomerPersonalProfileScreen());
                      await _loadProfile();
                    },
                  ),
                  _profileTile(context,
                      icon: Icons.history,
                      title: AppStrings.t(context, 'walletHistory'),
                      onTap: () => _push(context, const WalletHistoryScreen())),
                  _profileTile(context,
                      icon: Icons.favorite_border,
                      title: AppStrings.t(context, 'favouriteServices'),
                      onTap: () => _push(context, const FavouriteServicesScreen())),
                  _profileTile(context,
                      icon: Icons.person_outline,
                      title: AppStrings.t(context, 'favouriteProvider'),
                      onTap: () => _push(context, const FavouriteProviderScreen())),
                  _profileTile(context,
                      icon: Icons.card_giftcard,
                      title: AppStrings.t(context, 'referralLoyalty'),
                      onTap: () => _push(context, const ReferralLoyaltyScreen())),
                  _profileTile(context,
                      icon: Icons.star_border,
                      title: AppStrings.t(context, 'rateUs'),
                      onTap: () => _push(context, const RateUsScreen())),
                  _profileTile(context,
                      icon: Icons.rate_review_outlined,
                      title: AppStrings.t(context, 'myReviews'),
                      onTap: () => _push(context, const MyReviewsScreen())),
                  _profileTile(context,
                      icon: Icons.headset_mic_outlined,
                      title: AppStrings.t(context, 'helpDesk'),
                      onTap: () => _push(context, const HelpDeskScreen())),
                  const SizedBox(height: 20),
                  _sectionHeader(AppStrings.t(context, 'aboutAppSection')),
                  _profileTile(context,
                      icon: Icons.phone_in_talk,
                      title: AppStrings.t(context, 'helplineNumber'),
                      onTap: () => _push(context, const HelplineScreen())),
                  _profileTile(context,
                      icon: Icons.info_outline,
                      title: AppStrings.t(context, 'about'),
                      onTap: () => _push(context, const AboutScreen())),
                  const SizedBox(height: 20),
                  _sectionHeader(AppStrings.t(context, 'dangerZoneSection'),
                      color: Colors.red),
                  _profileTile(
                    context,
                    icon: Icons.person_remove_outlined,
                    title: AppStrings.t(context, 'deleteAccount'),
                    onTap: () => _push(context, const DeleteAccountScreen()),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () => _showLogoutDialog(context),
                      child: Text(
                        AppStrings.t(context, 'logout'),
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
            ),
    );
  }

  Widget _userCard(String name, String email, String imageUrl) {
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
              backgroundColor: AppTheme.customerPrimary.withValues(alpha: 0.2),
              backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
              child: imageUrl.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.customerPrimary,
                      ),
                    )
                  : null,
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

  Widget _sectionHeader(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: (color ?? Colors.grey[300])!.withValues(alpha: 0.3),
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

  Future<void> _push(BuildContext context, Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
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
        trailing:
            const Icon(Icons.chevron_right, color: AppTheme.darkGrey, size: 20),
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
            Text(
              AppStrings.t(context, 'comeBackSoon'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.t(context, 'confirmLogoutQuestion'),
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
                    MaterialPageRoute(
                        builder: (_) => const LoginPrototypeScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.customerPrimary,
                  foregroundColor: AppTheme.white,
                ),
                child: Text(AppStrings.t(context, 'yesLogout')),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.t(context, 'cancel'),
                  style: TextStyle(color: AppTheme.linkRed)),
            ),
          ],
        ),
      ),
    );
  }
}

class WalletBalanceCard extends StatefulWidget {
  const WalletBalanceCard({super.key});

  @override
  State<WalletBalanceCard> createState() => _WalletBalanceCardState();
}

class _WalletBalanceCardState extends State<WalletBalanceCard> {
  late Future<Map<String, dynamic>> _walletFuture;

  @override
  void initState() {
    super.initState();
    _walletFuture = ApiService.getWallet();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _walletFuture,
      builder: (context, snapshot) {
        final balance = (snapshot.data?['balance'] as num?)?.toDouble() ?? 0.0;
        return Material(
          color: AppTheme.customerPrimary,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet,
                    color: AppTheme.white.withOpacity(0.9), size: 28),
                const SizedBox(width: 12),
                Text(
                  AppStrings.t(context, 'walletBalance'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.white,
                  ),
                ),
                const Spacer(),
                snapshot.connectionState != ConnectionState.done
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: AppShimmerLoader(
                            color: AppTheme.white, strokeWidth: 2))
                    : Text(
                        ESewaService.formatAmount(balance),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.white,
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}
