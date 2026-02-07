import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';

/// Notifications tab: empty state or list (Order Accepted, Confirm Order, Order Assigned, etc.).
class NotificationsTabScreen extends StatefulWidget {
  const NotificationsTabScreen({super.key});

  @override
  State<NotificationsTabScreen> createState() => _NotificationsTabScreenState();
}

class _NotificationsTabScreenState extends State<NotificationsTabScreen> {
  // Real data: load from API when notifications endpoint is available; empty until then.
  final List<Map<String, dynamic>> _notifications = [];

  @override
  Widget build(BuildContext context) {
    if (_notifications.isEmpty) {
      return _buildEmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final n = _notifications[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: AppTheme.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            leading: CircleAvatar(
              backgroundColor: (n['color'] as Color?) ?? Colors.grey,
              child: Icon(
                n['icon'] as IconData? ?? Icons.notifications,
                color: AppTheme.white,
                size: 22,
              ),
            ),
            title: Text(
              n['title'] ?? 'Notification',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGrey,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                n['body'] ?? '',
                style: TextStyle(
                  color: AppTheme.darkGrey.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            ),
            trailing: Text(
              n['time'] ?? '2 hrs ago',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification details — coming soon')),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No Notifications Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have no notifications right now. Come back later.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
