import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

class RegistrationEmailVerificationScreen extends StatefulWidget {
  const RegistrationEmailVerificationScreen({
    super.key,
    required this.email,
    required this.role,
    this.initialCooldownSeconds = 60,
    this.codeLength = 6,
  });

  final String email;
  final String role;
  final int initialCooldownSeconds;
  final int codeLength;

  @override
  State<RegistrationEmailVerificationScreen> createState() =>
      _RegistrationEmailVerificationScreenState();
}

class _RegistrationEmailVerificationScreenState
    extends State<RegistrationEmailVerificationScreen> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _isVerifying = false;
  bool _isResending = false;
  int _secondsUntilResend = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _controllers =
        List.generate(widget.codeLength, (_) => TextEditingController());
    _focusNodes = List.generate(widget.codeLength, (_) => FocusNode());
    _startCooldown(widget.initialCooldownSeconds);
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

  String get _code => _controllers.map((e) => e.text.trim()).join();

  String get _maskedEmail {
    final email = widget.email.trim();
    final at = email.indexOf('@');
    if (at <= 1) return email;
    return '${email.substring(0, 2)}***${email.substring(at)}';
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _secondsUntilResend = seconds < 0 ? 0 : seconds);
    if (_secondsUntilResend <= 0) return;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsUntilResend <= 1) {
        timer.cancel();
        setState(() => _secondsUntilResend = 0);
      } else {
        setState(() => _secondsUntilResend--);
      }
    });
  }

  Future<void> _verify() async {
    if (_code.length != widget.codeLength || _isVerifying) return;
    setState(() => _isVerifying = true);
    try {
      await ApiService.verifyRegistrationOtp(
        email: widget.email,
        role: widget.role,
        code: _code,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Email verified and account created. Please log in.')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPrototypeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resend() async {
    if (_secondsUntilResend > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      final response = await ApiService.resendRegistrationOtp(
        email: widget.email,
        role: widget.role,
      );
      if (!mounted) return;
      final cooldown = int.tryParse(
              (response['resend_cooldown_seconds'] ?? '').toString()) ??
          60;
      _startCooldown(cooldown);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new verification code has been sent.')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      final match = RegExp(r'retry_after_seconds\D*(\d+)').firstMatch(message);
      if (match != null) {
        final seconds = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (seconds > 0) {
          _startCooldown(seconds);
        }
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel =
        widget.role.toLowerCase() == 'provider' ? 'Provider' : 'Customer';
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the 6-digit code sent to $_maskedEmail',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                '$roleLabel registration will complete only after verification.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(widget.codeLength, (i) {
                  return SizedBox(
                    width: 46,
                    child: TextField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      decoration: const InputDecoration(counterText: ''),
                      onChanged: (value) {
                        if (value.isNotEmpty && i < widget.codeLength - 1) {
                          _focusNodes[i + 1].requestFocus();
                        }
                        if (value.isEmpty && i > 0) {
                          _focusNodes[i - 1].requestFocus();
                        }
                        setState(() {});
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
                      (_code.length == widget.codeLength && !_isVerifying)
                          ? _verify
                          : null,
                  child: _isVerifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: AppShimmerLoader(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Verify and Create Account'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: (_isResending || _secondsUntilResend > 0)
                      ? null
                      : _resend,
                  child: Text(
                    _isResending
                        ? 'Sending...'
                        : _secondsUntilResend > 0
                            ? 'Resend code in ${_secondsUntilResend}s'
                            : 'Resend Code',
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
