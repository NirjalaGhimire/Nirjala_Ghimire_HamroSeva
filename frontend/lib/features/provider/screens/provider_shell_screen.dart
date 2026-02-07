import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_home_tab_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_bookings_tab_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_chat_tab_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_profile_tab_screen.dart';

/// Provider app shell: 4-tab bottom nav (Home, Bookings, Chat, Profile).
/// Uses same primary color as customer (AppTheme.customerPrimary).
class ProviderShellScreen extends StatefulWidget {
  const ProviderShellScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<ProviderShellScreen> createState() => _ProviderShellScreenState();
}

class _ProviderShellScreenState extends State<ProviderShellScreen> {
  int _currentIndex = 0;

  static const List<_NavItem> _tabs = [
    _NavItem(label: 'Home', icon: Icons.home),
    _NavItem(label: 'Bookings', icon: Icons.calendar_today),
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
        return const ProviderHomeTabScreen();
      case 1:
        return const ProviderBookingsTabScreen();
      case 2:
        return const ProviderChatTabScreen();
      case 3:
        return const ProviderProfileTabScreen();
      default:
        return const ProviderHomeTabScreen();
    }
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
