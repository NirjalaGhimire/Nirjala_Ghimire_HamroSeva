import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';

/// Full UI: Help Desk – FAQ and contact.
class HelpDeskScreen extends StatelessWidget {
  const HelpDeskScreen({super.key});

  static final List<Map<String, String>> _faqs = [
    {'q': 'How do I book a service?', 'a': 'Go to Categories or Search, choose a service, add details and photos, then confirm your booking.'},
    {'q': 'How can I pay?', 'a': 'You can pay via Wallet, eSewa, Khalti, or cash on delivery when the provider supports it.'},
    {'q': 'How do I cancel a booking?', 'a': 'Open the booking from Bookings tab and use the Cancel option. Refund depends on our cancellation policy.'},
    {'q': 'Who do I contact for issues?', 'a': 'Use the Helpline Number in Profile > About App, or email support@hamrosewa.com'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Help Desk', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Frequently asked questions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._faqs.map((faq) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: ExpansionTile(
                title: Text(faq['q']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(faq['a']!, style: TextStyle(color: Colors.grey[700])),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 24),
            const Text(
              'Contact us',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: ListTile(
                leading: const Icon(Icons.phone, color: AppTheme.customerPrimary),
                title: const Text('Helpline'),
                subtitle: const Text('+977-1-XXXXXXX'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ),
            Card(
              margin: const EdgeInsets.only(top: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: ListTile(
                leading: const Icon(Icons.email, color: AppTheme.customerPrimary),
                title: const Text('Email'),
                subtitle: const Text('support@hamrosewa.com'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
