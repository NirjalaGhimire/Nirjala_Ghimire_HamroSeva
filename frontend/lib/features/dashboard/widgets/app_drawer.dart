import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/profile_screen.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/contact_us_screen.dart';
import 'package:hamro_sewa_frontend/features/reviews/screens/ratings_reviews_screen.dart';

/// Prototype drawer: HamroSeva title, My Profile, Contact us, Become a worker,
/// Register a company, Share, Rate, Logout.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.onClose,
    required this.onLogout,
  });

  final VoidCallback onClose;
  final VoidCallback onLogout;

  static const Color _darkGrey = Color(0xFF2D3250);
  static const Color _lightBg = Color(0xFFE0E0EB);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _lightBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _drawerItem(context, Icons.person, 'My Profile', () {
                    onClose();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  }),
                  _drawerItem(context, Icons.contact_phone, 'Contact us', () {
                    onClose();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                    );
                  }),
                  _drawerItem(context, Icons.engineering, 'Become a worker', () => _navigateOrSnack(context, 'Become a worker')),
                  _drawerItem(context, Icons.business, 'Register a company', () => _navigateOrSnack(context, 'Register a company')),
                  _drawerItem(context, Icons.share, 'Share', () => _navigateOrSnack(context, 'Share')),
                  _drawerItem(context, Icons.star_border, 'Rate', () {
                    onClose();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RatingsReviewsScreen()),
                    );
                  }),
                  const Divider(height: 24),
                  _drawerItem(context, Icons.logout, 'Logout', () {
                    onClose();
                    onLogout(); // host shows logout confirmation dialog
                  }, isLogout: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'HamroSeva',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: _darkGrey,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            color: _darkGrey,
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isLogout = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: _darkGrey, size: 24),
      title: Text(
        label,
        style: TextStyle(
          color: _darkGrey,
          fontWeight: isLogout ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: _darkGrey),
      onTap: onTap,
    );
  }

  void _navigateOrSnack(BuildContext context, String label) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — coming soon')),
    );
  }
}
