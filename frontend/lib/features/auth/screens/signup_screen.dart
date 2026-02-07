import 'package:flutter/material.dart';
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
        title: const Text(
          'Sign Up',
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
              const Text(
                'Join Hamro Sewa',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select how you want to use our platform',
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
                  label: const Text('Register as Customer'),
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
                  label: const Text('Register as Service Provider'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
