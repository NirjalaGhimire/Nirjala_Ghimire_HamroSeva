import 'dart:async';

import 'package:app_links/app_links.dart';

class ReferralLinkService {
  ReferralLinkService._();

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;
  static String? _pendingReferralCode;

  static String? get pendingReferralCode => _pendingReferralCode;

  static Future<void> init() async {
    final initial = await _appLinks.getInitialLink();
    _captureFromUri(initial);

    _sub ??= _appLinks.uriLinkStream.listen(
      _captureFromUri,
      onError: (_) {
        // Ignore malformed/unhandled links.
      },
    );
  }

  static void _captureFromUri(Uri? uri) {
    if (uri == null) return;

    // Custom scheme: hamrosewa://referral?code=HAMRO-XXXX-2026
    if (uri.scheme.toLowerCase() == 'hamrosewa' &&
        uri.host.toLowerCase() == 'referral') {
      final code = uri.queryParameters['code']?.trim();
      if (code != null && code.isNotEmpty) {
        _pendingReferralCode = code.toUpperCase();
      }
      return;
    }

    // Universal link: https://hamrosewa.com/join?ref=... or ?code=...
    final sch = uri.scheme.toLowerCase();
    if (sch == 'https' || sch == 'http') {
      final host = uri.host.toLowerCase();
      if (host == 'hamrosewa.com' || host == 'www.hamrosewa.com') {
        final code = (uri.queryParameters['ref'] ??
                uri.queryParameters['code'] ??
                uri.queryParameters['referral'])
            ?.trim();
        if (code != null && code.isNotEmpty) {
          _pendingReferralCode = code.toUpperCase();
        }
      }
    }
  }
}
