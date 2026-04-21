/// Text used when sharing a referral — includes https URL (for link previews),
/// app deep link, and contact lines (phone / email / website) like messaging apps expect.
class ReferralShareContent {
  ReferralShareContent._();

  /// Public site (WhatsApp/Telegram often show a preview for the first https URL).
  static const String websiteBase = 'https://hamrosewa.com';

  static const String phoneDisplay = '+977 9827941092';
  static const String email = 'hamrosevaprovider@gmail.com';

  /// Web join URL with referral (encode code for query).
  static String webJoinUrl(String referralCode) {
    final q = Uri.encodeQueryComponent(referralCode.trim());
    return '$websiteBase/join?ref=$q';
  }

  /// App deep link (handled by [ReferralLinkService]).
  static String appReferralLink(String referralCode) {
    final q = Uri.encodeQueryComponent(referralCode.trim());
    return 'hamrosewa://referral?code=$q';
  }

  /// Full message: link-first for previews, then contact block, then human copy + code.
  static String buildMessage(String referralCode) {
    final code = referralCode.trim();
    if (code.isEmpty) return '';

    final web = webJoinUrl(code);
    final app = appReferralLink(code);

    return '''
Hamro Sewa — Join with my referral

$web

Open in app:
$app

Contact Hamro Sewa
Phone: $phoneDisplay
Email: $email
Website: $websiteBase

Join Hamro Sewa and sign up with my referral code: $code

Both of you earn loyalty points instantly.''';
  }
}
