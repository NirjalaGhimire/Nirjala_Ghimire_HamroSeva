import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';

/// Contact Us: title, "If you have any question we are happy to help", phone, email, Get Connected social icons.
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Contact Us', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Us',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
            ),
            const SizedBox(height: 8),
            Text(
              'If you have any question we are happy to help',
              style: TextStyle(fontSize: 15, color: AppTheme.darkGrey.withOpacity(0.8)),
            ),
            const SizedBox(height: 32),
            const Row(
              children: [
                Icon(Icons.phone_outlined, color: AppTheme.darkGrey, size: 28),
                SizedBox(width: 16),
                Text('+977 9827953057', style: TextStyle(fontSize: 16, color: AppTheme.darkGrey)),
              ],
            ),
            const SizedBox(height: 24),
            const Row(
              children: [
                Icon(Icons.email_outlined, color: AppTheme.darkGrey, size: 28),
                SizedBox(width: 16),
                Text('HamroSeva@gmail.com', style: TextStyle(fontSize: 16, color: AppTheme.darkGrey)),
              ],
            ),
            const SizedBox(height: 40),
            const Text(
              'Get Connected',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _socialIcon(Icons.link),
                const SizedBox(width: 12),
                _socialIcon(Icons.share),
                const SizedBox(width: 12),
                _socialIcon(Icons.camera_alt),
                const SizedBox(width: 12),
                _socialIcon(Icons.chat_bubble_outline),
                const SizedBox(width: 12),
                _socialIcon(Icons.phone),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialIcon(IconData icon) {
    return Material(
      color: AppTheme.darkGrey,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppTheme.white, size: 24),
        ),
      ),
    );
  }
}
