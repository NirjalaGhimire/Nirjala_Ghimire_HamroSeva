import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full UI: Help Desk – FAQ and contact.
class HelpDeskScreen extends StatelessWidget {
  const HelpDeskScreen({super.key});

  static const String _helplineNumber = '9827941092';
  static const String _supportEmail = 'hamrosevaprovider@gmail.com';

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'q': AppStrings.t(context, 'faqBookServiceQ'),
        'a': AppStrings.t(context, 'faqBookServiceA'),
      },
      {
        'q': AppStrings.t(context, 'faqPayQ'),
        'a': AppStrings.t(context, 'faqPayA'),
      },
      {
        'q': AppStrings.t(context, 'faqCancelBookingQ'),
        'a': AppStrings.t(context, 'faqCancelBookingA'),
      },
      {
        'q': AppStrings.t(context, 'faqContactIssuesQ'),
        'a': AppStrings.t(context, 'faqContactIssuesA'),
      },
    ];
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'helpDesk'),
            style:
                TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.t(context, 'frequentlyAskedQuestions'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...faqs.map((faq) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  child: ExpansionTile(
                    title: Text(faq['q']!,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(faq['a']!,
                            style: TextStyle(color: Colors.grey[700])),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 24),
            Text(
              AppStrings.t(context, 'contactUs'),
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
                leading:
                    const Icon(Icons.phone, color: AppTheme.customerPrimary),
                title: Text(AppStrings.t(context, 'helpline')),
                subtitle: const Text(_helplineNumber),
                trailing: const Icon(Icons.chevron_right),
                onTap: _callPhone,
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
                leading:
                    const Icon(Icons.email, color: AppTheme.customerPrimary),
                title: Text(AppStrings.t(context, 'email')),
                subtitle: const Text(_supportEmail),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openEmail(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callPhone() async {
    final uri = Uri.parse('tel:+977$_helplineNumber');
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
        // Fallback to normal mail client launch below.
      }
    }

    final launchedMail = await launchUrl(
      Uri.parse(mailto),
      mode: LaunchMode.externalApplication,
    );
    if (!launchedMail && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.t(context, 'noEmailAppFoundOnDevice')),
        ),
      );
    }
  }
}
