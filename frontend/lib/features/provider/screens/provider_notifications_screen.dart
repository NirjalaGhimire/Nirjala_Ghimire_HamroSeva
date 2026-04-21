import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/notifications/utils/notification_localizer.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/booking_detail_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/widgets/provider_app_bar.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

/// Provider Notifications: new bookings and updates (fetched from backend so provider sees new orders).
class ProviderNotificationsScreen extends StatefulWidget {
  const ProviderNotificationsScreen({super.key});

  @override
  State<ProviderNotificationsScreen> createState() =>
      _ProviderNotificationsScreenState();
}

class _ProviderNotificationsScreenState
    extends State<ProviderNotificationsScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getProviderNotifications();
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
        });
        // Remember the latest notification so we can show "new" badges later.
        final maxId = _items
            .map((e) => (e as Map<String, dynamic>)['id'])
            .map((v) => v is int ? v : int.tryParse(v?.toString() ?? '0'))
            .whereType<int>()
            .fold<int>(0, (prev, curr) => curr > prev ? curr : prev);
        if (maxId > 0) {
          await TokenStorage.setLastSeenNotificationId(maxId);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _items = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        title: Text(AppStrings.t(context, 'notifications'),
            style: const TextStyle(
                color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        elevation: 0,
        shape: providerAppBarShape,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _load),
        ],
      ),
      body: _loading
          ? const Center(
              child: AppShimmerLoader(color: AppTheme.customerPrimary))
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(AppStrings.t(context, 'noNotificationsYet'),
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.customerPrimary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final n = _items[index] as Map<String, dynamic>;
                      final title = NotificationLocalizer.localizeTitle(
                        context,
                        n['title'] as String?,
                      );
                      final body = NotificationLocalizer.localizeBody(
                        context,
                        n['body'] as String?,
                      );
                      final time = NotificationLocalizer.timeAgo(
                        context,
                        n['created_at']?.toString(),
                      );
                      final bookingId = n['booking_id']?.toString();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor:
                                AppTheme.customerPrimary.withOpacity(0.15),
                            child: const Icon(Icons.notifications_active,
                                color: AppTheme.customerPrimary),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              body,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[700]),
                            ),
                          ),
                          trailing: Text(
                            time,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                          onTap: () {
                            if (bookingId != null &&
                                bookingId != 'null' &&
                                bookingId.isNotEmpty) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BookingDetailScreen(
                                      bookingId: bookingId, isProvider: true),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
