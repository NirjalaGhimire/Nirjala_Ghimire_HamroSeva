import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/role_select_screen.dart';
import 'package:hamro_sewa_frontend/features/dashboard/screens/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_username.text.trim().isEmpty || _password.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.login(
        username: _username.text.trim(),
        password: _password.text,
      );

      // Save tokens and user (role, email, etc.) so dashboard shows correct role
      await TokenStorage.saveTokens(
        accessToken: response['tokens']['access'],
        refreshToken: response['tokens']['refresh'],
      );
      if (response['user'] != null) {
        await TokenStorage.saveUser(Map<String, dynamic>.from(response['user'] as Map));
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        final String msg = e is TimeoutException
            ? 'Connection timed out. Is the backend running? Run: python manage.py runserver 0.0.0.0:8000'
            : 'Login failed: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.home_repair_service,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome Back!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: "Username or Email",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: "Password",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Login',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RoleSelectScreen(),
                  ),
                );
              },
              child: Text(
                "Don't have an account? Register",
                style: TextStyle(color: Colors.blue[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
