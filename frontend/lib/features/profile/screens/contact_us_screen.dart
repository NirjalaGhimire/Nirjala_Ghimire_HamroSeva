import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:url_launcher/url_launcher.dart';

/// Contact Us: title, "If you have any question we are happy to help", phone, email, Get Connected social icons.
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  static const String _supportPhone = '9827941092';
  static const String _supportEmail = 'hamrosevaprovider@gmail.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          AppStrings.t(context, 'contactUs'),
          style: const TextStyle(
              color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.t(context, 'contactUs'),
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.t(context, 'contactUsSubtitleQuestion'),
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.darkGrey.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                const Icon(Icons.phone_outlined,
                    color: AppTheme.darkGrey, size: 28),
                const SizedBox(width: 16),
                InkWell(
                  onTap: () => _callPhone(),
                  child: const Text(
                    '+977 $_supportPhone',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.darkGrey,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.email_outlined,
                    color: AppTheme.darkGrey, size: 28),
                const SizedBox(width: 16),
                InkWell(
                  onTap: () => _openEmail(context),
                  child: const Text(
                    _supportEmail,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.darkGrey,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Text(
              AppStrings.t(context, 'getConnected'),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _socialIcon(Icons.link, () => _openWebsite()),
                const SizedBox(width: 12),
                _socialIcon(Icons.share, () => _shareContact()),
                const SizedBox(width: 12),
                _socialIcon(Icons.email_outlined, () => _openEmail(context)),
                const SizedBox(width: 12),
                _socialIcon(Icons.phone, () => _callPhone()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialIcon(IconData icon, Future<void> Function() onTap) {
    return Material(
      color: AppTheme.darkGrey,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => onTap(),
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppTheme.white, size: 24),
        ),
      ),
    );
  }

  Future<void> _openWebsite() async {
    final uri = Uri.parse('https://hamrosewa.com');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callPhone() async {
    final uri = Uri.parse('tel:+977$_supportPhone');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openEmail(BuildContext context) async {
    final subject = Uri.encodeComponent('Support Request - Hamro Sewa');
    final body = Uri.encodeComponent('Hello Hamro Sewa team,');

    final mailto = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    ).toString();

    // Prefer opening Gmail directly on Android.
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: mailto,
          package: 'com.google.android.gm',
        );

        final canLaunch = await intent.canResolveActivity();
        if (canLaunch == true) {
          await intent.launch();
          return;
        }
      } catch (_) {
        // Fall back to `mailto:` below.
      }
    }

    final launchedMail = await launchUrl(
      Uri.parse(mailto),
      mode: LaunchMode.externalApplication,
    );
    if (!launchedMail && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppStrings.t(context, 'noEmailAppFoundOnDevice'))),
      );
    }
  }

  Future<void> _shareContact() async {
    await Share.share(
      'Contact Hamro Sewa\n'
      'Phone: +977 $_supportPhone\n'
      'Email: $_supportEmail\n'
      'Website: https://hamrosewa.com',
    );
  }
}
