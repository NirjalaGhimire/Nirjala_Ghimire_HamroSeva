import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';

/// About Hamro Sewa – app description in about style.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        title: Text(AppStrings.t(context, 'about'),
            style: const TextStyle(
                color: AppTheme.white, fontWeight: FontWeight.bold)),
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
                  const Icon(Icons.handshake,
                      size: 72, color: AppTheme.customerPrimary),
                  const SizedBox(height: 12),
                  const Text(
                    'Hamro Sewa',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGrey),
                  ),
                  Text(
                    AppStrings.t(
                        context, 'connectingNepalWithTrustedLocalServices'),
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              AppStrings.t(context, 'aboutThisApp'),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.customerPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.t(context, 'aboutAppLong1'),
              style:
                  TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.t(context, 'aboutAppLong2'),
              style:
                  TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.t(context, 'aboutAppLong3'),
              style:
                  TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[800]),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.t(context, 'contactAndSupport'),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.t(context, 'aboutContactSupportText'),
              style:
                  TextStyle(fontSize: 14, height: 1.5, color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                AppStrings.t(context, 'servicesAtYourFingertips'),
                style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
