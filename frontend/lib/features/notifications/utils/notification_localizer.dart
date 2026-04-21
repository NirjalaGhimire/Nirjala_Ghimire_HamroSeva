import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';

class NotificationLocalizer {
  NotificationLocalizer._();

  static bool _isNepali(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ne';

  static String _fmt(String template, Map<String, String> vars) {
    var out = template;
    vars.forEach((k, v) {
      out = out.replaceAll('{$k}', v);
    });
    return out;
  }

  static String _replacePhrase(String text, String from, String to) {
    if (text.isEmpty) return text;
    return text.replaceAll(RegExp(from, caseSensitive: false), to);
  }

  static String _replaceWord(String text, String fromWord, String to) {
    if (text.isEmpty) return text;
    return text.replaceAll(
      RegExp('\\b${RegExp.escape(fromWord)}\\b', caseSensitive: false),
      to,
    );
  }

  static String _localizeFallbackTitleNepali(String title) {
    var t = title;
    final replacements = <MapEntry<String, String>>[
      const MapEntry(r'price quote received', 'मूल्य कोट प्राप्त भयो'),
      const MapEntry(r'booking cancelled', 'बुकिङ रद्द भयो'),
      const MapEntry(r'cancellation requested', 'रद्द अनुरोध प्राप्त भयो'),
      const MapEntry(r'refund updated', 'रिफन्ड अपडेट भयो'),
      const MapEntry(
          r'refund approved by provider', 'प्रदायकद्वारा रिफन्ड स्वीकृत भयो'),
      const MapEntry(
          r'refund rejected by provider', 'प्रदायकद्वारा रिफन्ड अस्वीकृत भयो'),
      const MapEntry(r'refund review required', 'रिफन्ड समीक्षा आवश्यक'),
      const MapEntry(r'refund review updated', 'रिफन्ड समीक्षा अपडेट भयो'),
      const MapEntry(r'refund approved', 'रिफन्ड स्वीकृत भयो'),
      const MapEntry(r'refund rejected', 'रिफन्ड अस्वीकृत भयो'),
      const MapEntry(r'notification', 'सूचना'),
    ];

    for (final entry in replacements) {
      t = _replacePhrase(t, entry.key, entry.value);
    }
    return t;
  }

  static String _localizeFallbackBodyNepali(String body) {
    var b = body;
    // Phrase-level replacements first (longest and most specific).
    final phraseReplacements = <MapEntry<String, String>>[
      const MapEntry(r'pay to confirm your booking',
          'बुकिङ पुष्टि गर्न भुक्तानी गर्नुहोस्'),
      const MapEntry(
          r'provider review is required', 'प्रदायक समीक्षा आवश्यक छ'),
      const MapEntry(
          r'awaiting admin processing', 'एडमिन प्रशोधनको प्रतीक्षामा'),
      const MapEntry(r'refund provider-approved for booking',
          'बुकिङका लागि रिफन्ड प्रदायकद्वारा स्वीकृत भयो'),
      const MapEntry(
          r'process final refund', 'अन्तिम रिफन्ड प्रक्रिया गर्नुहोस्'),
      const MapEntry(r'refund request was rejected by provider',
          'रिफन्ड अनुरोध प्रदायकले अस्वीकृत गर्नुभयो'),
      const MapEntry(r'provider approved refund for booking',
          'बुकिङका लागि प्रदायकले रिफन्ड स्वीकृत गर्नुभयो'),
      const MapEntry(r'provider rejected refund request for booking',
          'बुकिङका लागि प्रदायकले रिफन्ड अनुरोध अस्वीकृत गर्नुभयो'),
      const MapEntry(r'refund for booking', 'बुकिङको रिफन्ड'),
      const MapEntry(
          r'booking cancellation requested', 'बुकिङ रद्द अनुरोध गरिएको छ'),
      const MapEntry(r'cancellation requested', 'रद्द अनुरोध प्राप्त भयो'),
      const MapEntry(r'booking cancelled', 'बुकिङ रद्द भयो'),
      const MapEntry(r'quoted rs', 'रु को मूल्य कोट गर्नुभयो'),
      const MapEntry(r'for "', 'का लागि "'),
      const MapEntry(r'was cancelled', 'रद्द गरिएको छ'),
    ];

    for (final entry in phraseReplacements) {
      b = _replacePhrase(b, entry.key, entry.value);
    }

    // Word-level replacements with boundaries.
    b = _replaceWord(b, 'booking', 'बुकिङ');
    b = _replaceWord(b, 'refund', 'रिफन्ड');
    b = _replaceWord(b, 'approved', 'स्वीकृत');
    b = _replaceWord(b, 'rejected', 'अस्वीकृत');
    b = _replaceWord(b, 'provider', 'प्रदायक');
    b = _replaceWord(b, 'process', 'प्रक्रिया');
    b = _replaceWord(b, 'final', 'अन्तिम');

    return b;
  }

  static String localizeTitle(BuildContext context, String? rawTitle) {
    final title = (rawTitle ?? '').trim();
    if (title.isEmpty) return AppStrings.t(context, 'notification');

    final lower = title.toLowerCase();
    if (lower == 'price quote received') {
      return AppStrings.t(context, 'notificationPriceQuoteReceived');
    }
    if (lower == 'booking cancelled') {
      return AppStrings.t(context, 'notificationBookingCancelled');
    }
    if (lower == 'refund updated') {
      return AppStrings.t(context, 'notificationRefundUpdated');
    }
    if (lower == 'refund approved by provider') {
      return AppStrings.t(context, 'notificationRefundApprovedByProvider');
    }
    if (lower == 'refund rejected by provider') {
      return AppStrings.t(context, 'notificationRefundRejectedByProvider');
    }
    if (lower == 'refund review required') {
      return AppStrings.t(context, 'notificationRefundReviewRequired');
    }
    if (lower == 'refund review updated') {
      return AppStrings.t(context, 'notificationRefundReviewUpdated');
    }
    if (lower == 'refund approved') {
      return AppStrings.t(context, 'notificationRefundApproved');
    }
    if (lower == 'refund rejected') {
      return AppStrings.t(context, 'notificationRefundRejected');
    }
    if (lower == 'cancellation requested') {
      return _isNepali(context) ? 'रद्द अनुरोध प्राप्त भयो' : title;
    }

    if (_isNepali(context)) {
      return _localizeFallbackTitleNepali(title);
    }

    return title;
  }

  static String localizeBody(BuildContext context, String? rawBody) {
    final body = (rawBody ?? '').trim();
    if (body.isEmpty) return '';
    if (!_isNepali(context)) return body;

    RegExpMatch? m;

    m = RegExp(
      r'^(.+?) quoted Rs ([0-9.]+) for "(.+?)"\. Pay to confirm your booking\.$',
      caseSensitive: false,
    ).firstMatch(body);
    if (m != null) {
      return _fmt(
        AppStrings.t(context, 'notificationQuotedBody'),
        {
          'provider': m.group(1)!.trim(),
          'amount': m.group(2)!.trim(),
          'service': m.group(3)!.trim(),
        },
      );
    }

    m = RegExp(
      r'^Booking #(\d+) \((.+?)\) was cancelled\.$',
      caseSensitive: false,
    ).firstMatch(body);
    if (m != null) {
      return _fmt(
        AppStrings.t(context, 'notificationBookingCancelledBody'),
        {
          'bookingId': m.group(1)!.trim(),
          'service': m.group(2)!.trim(),
        },
      );
    }

    m = RegExp(
      r'^Refund for Booking #(\d+) approved\.$',
      caseSensitive: false,
    ).firstMatch(body);
    if (m != null) {
      return _fmt(
        AppStrings.t(context, 'notificationRefundApprovedBody'),
        {'bookingId': m.group(1)!.trim()},
      );
    }

    m = RegExp(
      r'^Refund for Booking #(\d+) was rejected\.$',
      caseSensitive: false,
    ).firstMatch(body);
    if (m != null) {
      return _fmt(
        AppStrings.t(context, 'notificationRefundRejectedBody'),
        {'bookingId': m.group(1)!.trim()},
      );
    }

    m = RegExp(
      r'^Booking #(\d+) refund approved by provider\. Awaiting admin processing\.$',
      caseSensitive: false,
    ).firstMatch(body);
    if (m != null) {
      return _fmt(
        AppStrings.t(context, 'notificationRefundApprovedAwaitingAdminBody'),
        {'bookingId': m.group(1)!.trim()},
      );
    }

    m = RegExp(
      r'^Booking #(\d+) refund request was rejected by provider\.$',
      caseSensitive: false,
    ).firstMatch(body);
    if (m != null) {
      return _fmt(
        AppStrings.t(context, 'notificationRefundRejectedByProviderBody'),
        {'bookingId': m.group(1)!.trim()},
      );
    }

    m = RegExp(
      r'^Provider approved refund for Booking #(\d+)\. Awaiting admin processing\.$',
      caseSensitive: false,
    ).firstMatch(body);
    if (m != null) {
      return _fmt(
        AppStrings.t(
            context, 'notificationProviderApprovedRefundAwaitingAdminBody'),
        {'bookingId': m.group(1)!.trim()},
      );
    }

    m = RegExp(
      r'^Provider approved refund for Booking #(\d+)\.$',
      caseSensitive: false,
    ).firstMatch(body);
    if (m != null) {
      return _fmt(
        AppStrings.t(context, 'notificationProviderApprovedRefundBody'),
        {'bookingId': m.group(1)!.trim()},
      );
    }

    m = RegExp(
      r'^Provider rejected refund request for Booking #(\d+)\.$',
      caseSensitive: false,
    ).firstMatch(body);
    if (m != null) {
      return _fmt(
        AppStrings.t(context, 'notificationProviderRejectedRefundBody'),
        {'bookingId': m.group(1)!.trim()},
      );
    }

    return _localizeFallbackBodyNepali(body);
  }

  static String timeAgo(BuildContext context, String? iso) {
    if (iso == null || iso.isEmpty) return AppStrings.t(context, 'recently');

    String normalizeIso(String value) {
      final v = value.trim();
      if (v.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(v)) {
        return v;
      }
      return '${v}Z';
    }

    final parsed = DateTime.tryParse(normalizeIso(iso));
    if (parsed == null) return AppStrings.t(context, 'recently');

    final diff = DateTime.now().toUtc().difference(parsed.toUtc());
    if (diff.inSeconds < 60) return AppStrings.t(context, 'justNow');
    if (diff.inMinutes < 60) {
      return _fmt(
        AppStrings.t(context, 'minutesAgo'),
        {'value': '${diff.inMinutes}'},
      );
    }
    if (diff.inHours < 24) {
      return _fmt(
        AppStrings.t(context, 'hoursAgo'),
        {'value': '${diff.inHours}'},
      );
    }
    return _fmt(
      AppStrings.t(context, 'daysAgo'),
      {'value': '${diff.inDays}'},
    );
  }
}
