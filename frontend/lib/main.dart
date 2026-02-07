import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hamro_sewa_frontend/core/locale/locale_notifier.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_shell_screen.dart';
import 'package:hamro_sewa_frontend/features/dashboard/screens/dashboard_screen.dart';
import 'package:hamro_sewa_frontend/features/splash/splash_decider.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  final savedLocale = await TokenStorage.getLocale();
  runApp(HamroSewaApp(initialLocaleCode: savedLocale));
}

class HamroSewaApp extends StatelessWidget {
  const HamroSewaApp({super.key, this.initialLocaleCode});

  final String? initialLocaleCode;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocaleNotifier(initialLocaleCode: initialLocaleCode ?? 'en'),
      child: Consumer<LocaleNotifier>(
        builder: (context, localeNotifier, _) {
          return MaterialApp(
            title: 'Hamro Sewa',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.theme,
            locale: localeNotifier.locale,
            supportedLocales: const [
              Locale('en'),
              Locale('ne'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SplashDecider(),
            routes: {
              '/login': (context) => const LoginPrototypeScreen(),
              '/dashboard': (context) => const DashboardScreen(),
              '/customer': (context) => const CustomerShellScreen(),
            },
          );
        },
      ),
    );
  }
}
