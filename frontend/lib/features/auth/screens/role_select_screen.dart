import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/register_customer_screen.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/register_provider_screen.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Role'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_add,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'Join Hamro Sewa',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Select how you want to use our platform',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
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
                      builder: (context) => const RegisterCustomerScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.person),
                label: const Text(
                  'Register as Customer',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const RegisterProviderScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.work),
                label: const Text(
                  'Register as Service Provider',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Already have an account? Login',
                style: TextStyle(color: Colors.blue[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
