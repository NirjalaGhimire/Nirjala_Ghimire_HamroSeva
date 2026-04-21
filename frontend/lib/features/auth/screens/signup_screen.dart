import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/register_customer_screen.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/register_provider_screen.dart';

/// Sign Up entry: navigates to role selection (Customer / Service Provider).
class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightLavender,
      appBar: AppBar(
        title: Text(
          AppStrings.t(context, 'signUp'),
          style: TextStyle(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_add,
                size: 80,
                color: AppTheme.darkGrey,
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.t(context, 'joinHamroSewa'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.t(context, 'selectHowToUsePlatform'),
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.darkGrey.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RegisterCustomerScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person),
                  label: Text(AppStrings.t(context, 'registerAsCustomer')),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RegisterProviderScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.work),
                  label:
                      Text(AppStrings.t(context, 'registerAsServiceProvider')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
