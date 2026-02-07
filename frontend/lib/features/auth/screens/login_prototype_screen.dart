import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/forgot_password_screen.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/signup_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_shell_screen.dart';
import 'package:hamro_sewa_frontend/features/dashboard/screens/dashboard_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_shell_screen.dart';

/// Prototype login: HamroSeva logo, tagline, Phone Number, Password, Forget password, Login, Or login with, Facebook/Email icons.
class LoginPrototypeScreen extends StatefulWidget {
  const LoginPrototypeScreen({super.key});

  @override
  State<LoginPrototypeScreen> createState() => _LoginPrototypeScreenState();
}

class _LoginPrototypeScreenState extends State<LoginPrototypeScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _navigateAfterLogin(Map<String, dynamic> response) {
    if (response['user'] != null) {
      final role = (response['user'] as Map)['role']?.toString().toLowerCase() ?? 'customer';
      final Widget widget = role == 'admin'
          ? const DashboardScreen()
          : role == 'provider'
              ? const ProviderShellScreen()
              : const CustomerShellScreen();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => widget),
        (route) => false,
      );
    }
  }

  Future<void> _socialLogin(String provider, String token) async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.socialLogin(provider: provider, token: token)
          .timeout(const Duration(seconds: 15));
      await TokenStorage.saveTokens(
        accessToken: response['tokens']['access'],
        refreshToken: response['tokens']['refresh'],
      );
      if (response['user'] != null) {
        await TokenStorage.saveUser(Map<String, dynamic>.from(response['user'] as Map));
      }
      if (mounted) _navigateAfterLogin(response);
    } catch (e) {
      if (mounted) {
        final String msg = e is TimeoutException
            ? AppStrings.t(context, 'connectionTimeout')
            : _cleanExceptionMessage(e, prefix: '${AppStrings.t(context, 'socialLoginFailed')}: ');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login();
      if (result.status != LoginStatus.success) {
        if (mounted) {
          final msg = result.status == LoginStatus.cancelled
              ? AppStrings.t(context, 'facebookLoginCancelled')
              : AppStrings.t(context, 'facebookLoginFailed');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
        return;
      }
      final token = result.accessToken?.tokenString;
      if (token == null || token.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'couldNotGetFacebookToken'))));
        return;
      }
      await _socialLogin('facebook', token);
    } catch (e) {
      if (mounted) {
        final msg = _socialErrorMessage(e, isFacebook: true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final account = await googleSignIn.signIn();
      if (account == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'googleSignInCancelled'))));
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'couldNotGetGoogleToken'))));
        return;
      }
      await _socialLogin('google', idToken);
    } catch (e) {
      if (mounted) {
        final msg = _socialErrorMessage(e, isFacebook: false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  /// User-friendly message for Facebook/Google plugin and config errors.
  String _socialErrorMessage(dynamic e, {required bool isFacebook}) {
    final context = this.context;
    final prefix = isFacebook ? 'Facebook: ' : 'Google: ';
    final s = e.toString();
    if (s.contains('MissingPluginException')) {
      return AppStrings.t(context, 'facebookNotSetUp');
    }
    if (s.contains('ApiException: 10') || s.contains('sign_in_failed')) {
      return AppStrings.t(context, 'googleAddSha1');
    }
    return _cleanExceptionMessage(e, prefix: prefix);
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'pleaseEnterCredentials'))));
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Backend accepts username, email, or phone in the same field
      final response = await ApiService.login(username: username, password: password)
          .timeout(const Duration(seconds: 15));
      await TokenStorage.saveTokens(
        accessToken: response['tokens']['access'],
        refreshToken: response['tokens']['refresh'],
      );
      if (response['user'] != null) {
        await TokenStorage.saveUser(Map<String, dynamic>.from(response['user'] as Map));
      }
      if (mounted) _navigateAfterLogin(response);
    } catch (e) {
      if (mounted) {
        final String msg = e is TimeoutException
            ? AppStrings.t(context, 'connectionTimeout')
            : _cleanExceptionMessage(e, prefix: '${AppStrings.t(context, 'loginFailed')}: ');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightLavender,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              // Logo: white rounded square with handshake + 3 figures
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                ),
                child: const Icon(Icons.handshake, size: 48, color: AppTheme.darkGrey),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.t(context, 'hamroSeva'),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.t(context, 'tagline'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.darkGrey.withOpacity(0.8)),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen())),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: AppTheme.darkGrey, fontSize: 14),
                    children: [
                      TextSpan(text: AppStrings.t(context, 'dontHaveAccount')),
                      TextSpan(text: AppStrings.t(context, 'signUp'), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _usernameController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: AppStrings.t(context, 'usernameHint'),
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: AppTheme.white,
                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: AppStrings.t(context, 'password'),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: AppTheme.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                  child: Text(AppStrings.t(context, 'forgetPassword'), style: const TextStyle(color: AppTheme.linkRed)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(AppStrings.t(context, 'login')),
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: Divider(color: AppTheme.darkGrey.withOpacity(0.3))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(AppStrings.t(context, 'orLoginWith'), style: TextStyle(color: AppTheme.darkGrey.withOpacity(0.8)))),
                Expanded(child: Divider(color: AppTheme.darkGrey.withOpacity(0.3))),
              ]),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialButton(
                    label: AppStrings.t(context, 'facebook'),
                    color: const Color(0xFF1877F2),
                    icon: Icons.facebook,
                    onTap: _isLoading ? null : _loginWithFacebook,
                  ),
                  const SizedBox(width: 16),
                  _socialButton(
                    label: AppStrings.t(context, 'google'),
                    color: Colors.white,
                    textColor: Colors.grey.shade800,
                    icon: Icons.g_mobiledata_rounded,
                    onTap: _isLoading ? null : _loginWithGoogle,
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _cleanExceptionMessage(dynamic e, {String prefix = ''}) {
    final s = e.toString();
    final cleaned = s.replaceFirst(RegExp(r'^Exception:\s*'), '');
    return prefix.isEmpty ? cleaned : '$prefix$cleaned';
  }

  Widget _socialButton({
    required String label,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    final useWhiteIcon = color.computeLuminance() < 0.4;
    final isLight = color.computeLuminance() > 0.6;
    return Material(
      color: color,
      elevation: 1,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLight ? BorderSide(color: Colors.grey.shade300) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AbsorbPointer(
          absorbing: onTap == null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: textColor ?? (useWhiteIcon ? AppTheme.white : AppTheme.darkGrey), size: 24),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textColor ?? (useWhiteIcon ? AppTheme.white : AppTheme.darkGrey))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
