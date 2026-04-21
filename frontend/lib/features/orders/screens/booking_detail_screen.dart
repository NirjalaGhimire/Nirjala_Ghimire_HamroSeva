import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/core/utils/nepal_time.dart';
import 'package:hamro_sewa_frontend/features/payment/screens/esewa_payment_screen.dart';
import 'package:hamro_sewa_frontend/features/payment/screens/payment_receipt_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_customer_profile_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/esewa_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-screen booking detail opened from a notification or list. Works for both customer and provider.
class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({
    super.key,
    required this.bookingId,
    required this.isProvider,
  });

  final String bookingId;
  final bool isProvider;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Map<String, dynamic>? _booking;
  bool _loading = true;
  String? _error;
  bool _showAmounts = true;

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
      final data = await ApiService.getBookingById(widget.bookingId);
      if (mounted) {
        setState(() {
          _booking = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    try {
      await ApiService.updateBookingStatus(widget.bookingId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'cancelled' ? 'Booking cancelled.' : 'Status updated.'),
          backgroundColor: status == 'cancelled' ? Colors.orange : Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.t(context, 'bookingFailed').replaceFirst(
              '{error}', e.toString().replaceFirst('Exception: ', ''))),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _providerReviewRefund(String action) async {
    final b = _booking;
    if (b == null) return;
    final refundId = b['refund_id'];
    if (refundId == null) return;
    try {
      await ApiService.providerReviewRefund(
        refundId: (refundId is num) ? refundId.toInt() : int.parse(refundId.toString()),
        action: action,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(action == 'approve'
              ? AppStrings.t(context, 'refundApprovedWaitingAdmin')
              : AppStrings.t(context, 'refundRequestRejected')),
          backgroundColor: action == 'approve' ? Colors.green : Colors.orange,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showProviderQuoteDialog() async {
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.t(context, 'cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.customerPrimary,
              foregroundColor: Colors.white,
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
    try {
      await ApiService.updateBookingStatus(widget.bookingId, 'quoted', quotedPrice: p);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.t(context, 'quoteSentCustomerCanPay')),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'bookingDetails'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
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
                        Icon(Icons.error_outline,
                            size: 56, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red[700])),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: Text(AppStrings.t(context, 'retry')),
                        ),
                      ],
                    ),
                  ),
                )
              : _booking == null
                  ? Center(child: Text(AppStrings.t(context, 'bookingNotFound')))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppTheme.customerPrimary,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 24),
                            _buildCard(AppStrings.t(context, 'details'), _buildDetails()),
                            if (widget.isProvider) ...[
                              const SizedBox(height: 16),
                              _buildCard('Customer Summary', _buildCustomerSummaryCard()),
                            ],
                            if (widget.isProvider && _hasLocation()) ...[
                              const SizedBox(height: 16),
                              _buildCard(AppStrings.t(context, 'location'), _buildLocationCard()),
                            ],
                            const SizedBox(height: 16),
                            if (widget.isProvider) _buildProviderActions(),
                            if (!widget.isProvider) _buildCustomerActions(),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildHeader() {
    final status = (_booking!['status'] as String?) ?? '—';
    final id = _booking!['id']?.toString() ?? widget.bookingId;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.customerPrimary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('#$id',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.customerPrimary,
                  fontSize: 15)),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _statusColor(status).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(status,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _statusColor(status),
                  fontSize: 14)),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => setState(() => _showAmounts = !_showAmounts),
          icon: Icon(
            _showAmounts ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppTheme.customerPrimary,
          ),
          tooltip: _showAmounts ? AppStrings.t(context, 'hideAmounts') : AppStrings.t(context, 'showAmounts'),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'quoted':
      case 'awaiting_payment':
        return Colors.deepPurple;
      case 'paid':
      case 'confirmed':
      case 'accepted':
        return Colors.green;
      case 'cancellation_requested':
      case 'cancel_req':
        return Colors.orangeAccent;
      case 'refund_provider_approved':
      case 'refund_p_approved':
        return Colors.blue;
      case 'refund_provider_rejected':
      case 'refund_p_rejected':
        return Colors.deepOrange;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      case 'refund_pending':
        return Colors.indigo;
      case 'refunded':
        return Colors.teal;
      case 'refund_rejected':
        return Colors.redAccent;
      case 'completed':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCard(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDetails() {
    final b = _booking!;
    final serviceTitle = b['service_title'] ?? b['title'] ?? 'Service';
    final providerName = b['provider_name'] ?? 'Provider';
    final providerVerified = b['provider_is_verified'] == true ||
        (b['provider_verification_status'] ?? '').toString().toLowerCase() == 'approved';
    final customerName = b['customer_name'] ?? 'Customer';
    final rawDate = b['booking_date']?.toString();
    final rawTime = b['booking_time']?.toString();
    final date = formatNepalDate(rawDate, rawTime);
    final time = formatNepalTime(rawDate, rawTime);
    final amount = b['total_amount'];
    final quoted = b['quoted_price'];
    final statusLower = (b['status'] as String?)?.toLowerCase() ?? '';
    double? rupees;
    if (quoted != null) {
      rupees = quoted is num
          ? quoted.toDouble()
          : double.tryParse(quoted.toString());
    }
    rupees ??= amount != null ? (amount as num).toDouble() : null;
    final amountStr = (rupees != null && rupees > 0)
        ? (_showAmounts ? ESewaService.formatAmount(rupees) : 'Rs ****')
        : 'Will be decided by service provider';
    final notes = (b['notes'] as String?)?.trim() ?? '';
    final address = (b['address'] as String?)?.trim() ?? '';
    final paymentStatus = (b['payment_status'] as String?)?.trim() ?? 'not_applicable';
    final refundStatus = (b['refund_status'] as String?)?.trim() ?? 'not_applicable';
    final refundAmount = b['refund_amount'];
    final requestImage = (b['request_image'] as String?)?.trim() ??
        (b['image_url'] as String?)?.trim() ??
        '';
    final createdAt = b['created_at']?.toString() ?? '';
    final updatedAt = b['updated_at']?.toString() ?? '';

    return Column(
      children: [
        _row(AppStrings.t(context, 'service'), serviceTitle),
        _row(widget.isProvider ? AppStrings.t(context, 'customer') : AppStrings.t(context, 'provider'),
            widget.isProvider ? customerName : providerName),
        if (!widget.isProvider)
          _row(AppStrings.t(context, 'providerVerification'), providerVerified ? AppStrings.t(context, 'verified') : AppStrings.t(context, 'unverified')),
        _row(AppStrings.t(context, 'date'), date),
        _row(AppStrings.t(context, 'time'), time),
        _row(AppStrings.t(context, 'amount'), amountStr),
        _row(AppStrings.t(context, 'paymentStatus'), paymentStatus),
        _row(AppStrings.t(context, 'bookingStatus'), statusLower),
        _row(AppStrings.t(context, 'refundStatus'), refundStatus),
        if (refundAmount != null)
          _row(AppStrings.t(context, 'refundAmount'), _showAmounts ? '${AppStrings.t(context, 'rsPrefix')} $refundAmount' : '${AppStrings.t(context, 'rsPrefix')} ****'),
        if (address.isNotEmpty) _row(AppStrings.t(context, 'address'), address),
        if (notes.isNotEmpty) _row(AppStrings.t(context, 'notes'), notes),
        if (createdAt.isNotEmpty) _row(AppStrings.t(context, 'createdAt'), createdAt),
        if (updatedAt.isNotEmpty) _row(AppStrings.t(context, 'updatedAt'), updatedAt),
        if (requestImage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(AppStrings.t(context, 'uploadedImage'), style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              requestImage,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 80,
                color: Colors.grey[200],
                alignment: Alignment.center,
                child: Text(AppStrings.t(context, 'imageUnavailable')),
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _hasLocation() {
    final b = _booking;
    if (b == null) return false;
    final addr = (b['address'] as String?)?.trim() ?? '';
    final lat = b['latitude'];
    final lng = b['longitude'];
    return addr.isNotEmpty || (lat != null && lng != null);
  }

  Widget _buildLocationCard() {
    final b = _booking!;
    final address = (b['address'] as String?)?.trim() ?? '';
    final lat = _toDouble(b['latitude']);
    final lng = _toDouble(b['longitude']);
    final hasCoords = lat != null && lng != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (address.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        if (hasCoords) ...[
          SizedBox(
            height: 200,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(lat, lng),
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('customer_location'),
                    position: LatLng(lat, lng),
                  ),
                },
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
                liteModeEnabled: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openInGoogleMaps(lat, lng, address),
            icon: const Icon(Icons.directions, size: 20),
            label: Text(AppStrings.t(context, 'openInGoogleMaps')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.customerPrimary,
              side: const BorderSide(color: AppTheme.customerPrimary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomerSummaryCard() {
    final b = _booking!;
    final profile = (b['customer_profile'] is Map)
        ? Map<String, dynamic>.from(b['customer_profile'] as Map)
        : <String, dynamic>{};
    final name = (profile['full_name'] ?? b['customer_name'] ?? 'Customer').toString();
    final email = (profile['email'] ?? b['customer_email'] ?? '').toString().trim();
    final phone = (profile['phone'] ?? b['customer_phone'] ?? '').toString().trim();
    final location = (profile['location'] ?? b['customer_location'] ?? '').toString().trim();
    final imageUrl =
        (profile['profile_image_url'] ?? b['customer_profile_image_url'] ?? '').toString().trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppTheme.customerPrimary.withValues(alpha: 0.15),
              backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
              child: imageUrl.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        color: AppTheme.customerPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(email.isNotEmpty ? email : 'Not provided'),
                  const SizedBox(height: 2),
                  Text(phone.isNotEmpty ? phone : 'Not provided'),
                  const SizedBox(height: 2),
                  Text(location.isNotEmpty ? location : 'Not provided'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProviderCustomerProfileScreen(
                  bookingId: widget.bookingId,
                ),
              ),
            );
          },
          icon: const Icon(Icons.visibility_outlined, size: 20),
          label: const Text('View Customer Profile'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.customerPrimary,
            side: const BorderSide(color: AppTheme.customerPrimary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Future<void> _openInGoogleMaps(double lat, double lng, String address) async {
    final dest = Uri.encodeComponent('$lat,$lng');
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$dest';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 14, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildProviderActions() {
    final status = ((_booking!['status'] as String?) ?? '').toLowerCase();
    final canReviewRefund = status == 'cancel_req' || status == 'refund_pending';
    if (status != 'pending' && !canReviewRefund) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          if (canReviewRefund) ...[
            Expanded(
              child: ElevatedButton(
                onPressed: () => _providerReviewRefund('approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(AppStrings.t(context, 'approveRefund')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _providerReviewRefund('reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  side: BorderSide(color: Colors.red[300]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(AppStrings.t(context, 'rejectRefund')),
              ),
            ),
          ] else ...[
            Expanded(
              child: ElevatedButton(
                onPressed: _showProviderQuoteDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.customerPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(AppStrings.t(context, 'sendQuote')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _updateStatus('cancelled'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  side: BorderSide(color: Colors.red[300]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(AppStrings.t(context, 'decline')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerActions() {
    final status = ((_booking!['status'] as String?) ?? '').toLowerCase();
    final amount = (_booking!['total_amount'] as num?)?.toDouble() ?? 0.0;
    final paymentStatus =
        ((_booking!['payment_status'] as String?) ?? '').toLowerCase();
    final phone = (_booking!['provider_phone'] as String?)?.trim() ?? '';
    final email = (_booking!['provider_email'] as String?)?.trim() ?? '';
    final canCancel = {
      'pending',
      'quoted',
      'awaiting_payment',
      'confirmed',
      'accepted',
      'paid',
    }.contains(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if ((status == 'quoted' || status == 'awaiting_payment') && amount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => ESewaPaymentScreen(
                        bookingId: widget.bookingId,
                        amount: amount,
                        serviceName:
                            _booking!['service_title'] as String? ?? 'Booking',
                      ),
                    ),
                  )
                  .then((_) => _load()),
              icon: const Icon(Icons.payment, size: 20),
              label: Text(AppStrings.t(context, 'payWithEsewa')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.customerPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        if ({
          'paid',
          'completed',
          'refund_pending',
          'refund_provider_approved',
          'refund_p_approved',
          'refunded',
          'refund_rejected',
        }.contains(status))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  final receipt = await ApiService.getReceiptByBooking(widget.bookingId);
                  if (!mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PaymentReceiptScreen(receipt: receipt),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                  );
                }
              },
              icon: const Icon(Icons.receipt_long_outlined, size: 20),
              label: Text(AppStrings.t(context, 'viewReceipt')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.customerPrimary,
                side: const BorderSide(color: AppTheme.customerPrimary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        if (canCancel)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: () => _updateStatus('cancelled'),
              icon: const Icon(Icons.cancel_outlined, size: 20),
              label: Text(AppStrings.t(context, 'cancelOrder')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[700],
                side: BorderSide(color: Colors.red[300]!),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        if (paymentStatus == 'refund_pending' ||
            status == 'refund_pending' ||
            status == 'cancel_req' ||
            status == 'refund_provider_approved' ||
            status == 'refund_p_approved')
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              status == 'refund_provider_approved'
                  ? AppStrings.t(context, 'refundApprovedByProviderAwaitingAdmin')
                  : AppStrings.t(context, 'refundPendingReview'),
              style: TextStyle(color: Colors.indigo[700], fontSize: 13),
            ),
          ),
        if (phone.isNotEmpty || email.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () async {
              if (phone.isNotEmpty) {
                final uri = Uri(scheme: 'tel', path: phone);
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              } else if (email.isNotEmpty) {
                final uri = Uri(scheme: 'mailto', path: email);
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              }
            },
            icon: const Icon(Icons.contact_phone, size: 20),
            label: Text(AppStrings.t(context, 'contactProvider')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.customerPrimary,
              side: const BorderSide(color: AppTheme.customerPrimary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
      ],
    );
  }
}
