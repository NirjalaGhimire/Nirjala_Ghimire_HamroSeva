import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/notifications/utils/notification_localizer.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

/// Polls notifications and shows a popup when a new one arrives. Tap opens the related booking.
class NotificationPopupOverlay extends StatefulWidget {
  const NotificationPopupOverlay({
    super.key,
    required this.child,
    required this.isProvider,
    required this.onOpenBooking,
  });

  final Widget child;
  final bool isProvider;
  final void Function(String bookingId) onOpenBooking;

  @override
  State<NotificationPopupOverlay> createState() =>
      _NotificationPopupOverlayState();
}

class _NotificationPopupOverlayState extends State<NotificationPopupOverlay> {
  Timer? _timer;
  int _lastSeenNotificationId = 0;
  Map<String, dynamic>? _popupNotification;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _loadLastSeenId().then((_) => _startPolling());
  }

  Future<void> _loadLastSeenId() async {
    final lastSeen = await TokenStorage.getLastSeenNotificationId();
    if (lastSeen != null) {
      _lastSeenNotificationId = lastSeen;
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer =
        Timer.periodic(const Duration(seconds: 30), (_) => _fetchAndShowNew());
    // First fetch: just seed _seenIds so we don't pop up for old notifications
    Future.delayed(const Duration(seconds: 2), _fetchAndShowNew);
  }

  Future<void> _fetchAndShowNew() async {
    if (!_mounted) return;
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;
    try {
      final list = widget.isProvider
          ? await ApiService.getProviderNotifications()
          : await ApiService.getCustomerNotifications();
      if (!_mounted) return;
      final items = list;

      // Track the highest notification ID we've seen so far; store it so we don't re-show the same notification.
      var maxId = _lastSeenNotificationId;
      Map<String, dynamic>? newNotif;

      for (final n in items) {
        final map = Map<String, dynamic>.from(n as Map);
        final id = map['id'];
        final idInt = id is int ? id : int.tryParse(id.toString());
        if (idInt == null) continue;
        if (idInt > maxId) {
          maxId = idInt;
          final bookingId = map['booking_id']?.toString();
          if (bookingId != null && bookingId != 'null' && newNotif == null) {
            newNotif = map;
          }
        }
      }

      if (maxId > _lastSeenNotificationId) {
        _lastSeenNotificationId = maxId;
        TokenStorage.setLastSeenNotificationId(maxId);
      }

      if (newNotif != null && _mounted) {
        setState(() {
          _popupNotification = newNotif;
        });
      }
    } catch (e) {
      // Ignore network errors; they will retry on the next timer tick.
      // Print so it is easier to diagnose if notifications never show.
      // ignore: avoid_print
      print('Notification polling error: $e');
    }
  }

  void _dismissAndOpen(String? bookingId) {
    setState(() => _popupNotification = null);
    if (bookingId != null && bookingId.isNotEmpty && bookingId != 'null') {
      widget.onOpenBooking(bookingId);
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_popupNotification != null) _buildPopup(),
      ],
    );
  }

  Widget _buildPopup() {
    final n = _popupNotification!;
    final title =
        NotificationLocalizer.localizeTitle(context, n['title'] as String?);
    final body =
        NotificationLocalizer.localizeBody(context, n['body'] as String?);
    final bookingId = n['booking_id']?.toString();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: () => _dismissAndOpen(bookingId),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.customerPrimary.withOpacity(0.3), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.customerPrimary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_active,
                      color: AppTheme.customerPrimary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.t(context, 'tapToView'),
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.customerPrimary,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: Colors.grey[600]),
                  onPressed: () => setState(() => _popupNotification = null),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
