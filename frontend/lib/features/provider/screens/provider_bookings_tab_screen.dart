import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/booking_detail_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_filter_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_notifications_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/widgets/provider_app_bar.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/esewa_service.dart';

/// Provider Bookings: Total Amount, booking cards with Accept/Decline/Assign, filter.
class ProviderBookingsTabScreen extends StatefulWidget {
  const ProviderBookingsTabScreen({super.key});

  @override
  State<ProviderBookingsTabScreen> createState() =>
      _ProviderBookingsTabScreenState();
}

class _ProviderBookingsTabScreenState extends State<ProviderBookingsTabScreen> {
  List<dynamic> _bookings = [];
  bool _loading = true;
  String _totalAmount = 'Rs 0.00';
  ProviderFilterResult? _filterResult;
  bool _showAmounts = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getUserBookings();
      if (!mounted) return;
      setState(() {
        _bookings = list;
        double total = 0;
        for (final b in list) {
          final status = (b['status'] as String?)?.toLowerCase() ?? '';
          if (status == 'cancelled' || status == 'rejected') continue;
          final amt = b['total_amount'];
          if (amt != null) total += (amt is num) ? amt.toDouble() : 0;
        }
        _totalAmount = 'Rs ${total.toStringAsFixed(2)}';
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _bookings = [];
          _loading = false;
        });
      }
    }
  }

  void _openFilter() async {
    final result = await Navigator.of(context).push<ProviderFilterResult>(
      MaterialPageRoute(builder: (_) => const ProviderFilterScreen()),
    );
    if (result != null && mounted) {
      setState(() => _filterResult = result);
    }
  }

  /// Map filter UI status to API status for matching.
  static String? _filterStatusToApi(String? uiStatus) {
    if (uiStatus == null) return null;
    switch (uiStatus) {
      case 'Pending':
      case 'Pay to Confirm':
        return 'pending';
      case 'Quoted':
        return 'awaiting_payment';
      case 'Awaiting Payment':
        return 'awaiting_payment';
      case 'Paid':
        return 'paid';
      case 'Cancellation Requested':
        return 'cancel_req';
      case 'Confirmed':
        return 'confirmed';
      case 'Completed':
        return 'completed';
      case 'Cancelled':
        return 'cancelled';
      case 'Refund Pending':
        return 'refund_pending';
      case 'Refund Provider Approved':
        return 'refund_p_approved';
      case 'Refund Provider Rejected':
        return 'refund_p_rejected';
      case 'Refunded':
        return 'refunded';
      case 'Refund Rejected':
        return 'refund_rejected';
      default:
        return null;
    }
  }

  List<dynamic> get _filteredBookings {
    if (_filterResult == null) return _bookings;
    var list = _bookings;
    final apiStatus = _filterStatusToApi(_filterResult!.bookingStatus);
    if (apiStatus != null) {
      list = list.where((b) => ((b['status'] as String?) ?? '').toLowerCase() == apiStatus).toList();
    }
    if (_filterResult!.paymentType != null && _filterResult!.paymentType!.isNotEmpty) {
      final pt = _filterResult!.paymentType!.toLowerCase();
      list = list.where((b) {
        final pay = (b['payment_type'] as String?) ?? '';
        if (pt.contains('cash')) return pay.isEmpty || pay.toLowerCase().contains('cash');
        if (pt.contains('esewa')) return pay.toLowerCase().contains('esewa');
        return true;
      }).toList();
    }
    return list;
  }

  Future<void> _updateStatus(dynamic bookingId, String status,
      {Object? quotedPrice}) async {
    final id = bookingId?.toString();
    if (id == null || id.isEmpty) return;
    try {
      await ApiService.updateBookingStatus(id, status, quotedPrice: quotedPrice);
      if (!mounted) return;
      final String msg;
      switch (status) {
        case 'confirmed':
          msg = AppStrings.t(context, 'bookingAcceptedInvoiceSent');
          break;
        case 'quoted':
          msg = AppStrings.t(context, 'quoteSentToCustomer');
          break;
        case 'cancelled':
          msg = AppStrings.t(context, 'bookingDeclined');
          break;
        default:
          msg = AppStrings.t(context, 'updated');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: status == 'cancelled' ? Colors.orange : Colors.green,
        ),
      );
      _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.t(context, 'failedToUpdate')}: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showQuoteDialog(dynamic bookingId) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.t(context, 'sendQuote')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.t(context, 'enterChargeForJobHint')),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: AppStrings.t(context, 'amountRs'),
                border: OutlineInputBorder(),
                prefixText: '${AppStrings.t(context, 'rsPrefix')} ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.t(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.customerPrimary,
              foregroundColor: AppTheme.white,
            ),
            child: Text(AppStrings.t(context, 'sendQuote')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final p = double.tryParse(ctrl.text.trim().replaceAll(',', ''));
    if (p == null || p <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t(context, 'enterAmountGreaterThanZero'))),
      );
      return;
    }
    await _updateStatus(bookingId, 'quoted', quotedPrice: p);
  }

  String _maskAmount(String value) {
    if (_showAmounts) return value;
    return 'Rs ****';
  }

  void _openBookingDetails(dynamic bookingId) {
    final id = bookingId?.toString();
    if (id == null || id.isEmpty) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => BookingDetailScreen(
              bookingId: id,
              isProvider: true,
            ),
          ),
        )
        .then((_) => _loadBookings());
  }

  Future<void> _providerRefundReview(Map<String, dynamic> booking, String action) async {
    final refundId = booking['refund_id'];
    if (refundId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t(context, 'noRefundRequestFound'))),
      );
      return;
    }
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          action == 'approve'
              ? AppStrings.t(context, 'approveRefundRequest')
              : AppStrings.t(context, 'rejectRefundRequest'),
        ),
        content: TextField(
          controller: noteCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: AppStrings.t(context, 'reasonOptional'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.t(context, 'cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'approve' ? Colors.green[700] : Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: Text(action == 'approve' ? AppStrings.t(context, 'approveRefund') : AppStrings.t(context, 'rejectRefund')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.providerReviewRefund(
        refundId: (refundId is num) ? refundId.toInt() : int.parse(refundId.toString()),
        action: action,
        note: noteCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'approve'
                ? AppStrings.t(context, 'refundApprovedWaitingAdmin')
                : AppStrings.t(context, 'refundRequestRejected'),
          ),
          backgroundColor: action == 'approve' ? Colors.green : Colors.orange,
        ),
      );
      _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.t(context, 'failed')}: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showBreakdown() {
    double gross = 0;
    double refunded = 0;
    for (final b in _filteredBookings) {
      final amt = (b['total_amount'] is num) ? (b['total_amount'] as num).toDouble() : 0.0;
      gross += amt;
      final rs = ((b['refund_status'] as String?) ?? '').toLowerCase();
      if (rs == 'refunded') refunded += amt;
    }
    final platformFee = gross * 0.05;
    final tax = gross * 0.13;
    const penalty = 0.0;
    final finalReturned = refunded - penalty;

    Widget rowItem(String label, String value, {bool emphasize = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              _maskAmount(value),
              style: TextStyle(
                fontSize: 14,
                color: emphasize ? AppTheme.customerPrimary : Colors.black87,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.t(context, 'amountBreakdown'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  rowItem(AppStrings.t(context, 'serviceCharge'), 'Rs ${gross.toStringAsFixed(2)}'),
                  rowItem(AppStrings.t(context, 'platformFee'), 'Rs ${platformFee.toStringAsFixed(2)}'),
                  rowItem(AppStrings.t(context, 'tax'), 'Rs ${tax.toStringAsFixed(2)}'),
                  const Divider(height: 18),
                  rowItem(AppStrings.t(context, 'totalAmountPaid'), 'Rs ${(gross + platformFee + tax).toStringAsFixed(2)}', emphasize: true),
                  const SizedBox(height: 2),
                  rowItem(AppStrings.t(context, 'refundAmount'), 'Rs ${refunded.toStringAsFixed(2)}'),
                  rowItem(AppStrings.t(context, 'deductionPenalty'), 'Rs ${penalty.toStringAsFixed(2)}'),
                  const Divider(height: 18),
                  rowItem(AppStrings.t(context, 'finalAmountReturned'), 'Rs ${finalReturned.toStringAsFixed(2)}', emphasize: true),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'pending':
        return Colors.red;
      case 'quoted':
        return Colors.deepPurple;
      case 'awaiting_payment':
        return Colors.deepPurple;
      case 'paid':
        return Colors.green;
      case 'accepted':
      case 'confirmed':
        return Colors.green;
      case 'refund_pending':
        return Colors.indigo;
      case 'cancellation_requested':
      case 'cancel_req':
        return Colors.orangeAccent;
      case 'refund_provider_approved':
      case 'refund_p_approved':
        return Colors.blue;
      case 'refund_provider_rejected':
      case 'refund_p_rejected':
        return Colors.deepOrange;
      case 'refunded':
        return Colors.teal;
      case 'refund_rejected':
        return Colors.redAccent;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(BuildContext context, String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'pending':
        return AppStrings.t(context, 'statusPending');
      case 'quoted':
        return AppStrings.t(context, 'statusQuoted');
      case 'awaiting_payment':
        return AppStrings.t(context, 'statusAwaitingPayment');
      case 'paid':
        return AppStrings.t(context, 'statusPaid');
      case 'accepted':
      case 'confirmed':
        return AppStrings.t(context, 'statusConfirmed');
      case 'cancel_req':
      case 'refund_pending':
        return AppStrings.t(context, 'statusCancellationRequested');
      case 'refund_p_approved':
        return AppStrings.t(context, 'statusRefundProviderApproved');
      case 'refund_p_rejected':
        return AppStrings.t(context, 'statusRefundProviderRejected');
      case 'refunded':
        return AppStrings.t(context, 'statusRefunded');
      case 'refund_rejected':
        return AppStrings.t(context, 'statusRefundRejected');
      case 'cancelled':
        return AppStrings.t(context, 'statusCancelled');
      case 'rejected':
        return AppStrings.t(context, 'statusRejected');
      case 'completed':
        return AppStrings.t(context, 'completed');
      default:
        return status ?? '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          AppStrings.t(context, 'bookingsTab'),
          style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        elevation: 0,
        shape: providerAppBarShape,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const ProviderNotificationsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _openFilter,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${AppStrings.t(context, 'totalAmount')}:',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    Text(
                      _showAmounts ? _totalAmount : 'Rs ****',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _showAmounts = !_showAmounts),
                      icon: Icon(
                        _showAmounts ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppTheme.customerPrimary,
                      ),
                      tooltip: _showAmounts
                          ? AppStrings.t(context, 'hideAmounts')
                          : AppStrings.t(context, 'showAmounts'),
                    ),
                    TextButton(
                      onPressed: _showBreakdown,
                      child: Text(AppStrings.t(context, 'viewBreakdown'),
                          style: TextStyle(
                              color: Colors.green, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: AppShimmerLoader(
                        color: AppTheme.customerPrimary))
                : _filteredBookings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              AppStrings.t(context, 'noBookingsYet'),
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadBookings,
                        color: AppTheme.customerPrimary,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredBookings.length,
                          itemBuilder: (context, index) {
                            final b = _filteredBookings[index];
                            final id = b['id']?.toString() ?? '#${index + 1}';
                            final status =
                                (b['status'] as String?) ?? 'pending';
                            final title =
                              b['service_title'] ?? b['title'] ?? AppStrings.t(context, 'booking');
                            final isPending = status.toLowerCase() == 'pending';
                            final amount = isPending
                              ? AppStrings.t(context, 'awaitingYourQuote')
                                : (b['total_amount'] != null
                                    ? 'Rs ${b['total_amount']}'
                                    : '—');
                            final address = b['address'] ?? AppStrings.t(context, 'unavailable');
                            final date =
                              b['booking_date'] ?? b['created_at'] ?? AppStrings.t(context, 'unavailable');
                            final customer = b['customer_name'] ?? AppStrings.t(context, 'customer');
                            final isAccepted =
                                status.toLowerCase() == 'accepted' ||
                                    status.toLowerCase() == 'confirmed';
                            final isCancellationRequested = status.toLowerCase() == 'cancel_req' ||
                                status.toLowerCase() == 'refund_pending';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _openBookingDetails(b['id']),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          height: 56,
                                          width: 56,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                              Icons.build_circle_outlined,
                                              color: Colors.grey[600]),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  _chip(id,
                                                      AppTheme.customerPrimary),
                                                  const SizedBox(width: 8),
                                                    _chip(_statusLabel(context, status),
                                                      _statusColor(status)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                title is String
                                                    ? title
                                                  : AppStrings.t(context, 'booking'),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Text(
                                                amount.startsWith('Rs ')
                                                    ? _maskAmount(amount)
                                                    : amount,
                                                style: const TextStyle(
                                                  color:
                                                      AppTheme.customerPrimary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                            _detailRow('${AppStrings.t(context, 'address')}:', address),
                                            _detailRow('${AppStrings.t(context, 'date')} & ${AppStrings.t(context, 'time')}:',
                                              date is String ? date : '—'),
                                          _detailRow(
                                              '${AppStrings.t(context, 'customer')}:',
                                              customer is String
                                                  ? customer
                                                  : '—'),
                                        ],
                                      ),
                                    ),
                                    if (isPending ||
                                        isAccepted ||
                                        isCancellationRequested ||
                                        status.toLowerCase() == 'completed') ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          if (isPending) ...[
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () =>
                                                    _showQuoteDialog(b['id']),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppTheme.customerPrimary,
                                                  foregroundColor:
                                                      AppTheme.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 10),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8)),
                                                ),
                                                child: Text(AppStrings.t(context, 'sendQuote')),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () =>
                                                    _updateStatus(b['id'], 'cancelled'),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      AppTheme.customerPrimary,
                                                  side: const BorderSide(
                                                      color: AppTheme
                                                          .customerPrimary),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 10),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8)),
                                                ),
                                                child: Text(AppStrings.t(context, 'decline')),
                                              ),
                                            ),
                                          ] else if (isAccepted)
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () => _openBookingDetails(b['id']),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppTheme.customerPrimary,
                                                  foregroundColor:
                                                      AppTheme.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 10),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8)),
                                                ),
                                                child: Text(AppStrings.t(context, 'manageBooking')),
                                              ),
                                            )
                                          else if (isCancellationRequested) ...[
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () => _providerRefundReview(b, 'approve'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green[700],
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                child: Text(AppStrings.t(context, 'approveRefund')),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () => _providerRefundReview(b, 'reject'),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red[700],
                                                  side: BorderSide(color: Colors.red[300]!),
                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                child: Text(AppStrings.t(context, 'rejectRefund')),
                                              ),
                                            ),
                                          ]
                                          else if (status.toLowerCase() ==
                                              'completed')
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () =>
                                                    _requestPayment(b),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.green[700],
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 10),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8)),
                                                ),
                                                icon: const Icon(
                                                    Icons
                                                        .account_balance_wallet,
                                                    size: 16),
                                                label: Text(
                                                  AppStrings.t(context, 'requestPayment')),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: AppTheme.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.grey[800], fontSize: 13),
          children: [
            TextSpan(
                text: '$label ',
                style: TextStyle(
                    fontWeight: FontWeight.w500, color: Colors.grey[700])),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  void _requestPayment(Map<String, dynamic> booking) {
    final amount = (booking['total_amount'] as num?)?.toDouble() ?? 0.0;
    final serviceName =
        booking['service_title'] ?? booking['title'] ?? 'Service';
    final bookingId = booking['id']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.t(context, 'requestPayment')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AppStrings.t(context, 'service')}: $serviceName'),
            const SizedBox(height: 8),
            Text('${AppStrings.t(context, 'amount')}: ${ESewaService.formatAmount(amount)}'),
            const SizedBox(height: 8),
            Text('${AppStrings.t(context, 'bookingId')}: $bookingId'),
            const SizedBox(height: 16),
            Text(
              AppStrings.t(context, 'sendPaymentRequestViaEsewa'),
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.t(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendPaymentRequest(booking);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
            child: Text(AppStrings.t(context, 'sendRequestToAdmin')),
          ),
        ],
      ),
    );
  }

  void _sendPaymentRequest(Map<String, dynamic> booking) {
    // In a real app, this would:
    // 1. Generate a payment link
    // 2. Send it to the customer via notification/SMS
    // 3. Update booking status to 'payment_requested'

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.t(context, 'paymentRequestSentToCustomer')),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
