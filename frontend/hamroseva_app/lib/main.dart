import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/role_select_screen.dart';
import 'screens/register_customer_screen.dart';
import 'screens/register_provider_screen.dart';

import 'screens/splash_decider.dart';
import 'screens/home_decider.dart';
import 'screens/customer_home_screen.dart';
import 'screens/provider_home_screen.dart';

void main() {
  runApp(const HamroSevaApp());
}

class HamroSevaApp extends StatelessWidget {
  const HamroSevaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HamroSeva',

      // ✅ Only ONE home
      home: const SplashDecider(),

      // ✅ No "/" route when using home:
      routes: {
        '/login': (_) => const LoginScreen(),
        '/role_select': (_) => const RoleSelectScreen(),
        '/register_customer': (_) => const RegisterCustomerScreen(),
        '/register_provider': (_) => const RegisterProviderScreen(),

        // decides provider vs customer home
        '/home_decider': (_) => const HomeDecider(),

        // direct homes (optional)
        '/customer_home': (_) => const CustomerHomeScreen(),
        '/provider_home': (_) => const ProviderHomeScreen(),
      },

      // ✅ avoid "Could not find a generator for route" crash
      onUnknownRoute: (_) => MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }
}
