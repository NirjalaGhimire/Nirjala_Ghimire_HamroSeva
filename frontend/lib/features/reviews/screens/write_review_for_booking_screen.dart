import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Write a review for a completed booking: stars + comment, submits to backend.
class WriteReviewForBookingScreen extends StatefulWidget {
  const WriteReviewForBookingScreen({
    super.key,
    required this.bookingId,
    this.serviceTitle = 'Service',
    this.providerName,
    this.initialReview,
  });

  final int bookingId;
  final String serviceTitle;
  final String? providerName;
  final Map<String, dynamic>? initialReview;

  @override
  State<WriteReviewForBookingScreen> createState() =>
      _WriteReviewForBookingScreenState();
}

class _WriteReviewForBookingScreenState
    extends State<WriteReviewForBookingScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _loadingExisting = false;
  bool _hasExistingReview = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadExistingReview();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _applyExistingReview(Map<String, dynamic> review) {
    final existingRating = review['rating'] is int
        ? review['rating'] as int
        : int.tryParse(review['rating']?.toString() ?? '') ?? 0;
    final existingComment = (review['comment'] ?? '').toString();
    if (!mounted) return;
    setState(() {
      _hasExistingReview = (review['exists'] == true) || (review['id'] != null);
      if (existingRating >= 1 && existingRating <= 5) {
        _rating = existingRating;
      }
      _commentController.text = existingComment;
    });
  }

  Future<void> _loadExistingReview() async {
    final seeded = widget.initialReview;
    if (seeded != null && seeded.isNotEmpty) {
      _applyExistingReview(seeded);
      return;
    }

    setState(() => _loadingExisting = true);
    try {
      final review = await ApiService.getReviewForBooking(widget.bookingId);
      if (!mounted) return;
      if (review['exists'] == true) {
        _applyExistingReview(review);
      }
    } catch (_) {
      // Keep screen usable for first-time review writes.
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  Future<void> _submit() async {
    if (_rating < 1 || _rating > 5) return;
    setState(() => _submitting = true);
    try {
      await ApiService.createReview(
        bookingId: widget.bookingId,
        rating: _rating,
        comment: _commentController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_hasExistingReview
                ? AppStrings.t(context, 'reviewUpdatedSuccessfully')
                : AppStrings.t(context, 'reviewPostedThankYou'))),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
            _hasExistingReview
                ? AppStrings.t(context, 'editReview')
                : AppStrings.t(context, 'writeReview'),
            style: const TextStyle(
                color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loadingExisting)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  height: 6,
                  child: AppShimmerLoader(
                    constraints: const BoxConstraints.expand(),
                    backgroundColor: Colors.grey.shade200,
                    color: AppTheme.customerPrimary.withOpacity(0.7),
                  ),
                ),
              ),
            Text(
              widget.serviceTitle,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGrey),
            ),
            if ((widget.providerName ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${AppStrings.t(context, 'provider')}: ${widget.providerName!.trim()}',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              AppStrings.t(context, 'howWasYourExperience'),
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            Text(AppStrings.t(context, 'rating'),
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.darkGrey)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = star),
                  icon: Icon(
                    star <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 40,
                  ),
                );
              }),
            ),
            Text(
              _rating == 0
                  ? AppStrings.t(context, 'tapToRate')
                  : '$_rating / 5',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Text(AppStrings.t(context, 'commentOptional'),
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.darkGrey)),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: AppStrings.t(context, 'shareYourExperience'),
                filled: true,
                fillColor: Colors.grey[50],
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_submitting || _rating == 0) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.customerPrimary,
                  foregroundColor: AppTheme.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: AppShimmerLoader(
                            color: Colors.white, strokeWidth: 2))
                    : Text(_hasExistingReview
                        ? AppStrings.t(context, 'updateReview')
                        : AppStrings.t(context, 'submitReview')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
