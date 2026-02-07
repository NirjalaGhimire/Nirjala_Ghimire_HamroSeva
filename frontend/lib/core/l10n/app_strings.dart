import 'package:flutter/material.dart';

/// English and Nepali strings for the app. Use [AppStrings.t(context, key)].
class AppStrings {
  AppStrings._();

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'appTitle': 'Hamro Sewa',
      'appTagline': 'Your Service Booking Platform',
      'hamroSeva': 'HamroSeva',
      'tagline': 'Connecting Nepal with trusted local services\nServices at your fingertips',
      'selectYourLanguage': 'Select your language',
      'confirm': 'Confirm',
      'login': 'Login',
      'usernameHint': 'Username, email or phone',
      'password': 'Password',
      'dontHaveAccount': "Don't have an account? ",
      'signUp': 'Sign Up',
      'forgetPassword': 'Forget password',
      'orLoginWith': 'Or login with',
      'facebook': 'Facebook',
      'google': 'Google',
      'languageEnglish': 'English',
      'languageNepali': 'नेपाली',
      'pleaseEnterCredentials': 'Please enter username, email or phone and password',
      'loginFailed': 'Login failed',
      'socialLoginFailed': 'Social login failed',
      'connectionTimeout': 'Connection timed out. Is the backend running?',
      'facebookLoginCancelled': 'Facebook login was cancelled',
      'facebookLoginFailed': 'Facebook login failed',
      'couldNotGetFacebookToken': 'Could not get Facebook token',
      'googleSignInCancelled': 'Google sign-in was cancelled',
      'couldNotGetGoogleToken': 'Could not get Google ID token',
      'facebookNotSetUp': 'Facebook login is not set up on this build. Try a full reinstall (flutter clean, then run again).',
      'googleAddSha1': "Google sign-in failed. Add your app's SHA-1 and package name in Google Cloud Console (OAuth Android client).",
    },
    'ne': {
      'appTitle': 'हाम्रो सेवा',
      'appTagline': 'तपाईंको सेवा बुकिङ प्लेटफर्म',
      'hamroSeva': 'HamroSeva',
      'tagline': 'नेपाललाई विश्वसनीय स्थानीय सेवासँग जोड्दै\nउँगलीनै तपाईंको सेवा',
      'selectYourLanguage': 'आफ्नो भाषा छान्नुहोस्',
      'confirm': 'पुष्टि गर्नुहोस्',
      'login': 'लगइन',
      'usernameHint': 'प्रयोगकर्तानामा, इमेल वा फोन',
      'password': 'पासवर्ड',
      'dontHaveAccount': 'खाता छैन? ',
      'signUp': 'साइन अप',
      'forgetPassword': 'पासवर्ड बिर्सनुभयो',
      'orLoginWith': 'वा यससँग लगइन गर्नुहोस्',
      'facebook': 'फेसबुक',
      'google': 'गुगल',
      'languageEnglish': 'English',
      'languageNepali': 'नेपाली',
      'pleaseEnterCredentials': 'कृपया प्रयोगकर्तानामा, इमेल वा फोन र पासवर्ड प्रविष्ट गर्नुहोस्',
      'loginFailed': 'लगइन असफल',
      'socialLoginFailed': 'सामाजिक लगइन असफल',
      'connectionTimeout': 'कनेक्सन समय समाप्त। ब्याकेन्ड चलिरहेको छ?',
      'facebookLoginCancelled': 'फेसबुक लगइन रद्द गरियो',
      'facebookLoginFailed': 'फेसबुक लगइन असफल',
      'couldNotGetFacebookToken': 'फेसबुक टोकन प्राप्त गर्न सकिएन',
      'googleSignInCancelled': 'गुगल साइन-इन रद्द गरियो',
      'couldNotGetGoogleToken': 'गुगल आईडी टोकन प्राप्त गर्न सकिएन',
      'facebookNotSetUp': 'यो बिल्डमा फेसबुक लगइन सेटअप छैन। पूर्ण पुनः इन्स्टल गर्न प्रयास गर्नुहोस्।',
      'googleAddSha1': 'गुगल साइन-इन असफल। Google Cloud Console मा तपाईंको ऐपको SHA-1 र प्याकेज नाम थप्नुहोस्।',
    },
  };

  static String _localeCode(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'ne' ? 'ne' : 'en';
  }

  /// Translate key for current locale. Falls back to English if key missing.
  static String t(BuildContext context, String key) {
    final code = _localeCode(context);
    final map = _strings[code] ?? _strings['en']!;
    return map[key] ?? _strings['en']![key] ?? key;
  }
}
