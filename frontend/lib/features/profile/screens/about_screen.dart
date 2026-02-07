import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';

/// About Hamro Sewa – app description in about style.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('About', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const Icon(Icons.handshake, size: 72, color: AppTheme.customerPrimary),
                  const SizedBox(height: 12),
                  const Text(
                    'Hamro Sewa',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                  ),
                  Text(
                    'Connecting Nepal with trusted local services',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'About this app',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.customerPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              'Hamro Sewa is a service-booking platform that connects people across Nepal with trusted local service providers. '
              'Whether you need a plumber, electrician, cleaner, tutor, or any other professional service, Hamro Sewa puts reliable options at your fingertips.',
              style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            Text(
              'For customers, the app lets you browse services by category, choose a provider, book a date and time, and pay securely (including via eSewa). '
              'You can track bookings, leave reviews, and refer friends to earn loyalty points.',
              style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            Text(
              'For service providers, Hamro Sewa offers a simple way to list your services, manage bookings, and grow your local business. '
              'You can verify your identity, showcase your work, and get paid for completed jobs.',
              style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[800]),
            ),
            const SizedBox(height: 24),
            const Text(
              'Contact & support',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
            ),
            const SizedBox(height: 8),
            Text(
              'For help or feedback, use the Helpline Number or Help Desk in your profile. We’re here to make local services easy for everyone.',
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Services at your fingertips.',
                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
