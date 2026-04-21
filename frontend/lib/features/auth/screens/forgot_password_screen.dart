import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/verify_code_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Forgot password: username or email; OTP is sent to the linked email.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  bool _isLoading = false;
  final _contactController = TextEditingController();

  @override
  void dispose() {
    _contactController.dispose();
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
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.t(context, 'forgotYourPassword'),
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkGrey),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.t(context, 'forgotPasswordHint'),
                style: TextStyle(
                    fontSize: 14, color: AppTheme.darkGrey.withOpacity(0.8)),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _contactController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: AppStrings.t(context, 'usernameOrEmail'),
                  prefixIcon: const Icon(Icons.email),
                  filled: true,
                  fillColor: AppTheme.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _requestReset,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: AppShimmerLoader(
                              strokeWidth: 2, color: Colors.white))
                      : Text(AppStrings.t(context, 'resetPassword')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestReset() async {
    final contactValue = _contactController.text.trim();
    if (contactValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t(context, 'enterUsernameOrEmail'))),
      );
      return;
    }
    final isEmail = contactValue.contains('@');
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.requestPasswordReset(
        contactValue: contactValue,
        isEmail: isEmail,
      );
      if (!mounted) return;
      final msg = (data['message'] as String?)?.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg != null && msg.isNotEmpty
                ? msg
                : AppStrings.t(context, 'ifAccountExistsVerificationCodeSent'),
          ),
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerifyCodeScreen(
            contactValue: contactValue,
            isEmail: isEmail,
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
}
