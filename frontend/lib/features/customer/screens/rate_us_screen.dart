import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/reviews/screens/write_review_for_booking_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Booking-linked Rate Us page.
/// Shows reviewable bookings and opens write/edit review for the selected provider.
class RateUsScreen extends StatefulWidget {
  const RateUsScreen({super.key});

  @override
  State<RateUsScreen> createState() => _RateUsScreenState();
}

class _RateUsScreenState extends State<RateUsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _completedBookings = [];
  Map<int, Map<String, dynamic>> _reviewsByBookingId = {};

  @override
  void initState() {
    super.initState();
    _loadReviewableBookings();
  }

  Future<void> _loadReviewableBookings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getUserBookings(),
        ApiService.getMyReviews(),
      ]);
      final bookingsRaw = List<dynamic>.from(results[0]);
      final reviewsRaw = List<dynamic>.from(results[1]);

      final completed = <Map<String, dynamic>>[];
      for (final item in bookingsRaw) {
        final map = item is Map<String, dynamic>
            ? item
            : (item is Map ? Map<String, dynamic>.from(item) : null);
        if (map == null) continue;
        final status = (map['status'] ?? '').toString().toLowerCase();
        final paymentStatus =
            (map['payment_status'] ?? '').toString().toLowerCase();
        final reviewable = status == 'completed' ||
            ((status == 'paid' ||
                    status == 'confirmed' ||
                    status == 'accepted' ||
                    status == 'assigned' ||
                    status == 'in progress') &&
                paymentStatus == 'completed');
        if (reviewable) {
          completed.add(Map<String, dynamic>.from(map));
        }
      }

      completed.sort((a, b) {
        final aDate = DateTime.tryParse(
                (a['booking_date'] ?? a['created_at'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse(
                (b['booking_date'] ?? b['created_at'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      final reviewMap = <int, Map<String, dynamic>>{};
      for (final item in reviewsRaw) {
        final map = item is Map<String, dynamic>
            ? item
            : (item is Map ? Map<String, dynamic>.from(item) : null);
        if (map == null) continue;
        final bookingId = map['booking_id'] is int
            ? map['booking_id'] as int
            : int.tryParse(map['booking_id']?.toString() ?? '');
        if (bookingId == null) continue;
        reviewMap[bookingId] = Map<String, dynamic>.from(map);
      }

      if (!mounted) return;
      setState(() {
        _completedBookings = completed;
        _reviewsByBookingId = reviewMap;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _completedBookings = [];
        _reviewsByBookingId = {};
        _loading = false;
      });
    }
  }

  Future<void> _openReview(Map<String, dynamic> booking) async {
    final bookingId = booking['id'] is int
        ? booking['id'] as int
        : int.tryParse(booking['id']?.toString() ?? '');
    if (bookingId == null) return;
    final existingReview = _reviewsByBookingId[bookingId];
    final didChange = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WriteReviewForBookingScreen(
          bookingId: bookingId,
          serviceTitle:
              (booking['service_title'] ?? booking['title'] ?? 'Service')
                  .toString(),
          providerName: (booking['provider_name'] ?? '').toString(),
          initialReview: existingReview,
        ),
      ),
    );
    if (didChange == true) {
      await _loadReviewableBookings();
    }
  }

  String _formatDate(dynamic raw) {
    final text = (raw ?? '').toString();
    final dt = DateTime.tryParse(text);
    if (dt == null) return text.isEmpty ? '—' : text;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'rateProviders'),
            style:
                TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
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
                        const SizedBox(height: 12),
                        TextButton(
                            onPressed: _loadReviewableBookings,
                            child: Text(AppStrings.t(context, 'retry'))),
                      ],
                    ),
                  ),
                )
              : _completedBookings.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.rate_review_outlined,
                                size: 60, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                                AppStrings.t(
                                    context, 'noReviewableBookingsYet'),
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text(
                              AppStrings.t(context, 'reviewableBookingsHint'),
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReviewableBookings,
                      color: AppTheme.customerPrimary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _completedBookings.length,
                        itemBuilder: (context, index) {
                          final booking = _completedBookings[index];
                          final bookingId = booking['id'] is int
                              ? booking['id'] as int
                              : int.tryParse(booking['id']?.toString() ?? '');
                          final review = bookingId != null
                              ? _reviewsByBookingId[bookingId]
                              : null;
                          final rating = review != null
                              ? (review['rating'] is int
                                  ? review['rating'] as int
                                  : int.tryParse(
                                          review['rating']?.toString() ?? '') ??
                                      0)
                              : 0;

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (booking['service_title'] ??
                                            booking['title'] ??
                                            AppStrings.t(context, 'service'))
                                        .toString(),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (booking['provider_name'] ?? 'Provider')
                                        .toString(),
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${AppStrings.t(context, 'serviceDate')}: ${_formatDate(booking['booking_date'] ?? booking['created_at'])}',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  if (review != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        ...List.generate(5, (i) {
                                          return Icon(
                                            i < rating
                                                ? Icons.star
                                                : Icons.star_border,
                                            size: 18,
                                            color: Colors.amber,
                                          );
                                        }),
                                        const SizedBox(width: 8),
                                        Text(
                                            AppStrings.t(context, 'yourReview'),
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700])),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _openReview(booking),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppTheme.customerPrimary,
                                        foregroundColor: AppTheme.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      icon: Icon(review == null
                                          ? Icons.rate_review_outlined
                                          : Icons.edit),
                                      label: Text(review == null
                                          ? AppStrings.t(context, 'writeReview')
                                          : AppStrings.t(
                                              context, 'editReview')),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
