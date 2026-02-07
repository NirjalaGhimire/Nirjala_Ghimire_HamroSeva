import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/dashboard/widgets/app_drawer.dart';
import 'package:hamro_sewa_frontend/features/shell/screens/home_tab_screen.dart';
import 'package:hamro_sewa_frontend/features/shell/screens/orders_tab_screen.dart';
import 'package:hamro_sewa_frontend/features/shell/screens/promotions_tab_screen.dart';
import 'package:hamro_sewa_frontend/features/shell/screens/notifications_tab_screen.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

/// Main app shell: bottom nav (Home, Orders, Promotions, Notifications) + drawer.
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  static const List<_NavItem> _tabs = [
    _NavItem(label: 'Home', icon: Icons.home),
    _NavItem(label: 'Orders', icon: Icons.list_alt),
    _NavItem(label: 'Promotions', icon: Icons.card_giftcard),
    _NavItem(label: 'Notifications', icon: Icons.notifications),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _tabs.length - 1);
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const HomeTabScreen();
      case 1:
        return const OrdersTabScreen();
      case 2:
        return const PromotionsTabScreen();
      case 3:
        return const NotificationsTabScreen();
      default:
        return const HomeTabScreen();
    }
  }

  Future<void> _logout() async {
    await TokenStorage.clearTokens();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPrototypeScreen()),
      (route) => false,
    );
  }

  void _onLogoutFromDrawer() {
    Navigator.pop(context); // close drawer
    _showLogoutDialog();
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: AppTheme.darkGrey,
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
                  _logout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.darkGrey,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightLavender,
      appBar: AppBar(
        title: Text(
          _tabs[_currentIndex].label,
          style: const TextStyle(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
        iconTheme: const IconThemeData(color: AppTheme.white),
      ),
      drawer: AppDrawer(
        onClose: () => Navigator.pop(context),
        onLogout: _onLogoutFromDrawer,
      ),
      body: _buildPage(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.darkGrey,
        unselectedItemColor: Colors.grey,
        backgroundColor: AppTheme.white,
        items: _tabs
            .map((t) => BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}
