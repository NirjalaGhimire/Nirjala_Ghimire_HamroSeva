import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_bookings_tab_screen.dart';
import 'package:hamro_sewa_frontend/features/notifications/utils/notification_localizer.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/booking_detail_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

/// Notifications for customer (e.g. booking declined by provider).
class CustomerNotificationsScreen extends StatefulWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  State<CustomerNotificationsScreen> createState() =>
      _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState
    extends State<CustomerNotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getCustomerNotifications();
      final items =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (e is SessionExpiredException ||
          e.toString().contains('token not valid') ||
          e.toString().contains('SESSION_EXPIRED')) {
        await TokenStorage.clearTokens();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPrototypeScreen()),
            (_) => false,
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _error = e.toString();
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
        title: Text(
          AppStrings.t(context, 'notifications'),
          style: const TextStyle(
              color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: AppShimmerLoader(color: AppTheme.customerPrimary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red[700])),
                        const SizedBox(height: 16),
                        TextButton(
                            onPressed: _load,
                            child: Text(AppStrings.t(context, 'retry'))),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none_outlined,
                                size: 72, color: Colors.grey[400]),
                            const SizedBox(height: 20),
                            Text(
                              AppStrings.t(context, 'noNotificationsYet'),
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700]),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppStrings.t(
                                  context, 'notificationsEmptySubtitle'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 24),
                            TextButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh, size: 20),
                              label: Text(AppStrings.t(context, 'refresh')),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final n = _items[index];
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
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
                              final bookingId = n['booking_id']?.toString();
                              if (bookingId != null &&
                                  bookingId != 'null' &&
                                  bookingId.isNotEmpty) {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => BookingDetailScreen(
                                        bookingId: bookingId,
                                        isProvider: false),
                                  ),
                                );
                              } else {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const CustomerBookingsTabScreen()),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
