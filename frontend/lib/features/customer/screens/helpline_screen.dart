import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';

/// Full UI: Helpline Number – display and call.
class HelplineScreen extends StatelessWidget {
  const HelplineScreen({super.key});

  static const String helpline = '+977-1-4XXXXXX';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Helpline Number', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: AppTheme.customerPrimary.withOpacity(0.15),
                child: const Icon(Icons.phone_in_talk, size: 56, color: AppTheme.customerPrimary),
              ),
              const SizedBox(height: 24),
              const Text('Customer support', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              const SelectableText(
                helpline,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.call),
                  label: const Text('Call now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.customerPrimary,
                    foregroundColor: AppTheme.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
