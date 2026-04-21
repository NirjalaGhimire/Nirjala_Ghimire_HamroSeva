import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/create_new_password_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// OTP step after forgot password (username or email).
class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({
    super.key,
    required this.contactValue,
    required this.isEmail,
  });

  final String contactValue;
  final bool isEmail;

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _isLoading = false;
  bool _resending = false;
  Timer? _cooldownTimer;

  /// Seconds until resend allowed (aligned with server cooldown).
  int _resendSecondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _startResendCooldown(60);
  }

  void _startResendCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _resendSecondsLeft = seconds);
    if (seconds <= 0) return;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendSecondsLeft <= 1) {
        t.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  String get _maskedEmail {
    final e = widget.contactValue.trim();
    if (e.length <= 5) return e;
    final at = e.indexOf('@');
    if (at <= 1) return '${e.substring(0, 2)}***';
    return '${e.substring(0, 2)}***${e.substring(at)}';
  }

  Future<void> _verify() async {
    if (_code.length != 4) return;
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.verifyResetCode(
        contactValue: widget.contactValue,
        isEmail: widget.isEmail,
        code: _code,
      );
      final token = data['reset_token'] as String?;
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppStrings.t(context, 'invalidResponseTryAgain'))));
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CreateNewPasswordScreen(resetToken: token),
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

  Future<void> _resend() async {
    if (_resendSecondsLeft > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      await ApiService.requestPasswordReset(
        contactValue: widget.contactValue,
        isEmail: widget.isEmail,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppStrings.t(context, 'ifAccountExistsNewCodeSent'))),
      );
      _startResendCooldown(60);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (msg.toLowerCase().contains('wait') ||
          msg.toLowerCase().contains('many')) {
        _startResendCooldown(60);
      }
    } finally {
      if (mounted) setState(() => _resending = false);
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
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.t(context, 'enterVerificationCode'),
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkGrey),
              ),
              const SizedBox(height: 8),
              Text(
                '${AppStrings.t(context, 'enterCodeSentTo')} $_maskedEmail',
                style: TextStyle(
                    fontSize: 14, color: AppTheme.darkGrey.withOpacity(0.8)),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (i) {
                  return SizedBox(
                    width: 56,
                    child: TextField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: AppTheme.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (v) {
                        if (v.isNotEmpty && i < 3)
                          _focusNodes[i + 1].requestFocus();
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (_code.length == 4 && !_isLoading) ? _verify : null,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: AppShimmerLoader(
                              strokeWidth: 2, color: Colors.white))
                      : Text(AppStrings.t(context, 'verify')),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap:
                      (_resending || _resendSecondsLeft > 0) ? null : _resend,
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: AppTheme.darkGrey),
                      children: [
                        TextSpan(
                            text: AppStrings.t(
                                context, 'didntReceiveCodePrompt')),
                        TextSpan(
                          text: _resending
                              ? AppStrings.t(context, 'sending')
                              : (_resendSecondsLeft > 0
                                  ? '${AppStrings.t(context, 'resendIn')} ${_resendSecondsLeft}s'
                                  : AppStrings.t(context, 'resend')),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
