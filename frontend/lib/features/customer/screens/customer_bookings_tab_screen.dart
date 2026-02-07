import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/payment/screens/esewa_payment_screen.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/features/reviews/screens/write_review_for_booking_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/esewa_service.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getUserBookings();
      if (!mounted) return;
      final pending = <dynamic>[];
      final history = <dynamic>[];
      for (final b in list) {
        final status = (b['status'] as String?)?.toLowerCase() ?? '';
        if (status == 'cancelled' || status == 'completed') {
          history.add(b);
        } else {
          pending.add(b);
        }
      }
      setState(() {
        _pending = pending;
        _history = history;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        if (e is SessionExpiredException || e.toString().contains('token not valid') || e.toString().contains('SESSION_EXPIRED')) {
          await TokenStorage.clearTokens();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPrototypeScreen()),
            (_) => false,
          );
          return;
        }
        setState(() {
          _pending = [];
          _history = [];
          _loading = false;
        });
      }
    }
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'accepted':
        return Colors.green;
      case 'assigned':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
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
        title: const Text(
          'Bookings',
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
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'History'),
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
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.customerPrimary));
    }
    if (items.isEmpty) {
      return _buildEmptyState(
        title: 'No Bookings Yet',
        subtitle: isPending
            ? 'You have no active booking right now.'
            : 'No past bookings.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: AppTheme.customerPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final order = items[index];
          final title = order['service_title'] ?? order['title'] ?? 'Booking';
          final desc = order['description'] ?? 'No description.';
          final status = order['status'] ?? 'Pending';
          final time = order['booking_date'] ?? order['created_at'] ?? '—';
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
                title is String ? title : 'Booking',
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
                    desc is String ? desc : 'No description.',
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
                          color: _statusColor(status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status is String ? status : 'Pending',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isConfirmed(status)) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long, size: 16, color: Colors.green[700]),
                          const SizedBox(width: 6),
                          Text(
                            'Payment invoice sent – pay to confirm',
                            style: TextStyle(fontSize: 12, color: Colors.green[800], fontWeight: FontWeight.w500),
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

  void _showBookingActions(
      BuildContext context, Map<String, dynamic> order, String status) {
    final isPending = status.toLowerCase() == 'pending';
    final isConfirmed = status.toLowerCase() == 'confirmed' || status.toLowerCase() == 'accepted';
    final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final serviceName = order['service_title'] ?? order['title'] ?? 'Service';
    final bookingId = order['id']?.toString() ?? '';

    void openPayment() {
      Navigator.pop(context);
      Navigator.push(
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
                'Booking Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              if (isConfirmed && amount > 0) ...[
                _buildInvoiceCard(
                  serviceName: serviceName,
                  amount: amount,
                  onPay: openPayment,
                ),
                const SizedBox(height: 20),
              ] else if (isPending && amount > 0) ...[
                _buildActionTile(
                  icon: Icons.account_balance_wallet,
                  title: 'Pay with eSewa',
                  subtitle: ESewaService.formatAmount(amount),
                  color: Colors.green[700],
                  onTap: openPayment,
                ),
                const Divider(height: 24),
              ],
              _buildActionTile(
                icon: Icons.info_outline,
                title: 'View Details',
                subtitle: 'See full booking information',
                color: Colors.blue[700],
                onTap: () {
                  Navigator.pop(context);
                  _showBookingDetails(context, order);
                },
              ),
              if (status.toLowerCase() == 'completed') ...[
                const Divider(height: 24),
                _buildActionTile(
                  icon: Icons.star_outline,
                  title: 'Write a review',
                  subtitle: 'Rate your experience',
                  color: Colors.amber[700]!,
                  onTap: () {
                    Navigator.pop(context);
                    final bid = order['id'];
                    final id = bid is int ? bid : int.tryParse(bid?.toString() ?? '');
                    if (id != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WriteReviewForBookingScreen(
                            bookingId: id,
                            serviceTitle: (order['service_title'] ?? serviceName).toString(),
                          ),
                        ),
                      ).then((_) => _loadOrders());
                    }
                  },
                ),
              ],
              const Divider(height: 24),
              _buildActionTile(
                icon: Icons.phone,
                title: 'Contact Provider',
                subtitle: 'Get in touch with service provider',
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
                  child: const Text('Close'),
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
    final status = (order['status'] as String?) ?? '—';
    final bookingDate = order['booking_date']?.toString() ?? '—';
    final bookingTime = order['booking_time']?.toString() ?? '—';
    final amount = order['total_amount'];
    final amountStr = amount != null ? ESewaService.formatAmount((amount as num).toDouble()) : '—';
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
                'Booking Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
              ),
              const SizedBox(height: 20),
              _detailRow('Booking ID', bookingId),
              _detailRow('Service', serviceTitle),
              _detailRow('Provider', providerName),
              _detailRow('Status', status),
              _detailRow('Date', bookingDate),
              _detailRow('Time', bookingTime),
              _detailRow('Amount', amountStr),
              if (notes.isNotEmpty) _detailRow('Notes', notes),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
              style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
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
              'Contact Provider',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
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
                title: const Text('Phone'),
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
                label: const Text('Call now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
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
                title: const Text('Email'),
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
                  'No contact details available for this provider.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
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
                child: const Icon(Icons.receipt_long, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment invoice',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[800],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Provider accepted your booking',
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
              label: const Text('Pay now with eSewa'),
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
