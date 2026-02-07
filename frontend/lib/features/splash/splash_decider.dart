import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_shell_screen.dart';
import 'package:hamro_sewa_frontend/features/dashboard/screens/dashboard_screen.dart';
import 'package:hamro_sewa_frontend/features/onboarding/screens/onboarding_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_shell_screen.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

class SplashDecider extends StatefulWidget {
  const SplashDecider({super.key});

  @override
  State<SplashDecider> createState() => _SplashDeciderState();
}

class _SplashDeciderState extends State<SplashDecider> {
  Widget? _target;

  @override
  void initState() {
    super.initState();
    _decideRoute();
  }

  Future<void> _decideRoute() async {
    final onboardingSeen = await TokenStorage.getOnboardingSeen();
    final token = await TokenStorage.getAccessToken();

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    Widget target;
    if (!onboardingSeen) {
      target = const OnboardingScreen();
    } else if (token != null && token.isNotEmpty) {
      final user = await TokenStorage.getSavedUser();
      final role = (user?['role'] ?? 'customer').toString().toLowerCase();
      if (role == 'admin') {
        target = const DashboardScreen();
      } else if (role == 'provider') {
        target = const ProviderShellScreen();
      } else {
        target = const CustomerShellScreen();
      }
    } else {
      target = const LoginPrototypeScreen();
    }
    setState(() => _target = target);
  }

  @override
  Widget build(BuildContext context) {
    if (_target != null) {
      return _target!;
    }
    return Scaffold(
      backgroundColor: AppTheme.darkGrey,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.home_repair_service,
              size: 80,
              color: AppTheme.white,
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.t(context, 'appTitle'),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppStrings.t(context, 'appTagline'),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
            ),
          ],
        ),
      ),
    );
  }
}
