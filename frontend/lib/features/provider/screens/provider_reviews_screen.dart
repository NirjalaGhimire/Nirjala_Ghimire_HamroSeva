import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Provider: list of reviews received from customers (from backend).
class ProviderReviewsScreen extends StatefulWidget {
  const ProviderReviewsScreen({super.key});

  @override
  State<ProviderReviewsScreen> createState() => _ProviderReviewsScreenState();
}

class _ProviderReviewsScreenState extends State<ProviderReviewsScreen> {
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic> _summary = const {
    'total_reviews': 0,
    'average_rating': 0.0,
  };
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
      final payload = await ApiService.getProviderReviews();
      final raw = List<dynamic>.from(payload['reviews'] ?? []);
      final reviews =
          raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _summary = payload['summary'] is Map
              ? Map<String, dynamic>.from(payload['summary'] as Map)
              : const {
                  'total_reviews': 0,
                  'average_rating': 0.0,
                };
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _reviews = [];
          _summary = const {
            'total_reviews': 0,
            'average_rating': 0.0,
          };
          _loading = false;
        });
      }
    }
  }

  static String _formatDate(String? s) {
    if (s == null || s.isEmpty) return '—';
    final d = DateTime.tryParse(s);
    if (d == null) return s;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final averageRating = (() {
      final value = _summary['average_rating'];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    })();
    final totalReviews = (() {
      final value = _summary['total_reviews'];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? _reviews.length;
    })();

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Ratings & Reviews',
            style:
                TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
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
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _reviews.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rate_review_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('No reviews yet',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey[600])),
                          const SizedBox(height: 8),
                          Text(
                            'Reviews from customers will appear here after completed bookings.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reviews.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(Icons.star,
                                      color: Colors.amber[700], size: 28),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        averageRating.toStringAsFixed(1),
                                        style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '$totalReviews review${totalReviews == 1 ? '' : 's'}',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final r = _reviews[index - 1];
                        final service = (r['service'] ?? '').toString();
                        final customerName =
                            (r['customer_name'] ?? '').toString();
                        final rating =
                            r['rating'] is int ? r['rating'] as int : 0;
                        final comment = (r['comment'] ?? '').toString();
                        final date = _formatDate(r['date']?.toString());
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        service.isEmpty ? 'Service' : service,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16),
                                      ),
                                    ),
                                    Row(
                                      children: List.generate(5, (i) {
                                        return Icon(
                                          i < rating
                                              ? Icons.star
                                              : Icons.star_border,
                                          size: 18,
                                          color: Colors.amber,
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$customerName • $date',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                ),
                                if (comment.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(comment,
                                      style:
                                          TextStyle(color: Colors.grey[700])),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
