import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hamro_sewa_frontend/core/locale/locale_notifier.dart';
import 'package:hamro_sewa_frontend/core/theme/theme_notifier.dart';
import 'package:hamro_sewa_frontend/features/admin/screens/admin_refund_management_screen.dart';
import 'package:hamro_sewa_frontend/features/admin/screens/admin_shell_screen.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_shell_screen.dart';
import 'package:hamro_sewa_frontend/features/dashboard/screens/dashboard_screen.dart';
import 'package:hamro_sewa_frontend/features/splash/splash_decider.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/referral_link_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: 'assets/.env');
  } catch (_) {
    // assets/.env missing or parse error — Google Sign-In may need --dart-define or a fixed .env
  }
  await ApiService.init();
  await ReferralLinkService.init();
  final savedLocale = await TokenStorage.getLocale();
  final themeNotifier = await ThemeNotifier.load();
  runApp(HamroSewaApp(
    initialLocaleCode: savedLocale,
    themeNotifier: themeNotifier,
  ));
}

class HamroSewaApp extends StatelessWidget {
  const HamroSewaApp({
    super.key,
    this.initialLocaleCode,
    required this.themeNotifier,
  });

  final String? initialLocaleCode;
  final ThemeNotifier themeNotifier;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeNotifier>.value(value: themeNotifier),
        ChangeNotifierProvider(
          create: (_) =>
              LocaleNotifier(initialLocaleCode: initialLocaleCode ?? 'en'),
        ),
      ],
      child: Consumer2<ThemeNotifier, LocaleNotifier>(
        builder: (context, theme, localeNotifier, _) {
          return MaterialApp(
            title: 'Hamro Sewa',
            debugShowCheckedModeBanner: false,
            theme: theme.themeData(
                WidgetsBinding.instance.platformDispatcher.platformBrightness),
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
              '/admin': (context) => const AdminShellScreen(),
              '/admin/refunds': (context) =>
                  const AdminRefundManagementScreen(),
            },
          );
        },
      ),
    );
  }
}
