import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_home_tab_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_bookings_tab_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_categories_tab_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_chat_tab_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_profile_tab_screen.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

/// Customer app shell: 5-tab bottom nav (Home, Bookings, Categories, Chat, Profile).
/// Purple-themed; no drawer. Used when logged-in user role is customer.
class CustomerShellScreen extends StatefulWidget {
  const CustomerShellScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<CustomerShellScreen> createState() => _CustomerShellScreenState();
}

class _CustomerShellScreenState extends State<CustomerShellScreen> {
  int _currentIndex = 0;

  static const List<_NavItem> _tabs = [
    _NavItem(label: 'Home', icon: Icons.home),
    _NavItem(label: 'Bookings', icon: Icons.calendar_today),
    _NavItem(label: 'Categories', icon: Icons.grid_view),
    _NavItem(label: 'Chat', icon: Icons.chat_bubble_outline),
    _NavItem(label: 'Profile', icon: Icons.person_outline),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _tabs.length - 1);
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const CustomerHomeTabScreen();
      case 1:
        return const CustomerBookingsTabScreen();
      case 2:
        return const CustomerCategoriesTabScreen();
      case 3:
        return const CustomerChatTabScreen();
      case 4:
        return const CustomerProfileTabScreen();
      default:
        return const CustomerHomeTabScreen();
    }
  }

  Future<void> _logout() async {
    await TokenStorage.clearTokens();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPrototypeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: _buildPage(_currentIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (i) {
                final t = _tabs[i];
                final selected = _currentIndex == i;
                return InkWell(
                  onTap: () => setState(() => _currentIndex = i),
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.customerPrimary.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          t.icon,
                          size: 24,
                          color: selected ? AppTheme.customerPrimary : Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            color: selected ? AppTheme.customerPrimary : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}
