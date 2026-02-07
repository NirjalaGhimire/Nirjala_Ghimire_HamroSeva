import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/order_detail_screen.dart';
import 'package:hamro_sewa_frontend/features/payment/screens/esewa_payment_screen.dart';
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
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProviderFilterScreen()),
    );
    _loadBookings();
  }

  Future<void> _updateStatus(dynamic bookingId, String status) async {
    final id = bookingId?.toString();
    if (id == null || id.isEmpty) return;
    try {
      await ApiService.updateBookingStatus(id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'confirmed'
              ? 'Booking accepted. Payment invoice will be sent to the customer.'
              : 'Booking declined.'),
          backgroundColor: status == 'confirmed' ? Colors.green : Colors.orange,
        ),
      );
      _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'pending':
        return Colors.red;
      case 'accepted':
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Bookings',
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
                      'Total Amount:',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    Text(
                      _totalAmount,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('View Breakdown',
                      style: TextStyle(
                          color: Colors.green, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.customerPrimary))
                : _bookings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No bookings yet',
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
                          itemCount: _bookings.length,
                          itemBuilder: (context, index) {
                            final b = _bookings[index];
                            final id = b['id']?.toString() ?? '#${index + 1}';
                            final status =
                                (b['status'] as String?) ?? 'pending';
                            final title =
                                b['service_title'] ?? b['title'] ?? 'Booking';
                            final amount = b['total_amount'] != null
                                ? 'Rs ${b['total_amount']}'
                                : '—';
                            final address = b['address'] ?? '—';
                            final date =
                                b['booking_date'] ?? b['created_at'] ?? '—';
                            final customer = b['customer_name'] ?? 'Customer';
                            final isPending = status.toLowerCase() == 'pending';
                            final isAccepted =
                                status.toLowerCase() == 'accepted' ||
                                    status.toLowerCase() == 'confirmed';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
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
                                                  _chip(status,
                                                      _statusColor(status)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                title is String
                                                    ? title
                                                    : 'Booking',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Text(
                                                amount,
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
                                          _detailRow('Address:', address),
                                          _detailRow('Date & Time:',
                                              date is String ? date : '—'),
                                          _detailRow(
                                              'Customer:',
                                              customer is String
                                                  ? customer
                                                  : '—'),
                                        ],
                                      ),
                                    ),
                                    if (isPending ||
                                        isAccepted ||
                                        status.toLowerCase() ==
                                            'completed') ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          if (isPending) ...[
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () =>
                                                    _updateStatus(b['id'], 'confirmed'),
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
                                                child: const Text('Accept'),
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
                                                child: const Text('Decline'),
                                              ),
                                            ),
                                          ] else if (isAccepted)
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () {},
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
                                                child: const Text('Assign'),
                                              ),
                                            )
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
                                                label: const Text(
                                                    'Request Payment'),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
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
        title: const Text('Request Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service: $serviceName'),
            const SizedBox(height: 8),
            Text('Amount: ${ESewaService.formatAmount(amount)}'),
            const SizedBox(height: 8),
            Text('Booking ID: $bookingId'),
            const SizedBox(height: 16),
            const Text(
              'Send payment request to customer via eSewa?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
            child: const Text('Send Request'),
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
      const SnackBar(
        content: Text('Payment request sent to customer!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
