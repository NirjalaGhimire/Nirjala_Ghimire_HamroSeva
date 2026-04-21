import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full UI: Helpline Number – display and call.
class HelplineScreen extends StatelessWidget {
  const HelplineScreen({super.key});

  static const String _helpline = '9827941092';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'helplineNumber'),
            style: const TextStyle(
                color: AppTheme.white, fontWeight: FontWeight.bold)),
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
                backgroundColor:
                    AppTheme.customerPrimary.withValues(alpha: 0.15),
                child: const Icon(Icons.phone_in_talk,
                    size: 56, color: AppTheme.customerPrimary),
              ),
              const SizedBox(height: 24),
              Text(AppStrings.t(context, 'customerSupport'),
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              const SelectableText(
                _helpline,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse('tel:+977$_helpline');
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.call),
                  label: Text(AppStrings.t(context, 'callNow')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.customerPrimary,
                    foregroundColor: AppTheme.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
