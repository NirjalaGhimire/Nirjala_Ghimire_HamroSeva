import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/create_password_success_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

class CreateNewPasswordScreen extends StatefulWidget {
  const CreateNewPasswordScreen({super.key, required this.resetToken});

  final String resetToken;

  @override
  State<CreateNewPasswordScreen> createState() => _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ApiService.setNewPassword(
        resetToken: widget.resetToken,
        newPassword: password,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CreatePasswordSuccessScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightLavender,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.darkGrey,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create New Password',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
              ),
              const SizedBox(height: 8),
              Text(
                'Create your new password to login',
                style: TextStyle(fontSize: 14, color: AppTheme.darkGrey.withOpacity(0.8)),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _passwordController,
                obscureText: _obscure1,
                decoration: InputDecoration(
                  hintText: 'New password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                  filled: true,
                  fillColor: AppTheme.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmController,
                obscureText: _obscure2,
                decoration: InputDecoration(
                  hintText: 'Confirm password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                  filled: true,
                  fillColor: AppTheme.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
