import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';

/// Privacy Policy: what data we collect and how we use it. Opens as separate page from Settings.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        title: Text(AppStrings.t(context, 'privacyPolicyTitle'),
            style: const TextStyle(
                color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.t(context, 'hamroSewaPrivacyPolicy'),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey),
            ),
            const SizedBox(height: 8),
            Text(AppStrings.t(context, 'lastUpdated2026'),
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 24),
            _section(AppStrings.t(context, 'privacySection1Title'),
                AppStrings.t(context, 'privacySection1Body')),
            _section(AppStrings.t(context, 'privacySection2Title'),
                AppStrings.t(context, 'privacySection2Body')),
            _section(AppStrings.t(context, 'privacySection3Title'),
                AppStrings.t(context, 'privacySection3Body')),
            _section(AppStrings.t(context, 'privacySection4Title'),
                AppStrings.t(context, 'privacySection4Body')),
            _section(AppStrings.t(context, 'privacySection5Title'),
                AppStrings.t(context, 'privacySection5Body')),
            _section(AppStrings.t(context, 'privacySection6Title'),
                AppStrings.t(context, 'privacySection6Body')),
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
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey)),
          const SizedBox(height: 6),
          Text(body,
              style: TextStyle(
                  fontSize: 14, height: 1.5, color: Colors.grey[800])),
        ],
      ),
    );
  }
}
