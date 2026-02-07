import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';

/// Provider registration: category from seva_servicecategory, then subcategory from seva_service.
class RegisterProviderScreen extends StatefulWidget {
  const RegisterProviderScreen({super.key});

  @override
  State<RegisterProviderScreen> createState() => _RegisterProviderScreenState();
}

/// Dark blue-grey for app bar and buttons; subtle buttery yellow for background.
const Color _ProviderSignupPrimary = Color(0xFF383A54);
const Color _ProviderSignupBackground = Color(0xFFFFF9E6); // very light buttery yellow

class _RegisterProviderScreenState extends State<RegisterProviderScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _profession = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  List<dynamic> _categories = [];
  List<dynamic> _subcategories = [];
  bool _categoriesLoading = true;
  bool _subcategoriesLoading = false;
  String? _selectedCategoryId;
  String? _selectedSubcategoryTitle;
  bool _useOtherProfession = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _categoriesLoading = true);
    try {
      final list = await ApiService.getCategories();
      if (mounted) {
        setState(() {
        _categories = list;
        _categoriesLoading = false;
      });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
        _categories = [];
        _categoriesLoading = false;
      });
      }
    }
  }

  Future<void> _onCategoryChanged(String? categoryId) async {
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedSubcategoryTitle = null;
      _subcategories = [];
    });
    if (categoryId == null || categoryId.isEmpty) return;
    setState(() => _subcategoriesLoading = true);
    try {
      final list = await ApiService.getServicesByCategory(categoryId, forSignup: true);
      if (!mounted) {
        if (mounted) setState(() { _subcategories = []; _subcategoriesLoading = false; });
        return;
      }
      final titles = <String>{};
      final out = <Map<String, dynamic>>[];
      for (final s in list) {
        final t = (s['title'] ?? '').toString().trim();
        if (t.isNotEmpty && !titles.contains(t)) {
          titles.add(t);
          out.add({'title': t, 'id': s['id']});
        }
      }
      if (mounted) {
        setState(() {
        _subcategories = out;
        _subcategoriesLoading = false;
      });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
        _subcategories = [];
        _subcategoriesLoading = false;
      });
      }
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _profession.dispose();
    super.dispose();
  }

  String _getProfessionForSubmit() {
    if (_useOtherProfession) return _profession.text.trim();
    return _selectedSubcategoryTitle ?? _profession.text.trim();
  }

  Future<void> _register() async {
    final profession = _getProfessionForSubmit();
    if (_username.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.trim().isEmpty ||
        _passwordConfirm.text.trim().isEmpty ||
        profession.isEmpty) {
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

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.registerProvider(
        username: _username.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
        passwordConfirm: _passwordConfirm.text,
        profession: profession,
      );

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
      if (mounted) setState(() => _isLoading = false);
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
      backgroundColor: _ProviderSignupBackground,
      appBar: AppBar(
        title: const Text('Provider Registration'),
        backgroundColor: _ProviderSignupPrimary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Icon(Icons.work, size: 80, color: _ProviderSignupPrimary),
              const SizedBox(height: 20),
              const Text(
                'Create Provider Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
              _categoriesLoading
                  ? const ListTile(title: Text('Loading categories...'))
                  : DropdownButtonFormField<String>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: "Select category * (from database)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Select category')),
                        ..._categories.map<DropdownMenuItem<String>>((c) {
                          final id = c['id']?.toString();
                          final name = (c['name'] ?? 'Category').toString();
                          return DropdownMenuItem(value: id, child: Text(name));
                        }),
                      ],
                      onChanged: (v) => _onCategoryChanged(v),
                    ),
              const SizedBox(height: 16),
              if (_selectedCategoryId != null) ...[
                _subcategoriesLoading
                    ? const ListTile(title: Text('Loading subcategories...'))
                    : DropdownButtonFormField<String>(
                        initialValue: _useOtherProfession ? '__other__' : _selectedSubcategoryTitle,
                        decoration: const InputDecoration(
                          labelText: "Select profession / subcategory * (from database)",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.work),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Select profession')),
                          ..._subcategories.map<DropdownMenuItem<String>>((s) {
                            final title = (s['title'] ?? '').toString();
                            return DropdownMenuItem(value: title, child: Text(title));
                          }),
                          const DropdownMenuItem(value: '__other__', child: Text('Other (type below)')),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _useOtherProfession = (v == '__other__');
                            _selectedSubcategoryTitle = (v == null || v == '__other__') ? null : v;
                          });
                        },
                      ),
                if (_useOtherProfession) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _profession,
                    decoration: const InputDecoration(
                      labelText: "Your profession *",
                      border: OutlineInputBorder(),
                      hintText: "e.g., Plumber, Electrician",
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password *",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ProviderSignupPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Register', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Already have an account? Login', style: TextStyle(color: _ProviderSignupPrimary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
