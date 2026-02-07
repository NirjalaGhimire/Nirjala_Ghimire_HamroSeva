import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/reviews/screens/write_review_screen.dart';

/// Ratings & Reviews: empty state with "Write a review" button, or list of reviews.
class RatingsReviewsScreen extends StatelessWidget {
  const RatingsReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightLavender,
      appBar: AppBar(
        title: const Text('Ratings & Reviews', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Ratings & Reviews',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Share your thoughts with other customers',
                style: TextStyle(fontSize: 15, color: AppTheme.darkGrey.withOpacity(0.8)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WriteReviewScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkGrey,
                    foregroundColor: AppTheme.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Write a review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
