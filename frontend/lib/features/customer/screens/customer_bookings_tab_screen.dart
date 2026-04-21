import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/payment/screens/esewa_payment_screen.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/features/reviews/screens/write_review_for_booking_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/esewa_service.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:url_launcher/url_launcher.dart';

/// Customer Bookings tab: list of bookings with status (Pending / History).
class CustomerBookingsTabScreen extends StatefulWidget {
  const CustomerBookingsTabScreen({super.key});

  @override
  State<CustomerBookingsTabScreen> createState() =>
      _CustomerBookingsTabScreenState();
}

class _CustomerBookingsTabScreenState extends State<CustomerBookingsTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _pending = [];
  List<dynamic> _history = [];
  bool _loading = true;
  bool _bookingsLoadFailed = false;
  String? _loadError;
  Map<int, Map<String, dynamic>> _paidPaymentsByBookingId = {};
  Map<int, Map<String, dynamic>> _reviewsByBookingId = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders(preferCache: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime? _normalizeIsoToUtc(dynamic value) {
    final s = value?.toString();
    if (s == null || s.isEmpty) return null;
    final trimmed = s.trim();

    // If it's a simple date (YYYY-MM-DD), treat it as UTC midnight.
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
      return DateTime.tryParse('${trimmed}T00:00:00Z')?.toUtc();
    }

    // If timestamp has an explicit timezone (e.g. +00:00 or Z), keep it.
    // Otherwise assume UTC and append a Z.
    final hasTimezone =
        trimmed.endsWith('Z') || RegExp(r'[+\-]\d{2}:\d{2}$').hasMatch(trimmed);
    final normalized = hasTimezone ? trimmed : '${trimmed}Z';
    return DateTime.tryParse(normalized)?.toUtc();
  }

  Map<String, List<dynamic>> _splitBookings(
    List<dynamic> list,
    Map<int, Map<String, dynamic>> paidMap,
  ) {
    final pending = <dynamic>[];
    final history = <dynamic>[];

    for (final b in list) {
      final status = (b['status'] as String?)?.toLowerCase() ?? '';
      final paymentStatus =
          (b['payment_status'] as String?)?.toLowerCase() ?? '';
      final bookingId = b['id'];
      final bookingIdInt = bookingId is int
          ? bookingId
          : int.tryParse(bookingId?.toString() ?? '') ?? -1;
      final isPaid = paidMap.containsKey(bookingIdInt) ||
          paymentStatus == 'completed' ||
          paymentStatus == 'refund_pending' ||
          paymentStatus == 'refunded' ||
          paymentStatus == 'refund_rejected';

      // Keep unpaid bookings in Pending (even if provider accepted/confirmed or quoted a price).
      final shouldBePending = !isPaid &&
          (status == 'pending' ||
              status == 'quoted' ||
              status == 'awaiting_payment' ||
              status == 'confirmed' ||
              status == 'accepted');
      final shouldBeHistory = isPaid ||
          status == 'completed' ||
          status == 'cancelled' ||
          status == 'refund_pending' ||
          status == 'refunded' ||
          status == 'refund_rejected' ||
          status == 'paid';

      if (shouldBePending) {
        pending.add(b);
      } else if (shouldBeHistory) {
        history.add(b);
      } else {
        // Fallback: treat anything else as history.
        history.add(b);
      }
    }

    return {
      'pending': pending,
      'history': history,
    };
  }

  void _applyBaseBookings(List<dynamic> list) {
    final sorted = List<dynamic>.from(list);

    // Sort by booking date (if set) or creation time, newest first.
    sorted.sort((a, b) {
      // Prefer booking_date (user-selected) for ordering; fall back to created_at.
      final aDate = _normalizeIsoToUtc(a['booking_date'] ?? a['created_at']);
      final bDate = _normalizeIsoToUtc(b['booking_date'] ?? b['created_at']);
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });

    final split = _splitBookings(sorted, const {});
    if (!mounted) return;

    setState(() {
      _pending = split['pending']!;
      _history = split['history']!;
      _paidPaymentsByBookingId = <int, Map<String, dynamic>>{};
      _reviewsByBookingId = <int, Map<String, dynamic>>{};
      _loading = false;
      _bookingsLoadFailed = false;
      _loadError = null;
    });

    if (sorted.isNotEmpty) {
      unawaited(_loadSupplementaryBookingData(List<dynamic>.from(sorted)));
    }
  }

  Future<void> _loadSupplementaryBookingData(List<dynamic> bookings) async {
    if (bookings.isEmpty) {
      if (!mounted) return;
      setState(() {
        _paidPaymentsByBookingId = <int, Map<String, dynamic>>{};
        _reviewsByBookingId = <int, Map<String, dynamic>>{};
      });
      return;
    }

    Future<List<dynamic>> safeLoadReviews() async {
      try {
        return await ApiService.getMyReviews();
      } catch (_) {
        return <dynamic>[];
      }
    }

    Future<Map<String, dynamic>> safeLoadWallet() async {
      try {
        return await ApiService.getWallet();
      } catch (_) {
        return <String, dynamic>{};
      }
    }

    try {
      final results = await Future.wait([
        safeLoadReviews(),
        safeLoadWallet(),
      ]);
      if (!mounted) return;

      final myReviews = List<dynamic>.from(results[0] as List<dynamic>);
      final wallet =
          Map<String, dynamic>.from(results[1] as Map<String, dynamic>);

      final txns = (wallet['transactions'] as List<dynamic>?) ?? [];
      final paidMap = <int, Map<String, dynamic>>{};
      for (final t in txns) {
        if (t is! Map<String, dynamic>) continue;
        final status = (t['status'] as String?)?.toLowerCase() ?? '';
        if (status != 'completed') continue;
        final bookingId = t['booking_id'];
        final bid = bookingId is int
            ? bookingId
            : int.tryParse(bookingId?.toString() ?? '');
        if (bid == null) continue;
        // Keep only latest completed payment per booking.
        final existing = paidMap[bid];
        if (existing == null) {
          paidMap[bid] = t;
        } else {
          final existingDate = _normalizeIsoToUtc(existing['created_at']);
          final thisDate = _normalizeIsoToUtc(t['created_at']);
          if (thisDate != null &&
              existingDate != null &&
              thisDate.isAfter(existingDate)) {
            paidMap[bid] = t;
          }
        }
      }

      final reviewMap = <int, Map<String, dynamic>>{};
      for (final item in myReviews) {
        if (item is! Map) continue;
        final review = Map<String, dynamic>.from(item);
        final bookingId = review['booking_id'] is int
            ? review['booking_id'] as int
            : int.tryParse(review['booking_id']?.toString() ?? '');
        if (bookingId == null) continue;
        reviewMap[bookingId] = review;
      }

      final split = _splitBookings(bookings, paidMap);
      if (!mounted) return;
      setState(() {
        _pending = split['pending']!;
        _history = split['history']!;
        _paidPaymentsByBookingId = paidMap;
        _reviewsByBookingId = reviewMap;
      });
    } catch (_) {
      // Keep base bookings visible even if supplementary calls fail.
    }
  }

  Future<void> _loadOrders({
    bool forceRefresh = false,
    bool showLoading = true,
    bool preferCache = false,
  }) async {
    final hadVisibleData = _pending.isNotEmpty || _history.isNotEmpty;

    setState(() {
      _loading = showLoading && !hadVisibleData;
      _bookingsLoadFailed = false;
      _loadError = null;
    });

    if (preferCache && !forceRefresh) {
      final cached = await ApiService.peekCachedUserBookings();
      if (!mounted) return;

      if (cached != null && (cached.isNotEmpty || hadVisibleData)) {
        _applyBaseBookings(cached);
        unawaited(_loadOrders(forceRefresh: true, showLoading: false));
        return;
      }
    }

    try {
      final list = List<dynamic>.from(
        await ApiService.getUserBookings(forceRefresh: forceRefresh),
      );
      if (!mounted) return;
      _applyBaseBookings(list);
    } catch (e) {
      if (!mounted) return;
      if (e is SessionExpiredException ||
          e.toString().contains('token not valid') ||
          e.toString().contains('SESSION_EXPIRED')) {
        final navigator = Navigator.of(context);
        await TokenStorage.clearTokens();
        if (!mounted) return;
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPrototypeScreen()),
          (_) => false,
        );
        return;
      }

      if (hadVisibleData) {
        setState(() {
          _loading = false;
          _bookingsLoadFailed = false;
          _loadError = null;
        });
        return;
      }

      setState(() {
        _loading = false;
        _bookingsLoadFailed = true;
        _loadError =
            e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
      });
    }
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'cancel_req':
      case 'refund_p_approved':
        return Colors.indigo;
      case 'refund_p_rejected':
        return Colors.redAccent;
      case 'awaiting_payment':
      case 'quoted':
        return Colors.deepPurple;
      case 'paid':
      case 'confirmed':
      case 'accepted':
        return Colors.green;
      case 'assigned':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'refund_pending':
        return Colors.indigo;
      case 'refunded':
        return Colors.teal;
      case 'refund_rejected':
        return Colors.redAccent;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'awaiting_payment':
        return 'Awaiting Payment';
      case 'quoted':
        return 'Quoted';
      case 'paid':
        return 'Paid';
      case 'confirmed':
      case 'accepted':
        return 'Confirmed';
      case 'cancel_req':
      case 'refund_pending':
        return 'Refund Pending';
      case 'refund_p_approved':
        return 'Under Review';
      case 'refund_p_rejected':
      case 'refund_rejected':
        return 'Refund Rejected';
      case 'refunded':
        return 'Refunded';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return (status ?? '').toString();
    }
  }

  bool _isConfirmed(String? status) {
    final s = (status ?? '').toLowerCase();
    return s == 'confirmed' || s == 'accepted';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          AppStrings.t(context, 'bookingsTab'),
          style: TextStyle(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.white,
          unselectedLabelColor: AppTheme.white.withOpacity(0.7),
          indicatorColor: AppTheme.white,
          tabs: [
            Tab(text: AppStrings.t(context, 'pendingTab')),
            Tab(text: AppStrings.t(context, 'historyTab')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList(_pending, isPending: true),
          _buildOrderList(_history, isPending: false),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<dynamic> items, {required bool isPending}) {
    if (_loading) {
      return const _BookingsPageShimmer();
    }
    if (_bookingsLoadFailed) {
      return _buildLoadErrorState();
    }
    if (items.isEmpty) {
      return _buildEmptyState(
        title: AppStrings.t(context, 'noBookingsYet'),
        subtitle: isPending
            ? AppStrings.t(context, 'noActiveBookingNow')
            : AppStrings.t(context, 'noPastBookings'),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadOrders(
        forceRefresh: true,
        showLoading: false,
      ),
      color: AppTheme.customerPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final order = items[index];
          final title = order['service_title'] ??
              order['title'] ??
              AppStrings.t(context, 'booking');
          final desc =
              order['description'] ?? AppStrings.t(context, 'noDescription');
          final status = (order['status'] as String?) ??
              AppStrings.t(context, 'pendingTab');
          final statusLower = status.toLowerCase();

          final bookingId = order['id'];
          final bookingIdInt = bookingId is int
              ? bookingId
              : int.tryParse(bookingId?.toString() ?? '') ?? -1;
          final hasPaid = _paidPaymentsByBookingId.containsKey(bookingIdInt);

          // If the booking is confirmed/accepted but not yet paid, show it as pending
          // to make the payment UI consistent (badge + payment hint).
          final displayStatus = !hasPaid &&
                  (statusLower == 'confirmed' ||
                      statusLower == 'accepted' ||
                      statusLower == 'awaiting_payment' ||
                      statusLower == 'quoted')
              ? (statusLower == 'quoted' || statusLower == 'awaiting_payment'
                  ? 'awaiting_payment'
                  : 'pending')
              : statusLower;

          final time = order['booking_date'] ?? order['created_at'] ?? '—';
          final qp = order['quoted_price'];
          final amount = (qp != null
                  ? (qp is num ? qp.toDouble() : double.tryParse(qp.toString()))
                  : null) ??
              ((order['total_amount'] as num?)?.toDouble() ?? 0.0);
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: Text(
                title is String ? title : AppStrings.t(context, 'booking'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGrey,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    desc is String
                        ? desc
                        : AppStrings.t(context, 'noDescription'),
                    style: TextStyle(
                      color: AppTheme.darkGrey.withOpacity(0.8),
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        time is String ? time : '—',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(displayStatus).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _statusLabel(displayStatus),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(displayStatus),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (displayStatus == 'awaiting_payment' && amount > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long,
                              size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 6),
                          Text(
                            statusLower == 'quoted'
                                ? AppStrings.t(
                                    context, 'providerQuotedPayToConfirm')
                                : AppStrings.t(
                                    context, 'paymentRequiredPayToConfirm'),
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[800],
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              onTap: () {
                final st = (order['status'] as String?) ?? 'pending';
                final showWorkers = ['assigned', 'in progress', 'completed']
                    .contains(st.toLowerCase());
                final showBooked = [
                  'accepted',
                  'confirmed',
                  'assigned',
                  'in progress',
                  'completed'
                ].contains(st.toLowerCase());
                final showPayments =
                    ['in progress', 'completed'].contains(st.toLowerCase());

                // Show bottom sheet with actions
                _showBookingActions(context, order, st);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadErrorState() {
    final errorMessage = (_loadError == null || _loadError!.isEmpty)
        ? 'Could not load bookings right now. Please try again.'
        : _loadError!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 72, color: Colors.grey[500]),
            const SizedBox(height: 14),
            const Text(
              'Could not load bookings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingActions(
      BuildContext context, Map<String, dynamic> order, String status) {
    final normalizedStatus = status.toLowerCase();
    final isPending = normalizedStatus == 'pending';
    final isQuoted = normalizedStatus == 'quoted';
    final isAwaitingPayment = normalizedStatus == 'awaiting_payment';
    final isPaidStatus = normalizedStatus == 'paid';
    final isConfirmed =
        normalizedStatus == 'confirmed' || normalizedStatus == 'accepted';
    final canCancel = [
      'pending',
      'quoted',
      'awaiting_payment',
      'confirmed',
      'accepted',
      'paid',
    ].contains(normalizedStatus);
    final qp = order['quoted_price'];
    final amount = (qp != null
            ? (qp is num ? qp.toDouble() : double.tryParse(qp.toString()))
            : null) ??
        ((order['total_amount'] as num?)?.toDouble() ?? 0.0);
    final serviceName = order['service_title'] ?? order['title'] ?? 'Service';
    final bookingId = order['id']?.toString() ?? '';
    final bookingIdInt = int.tryParse(bookingId) ?? -1;
    final existingReview = _reviewsByBookingId[bookingIdInt];
    final payment = _paidPaymentsByBookingId[bookingIdInt];
    final hasPaid = payment != null;
    final paymentStatus =
        (order['payment_status'] as String?)?.toLowerCase().trim() ?? '';
    final canWriteReview = normalizedStatus == 'completed' ||
        ((normalizedStatus == 'paid' ||
                normalizedStatus == 'confirmed' ||
                normalizedStatus == 'accepted' ||
                normalizedStatus == 'assigned' ||
                normalizedStatus == 'in progress') &&
            (hasPaid || paymentStatus == 'completed'));
    final paidAmount = payment != null
        ? (double.tryParse(payment['amount']?.toString() ?? '') ?? amount)
        : amount;

    String formatPaymentDate(String? iso) {
      if (iso == null || iso.isEmpty) return '';
      final trimmed = iso.trim();
      final normalized = trimmed.endsWith('Z') ||
              RegExp(r'[+\-]\d{2}:\d{2}$').hasMatch(trimmed)
          ? trimmed
          : '${trimmed}Z';
      final dt = DateTime.tryParse(normalized);
      if (dt == null) return '';
      final local = dt.toLocal();
      return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    Future<void> openPayment() async {
      Navigator.pop(context);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ESewaPaymentScreen(
            amount: amount,
            serviceName: serviceName,
            bookingId: bookingId,
            serviceId: order['service_id']?.toString(),
          ),
        ),
      );
      // Refresh list after returning from payment screen so confirmed bookings move to History.
      await _loadOrders(forceRefresh: true, showLoading: false);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.35,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                AppStrings.t(context, 'bookingActions'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              if (hasPaid) ...[
                _buildPaymentDetailsCard(
                  serviceName: serviceName,
                  amount: paidAmount,
                  paidAt: formatPaymentDate(payment['created_at']?.toString()),
                  transactionId: payment['transaction_id']?.toString(),
                ),
                const SizedBox(height: 20),
              ] else if (amount > 0 &&
                  (isPending ||
                      isQuoted ||
                      isAwaitingPayment ||
                      isConfirmed)) ...[
                _buildInvoiceCard(
                  serviceName: serviceName,
                  amount: amount,
                  onPay: openPayment,
                ),
                const SizedBox(height: 20),
              ] else if ((isPending || isQuoted || isAwaitingPayment) &&
                  amount > 0) ...[
                _buildActionTile(
                  icon: Icons.account_balance_wallet,
                  title: AppStrings.t(context, 'payWithEsewa'),
                  subtitle: ESewaService.formatAmount(amount),
                  color: Colors.green[700],
                  onTap: openPayment,
                ),
                const Divider(height: 24),
              ],
              _buildActionTile(
                icon: Icons.info_outline,
                title: AppStrings.t(context, 'viewDetails'),
                subtitle: AppStrings.t(context, 'seeFullBookingInformation'),
                color: Colors.blue[700],
                onTap: () {
                  Navigator.pop(context);
                  _showBookingDetails(context, order);
                },
              ),
              if (canCancel) ...[
                const Divider(height: 24),
                _buildActionTile(
                  icon: Icons.cancel_outlined,
                  title: AppStrings.t(context, 'cancelOrder'),
                  subtitle: AppStrings.t(context, 'cancelOrderAndRefundIfPaid'),
                  color: Colors.red[700]!,
                  onTap: () async {
                    Navigator.pop(context);
                    await _confirmAndCancelOrder(order);
                  },
                ),
              ],
              if (canWriteReview) ...[
                const Divider(height: 24),
                _buildActionTile(
                  icon: Icons.star_outline,
                  title: existingReview == null
                      ? AppStrings.t(context, 'writeReview')
                      : AppStrings.t(context, 'editYourReview'),
                  subtitle: existingReview == null
                      ? AppStrings.t(context, 'rateYourExperience')
                      : AppStrings.t(context, 'updateYourPreviousRating'),
                  color: Colors.amber[700]!,
                  onTap: () {
                    Navigator.pop(context);
                    final bid = order['id'];
                    final id =
                        bid is int ? bid : int.tryParse(bid?.toString() ?? '');
                    if (id != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WriteReviewForBookingScreen(
                            bookingId: id,
                            serviceTitle:
                                (order['service_title'] ?? serviceName)
                                    .toString(),
                            providerName:
                                (order['provider_name'] ?? '').toString(),
                            initialReview: existingReview,
                          ),
                        ),
                      ).then((_) => _loadOrders(
                            forceRefresh: true,
                            showLoading: false,
                          ));
                    }
                  },
                ),
              ],
              if (isPaidStatus) ...[
                const SizedBox(height: 8),
                Text(
                  AppStrings.t(context, 'paidBookingRefundReviewedByAdmin'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
              const Divider(height: 24),
              _buildActionTile(
                icon: Icons.phone,
                title: AppStrings.t(context, 'contactProvider'),
                subtitle: AppStrings.t(context, 'getInTouchWithProvider'),
                color: Colors.orange[700],
                onTap: () {
                  Navigator.pop(context);
                  _showContactProvider(context, order);
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppStrings.t(context, 'close')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBookingDetails(BuildContext context, Map<String, dynamic> order) {
    final serviceTitle = order['service_title'] ?? order['title'] ?? 'Service';
    final providerName = order['provider_name'] ?? 'Provider';
    final status = _statusLabel((order['status'] as String?) ?? '—');
    final bookingDate = order['booking_date']?.toString() ?? '—';
    final bookingTime = order['booking_time']?.toString() ?? '—';
    final amount = order['total_amount'];
    final amountStr = amount != null
        ? ESewaService.formatAmount((amount as num).toDouble())
        : '—';
    final paymentStatus =
        (order['payment_status'] as String?)?.toLowerCase().trim() ?? '';
    final refundStatus =
        (order['refund_status'] as String?)?.toLowerCase().trim() ?? '';
    final notes = (order['notes'] as String?)?.trim() ?? '';
    final bookingId = order['id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.35,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                AppStrings.t(context, 'bookingDetails'),
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800]),
              ),
              const SizedBox(height: 20),
              _detailRow(AppStrings.t(context, 'bookingId'), bookingId),
              _detailRow(AppStrings.t(context, 'service'), serviceTitle),
              _detailRow(AppStrings.t(context, 'provider'), providerName),
              _detailRow(AppStrings.t(context, 'status'), status),
              _detailRow(AppStrings.t(context, 'date'), bookingDate),
              _detailRow(AppStrings.t(context, 'time'), bookingTime),
              _detailRow(AppStrings.t(context, 'amount'), amountStr),
              if (paymentStatus.isNotEmpty)
                _detailRow(AppStrings.t(context, 'payment'), paymentStatus),
              if (refundStatus.isNotEmpty)
                _detailRow(AppStrings.t(context, 'refund'), refundStatus),
              if (notes.isNotEmpty)
                _detailRow(AppStrings.t(context, 'notes'), notes),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppStrings.t(context, 'close')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndCancelOrder(Map<String, dynamic> order) async {
    final bookingId = order['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;
    final paidLike = ((order['payment_status'] as String?) ?? '').toLowerCase();
    final isPaid = paidLike == 'completed' ||
        paidLike == 'refund_pending' ||
        paidLike == 'refunded' ||
        paidLike == 'refund_rejected' ||
        ((order['status'] as String?) ?? '').toLowerCase() == 'paid';

    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.t(context, 'cancelOrderQuestion')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPaid
                  ? AppStrings.t(
                      context, 'paidBookingCancellationStartsRefundReview')
                  : AppStrings.t(context, 'thisBookingWillBeCancelled'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: AppStrings.t(context, 'reasonOptional'),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.t(context, 'no'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white),
            child: Text(AppStrings.t(context, 'yesCancel')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final updated = await ApiService.updateBookingStatus(
        bookingId,
        'cancelled',
        cancelReason: reasonCtrl.text,
      );
      if (!mounted) return;
      final s = (updated['status']?.toString().toLowerCase() ?? '');
      final msg = (s == 'refund_pending' || s == 'cancel_req')
          ? AppStrings.t(context, 'orderCancelledRefundPending')
          : AppStrings.t(context, 'orderCancelledSuccessfully');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _loadOrders(forceRefresh: true, showLoading: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${AppStrings.t(context, 'cancellationFailed')}: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _showContactProvider(BuildContext context, Map<String, dynamic> order) {
    final providerName = order['provider_name'] ?? 'Provider';
    final email = (order['provider_email'] as String?)?.trim() ?? '';
    final phone = (order['provider_phone'] as String?)?.trim() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              AppStrings.t(context, 'contactProvider'),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800]),
            ),
            const SizedBox(height: 8),
            Text(
              providerName,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),
            if (phone.isNotEmpty) ...[
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[50],
                  child: Icon(Icons.phone, color: Colors.green[700]),
                ),
                title: Text(AppStrings.t(context, 'phone')),
                subtitle: Text(phone),
                onTap: () async {
                  final uri = Uri(scheme: 'tel', path: phone);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri(scheme: 'tel', path: phone);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.phone),
                label: Text(AppStrings.t(context, 'callNow')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (email.isNotEmpty) ...[
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[50],
                  child: Icon(Icons.email_outlined, color: Colors.blue[700]),
                ),
                title: Text(AppStrings.t(context, 'email')),
                subtitle: Text(email),
                onTap: () async {
                  final uri = Uri.parse('mailto:$email');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
            ],
            if (phone.isEmpty && email.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  AppStrings.t(context, 'noContactDetails'),
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.t(context, 'close')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceCard({
    required String serviceName,
    required double amount,
    required VoidCallback onPay,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green[50]!,
            Colors.green[100]!.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[700],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.t(context, 'paymentInvoice'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[800],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.t(context, 'providerAcceptedBooking'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  serviceName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkGrey,
                  ),
                ),
                Text(
                  ESewaService.formatAmount(amount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPay,
              icon: const Icon(Icons.account_balance_wallet, size: 20),
              label: Text(AppStrings.t(context, 'payNowWithEsewa')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsCard({
    required String serviceName,
    required double amount,
    required String paidAt,
    String? transactionId,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[50]!,
            Colors.blue[100]!.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[700],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.t(context, 'paymentReceived'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[800],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      paidAt.isNotEmpty
                          ? AppStrings.t(context, 'paidOn')
                              .replaceFirst('{date}', paidAt)
                          : AppStrings.t(context, 'paid'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  serviceName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkGrey,
                  ),
                ),
                Text(
                  ESewaService.formatAmount(amount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
          ),
          if (transactionId != null && transactionId.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              AppStrings.t(context, 'transaction')
                  .replaceFirst('{id}', transactionId),
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color? color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color?.withOpacity(0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

class _BookingsPageShimmer extends StatelessWidget {
  const _BookingsPageShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const _BookingCardShimmer(),
    );
  }
}

class _BookingCardShimmer extends StatelessWidget {
  const _BookingCardShimmer();

  Widget _bar({
    required double widthFactor,
    required double height,
    required Color baseColor,
    required Color highlightColor,
  }) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: SizedBox(
        height: height,
        child: AppShimmerLoader(
          constraints: const BoxConstraints.expand(),
          backgroundColor: baseColor,
          color: highlightColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = Colors.grey.shade300;
    final highlight = Colors.grey.shade100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bar(
            widthFactor: 0.62,
            height: 14,
            baseColor: base,
            highlightColor: highlight,
          ),
          const SizedBox(height: 10),
          _bar(
            widthFactor: 0.92,
            height: 10,
            baseColor: base,
            highlightColor: highlight,
          ),
          const SizedBox(height: 8),
          _bar(
            widthFactor: 0.74,
            height: 10,
            baseColor: base,
            highlightColor: highlight,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _bar(
                widthFactor: 0.32,
                height: 10,
                baseColor: base,
                highlightColor: highlight,
              ),
              const Spacer(),
              SizedBox(
                width: 84,
                height: 24,
                child: AppShimmerLoader(
                  constraints: const BoxConstraints.expand(),
                  backgroundColor: base,
                  color: highlight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
