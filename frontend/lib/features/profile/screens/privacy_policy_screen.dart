import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';

/// Privacy Policy: what data we collect and how we use it. Opens as separate page from Settings.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Privacy Policy', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hamro Sewa Privacy Policy',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
            ),
            const SizedBox(height: 8),
            Text('Last updated: 2026', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 24),
            _section('1. Information we collect', 'We collect information you provide when you register (name, email, phone, password) and when you book services (booking details, address). We also collect usage data to improve the app.'),
            _section('2. How we use your data', 'We use your data to provide and improve our services, process bookings, send notifications, handle payments, and communicate with you. We do not sell your personal information to third parties.'),
            _section('3. Data sharing', 'We may share data with service providers you book through the app (e.g. your name and contact for the booking). Payment data is processed by secure payment providers (e.g. eSewa).'),
            _section('4. Data security', 'We use secure connections and store data on trusted servers. You are responsible for keeping your login credentials safe.'),
            _section('5. Your choices', 'You can update your profile in the app. You can request account deletion through the app. You may opt out of non-essential notifications in Settings.'),
            _section('6. Contact', 'For privacy-related questions, contact us at HamroSeva@gmail.com or use the Contact Us option in Settings.'),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey[800])),
        ],
      ),
    );
  }
}
