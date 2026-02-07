import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/create_new_password_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({super.key, required this.contact, required this.isEmail});

  final String contact;
  final bool isEmail;

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _isLoading = false;
  bool _resending = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length != 4) return;
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.verifyResetCode(
        contactValue: widget.contact,
        isEmail: widget.isEmail,
        code: _code,
      );
      final token = data['reset_token'] as String?;
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid response. Try again.')));
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
    setState(() => _resending = true);
    try {
      await ApiService.requestPasswordReset(
        email: widget.isEmail ? widget.contact : null,
        phone: widget.isEmail ? null : widget.contact,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code resent.')));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter Verification Code',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter code that we have sent to ${widget.contact.length > 5 ? "${widget.contact.substring(0, 5)}***" : widget.contact}',
                style: TextStyle(fontSize: 14, color: AppTheme.darkGrey.withOpacity(0.8)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (v) {
                        if (v.isNotEmpty && i < 3) _focusNodes[i + 1].requestFocus();
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_code.length == 4 && !_isLoading) ? _verify : null,
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verify'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: _resending ? null : _resend,
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: AppTheme.darkGrey),
                      children: [
                        const TextSpan(text: "Didn't receive the code? "),
                        TextSpan(
                          text: _resending ? 'Sending…' : 'Resend',
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
