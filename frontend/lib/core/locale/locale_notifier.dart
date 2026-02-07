import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

/// Holds current app locale. Load from storage on init; save when user changes language.
class LocaleNotifier extends ChangeNotifier {
  LocaleNotifier({String? initialLocaleCode}) {
    _locale = _localeFromCode(initialLocaleCode ?? 'en');
  }

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  static Locale _localeFromCode(String code) {
    if (code == 'ne') return const Locale('ne');
    return const Locale('en');
  }

  Future<void> loadSavedLocale() async {
    final code = await TokenStorage.getLocale();
    _locale = _localeFromCode(code);
    notifyListeners();
  }

  Future<void> setLocale(Locale value) async {
    if (_locale == value) return;
    _locale = value;
    await TokenStorage.saveLocale(value.languageCode);
    notifyListeners();
  }

  String get languageCode => _locale.languageCode;
}
