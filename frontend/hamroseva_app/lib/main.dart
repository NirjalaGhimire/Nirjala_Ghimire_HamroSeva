import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/register_customer_screen.dart';
import 'screens/register_provider_screen.dart';
import 'screens/role_select_screen.dart';
import 'screens/home_screen.dart';
import 'services/token_storage.dart';
import 'services/api_service.dart';

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

      // ✅ Keep SplashDecider as first screen
      home: const SplashDecider(),

      // ✅ Do NOT include '/' when home is used
      routes: {
        '/role_select': (_) => const RoleSelectScreen(),
        '/register_customer': (_) => const RegisterCustomerScreen(),
        '/register_provider': (_) => const RegisterProviderScreen(),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}

class SplashDecider extends StatefulWidget {
  const SplashDecider({super.key});

  @override
  State<SplashDecider> createState() => _SplashDeciderState();
}

class _SplashDeciderState extends State<SplashDecider> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final access = await TokenStorage.getAccessToken();

    if (access != null) {
      try {
        await ApiService.me(); // validates token (refresh if expired)
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
        return;
      } catch (_) {
        await TokenStorage.clear();
      }
    }

    if (!mounted) return;

    // ✅ Go to Login screen directly (no '/login' route needed)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
