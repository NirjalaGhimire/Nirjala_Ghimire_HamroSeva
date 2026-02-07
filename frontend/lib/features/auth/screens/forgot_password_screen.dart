import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/verify_code_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Forgot password: Email / Phone tabs, input, "Reset Password" button.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  bool _useEmail = true;
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
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
                'Forgot Your Password?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your email or your phone number, we will send you confirmation code.',
                style: TextStyle(fontSize: 14, color: AppTheme.darkGrey.withOpacity(0.8)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _segment('Email', _useEmail, () => setState(() => _useEmail = true)),
                  ),
                  Expanded(
                    child: _segment('Phone', !_useEmail, () => setState(() => _useEmail = false)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_useEmail)
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    suffixIcon: const Icon(Icons.check),
                    filled: true,
                    fillColor: AppTheme.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              else
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Phone Number',
                    prefixIcon: const Icon(Icons.phone),
                    filled: true,
                    fillColor: AppTheme.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _requestReset,
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Reset Password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestReset() async {
    final contact = _useEmail ? _emailController.text.trim() : _phoneController.text.trim();
    if (contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_useEmail ? 'Enter your email' : 'Enter your phone number')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.requestPasswordReset(
        email: _useEmail ? contact : null,
        phone: _useEmail ? null : contact,
      );
      if (!mounted) return;
      final code = data['code'] as String?;
      if (code != null && code.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dev: Your code is $code')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('If an account exists, a code has been sent.')),
        );
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerifyCodeScreen(
            contact: contact,
            isEmail: _useEmail,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.darkGrey.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: AppTheme.darkGrey,
          ),
        ),
      ),
    );
  }
}
