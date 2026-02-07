import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';

class RegisterCustomerScreen extends StatefulWidget {
  const RegisterCustomerScreen({super.key});

  @override
  State<RegisterCustomerScreen> createState() => _RegisterCustomerScreenState();
}

/// Same theme as Provider Registration: dark blue-grey + light buttery yellow background.
const Color _CustomerSignupPrimary = Color(0xFF383A54);
const Color _CustomerSignupBackground = Color(0xFFFFF9E6);

class _RegisterCustomerScreenState extends State<RegisterCustomerScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _referralCode = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  List<dynamic> _providers = [];
  bool _providersLoading = true;
  int? _selectedProviderId; // optional preferred provider from database

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    try {
      final list = await ApiService.getProviders();
      if (mounted) {
        setState(() {
        _providers = list;
        _providersLoading = false;
      });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
        _providers = [];
        _providersLoading = false;
      });
      }
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _referralCode.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_username.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.trim().isEmpty ||
        _passwordConfirm.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (_password.text != _passwordConfirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.registerCustomer(
        username: _username.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
        passwordConfirm: _passwordConfirm.text,
        referralCode: _referralCode.text.trim().isEmpty ? null : _referralCode.text.trim(),
      );

      // Save tokens and user
      await TokenStorage.saveTokens(
        accessToken: response['tokens']['access'],
        refreshToken: response['tokens']['refresh'],
      );
      if (response['user'] != null) {
        await TokenStorage.saveUser(Map<String, dynamic>.from(response['user'] as Map));
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPrototypeScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful!')),
        );
      }
    } catch (e) {
      if (mounted) {
        final String msg = e is TimeoutException
            ? 'Connection timed out. Is the backend running? Run: python manage.py runserver 0.0.0.0:8000'
            : _cleanExceptionMessage(e, prefix: 'Registration failed: ');
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

  String _cleanExceptionMessage(dynamic e, {String prefix = ''}) {
    final s = e.toString();
    final cleaned = s.replaceFirst(RegExp(r'^Exception:\s*'), '');
    return prefix.isEmpty ? cleaned : '$prefix$cleaned';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _CustomerSignupBackground,
      appBar: AppBar(
        title: const Text('Customer Registration'),
        backgroundColor: _CustomerSignupPrimary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Icon(
                Icons.person,
                size: 80,
                color: _CustomerSignupPrimary,
              ),
              const SizedBox(height: 20),
              const Text(
                'Create Customer Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _username,
                decoration: const InputDecoration(
                  labelText: "Username *",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email *",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone Number",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),
              _providersLoading
                  ? const ListTile(title: Text('Loading providers...'))
                  : DropdownButtonFormField<int>(
                      initialValue: _selectedProviderId,
                      decoration: const InputDecoration(
                        labelText: "Preferred provider (optional)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_search),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        ..._providers.where((p) {
                          final id = p['id'];
                          return id != null && (id is int || int.tryParse(id.toString()) != null);
                        }).map<DropdownMenuItem<int>>((p) {
                          final id = p['id'] is int ? p['id'] as int : int.tryParse(p['id'].toString())!;
                          final name = (p['username'] ?? '').toString();
                          final prof = (p['profession'] ?? '').toString().trim();
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(prof.isEmpty ? name : '$name ($prof)'),
                          );
                        }),
                      ],
                      onChanged: (v) => setState(() => _selectedProviderId = v),
                    ),
              const SizedBox(height: 16),
              TextField(
                controller: _referralCode,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: "Referral code (optional)",
                  hintText: "e.g. HAMRO-NISHA-2026",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.card_giftcard),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Have a code from a friend? Enter it here – you\'ll both earn loyalty points when you book a service.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password *",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordConfirm,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: "Confirm Password *",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _CustomerSignupPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Register',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Already have an account? Login',
                  style: TextStyle(color: _CustomerSignupPrimary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
