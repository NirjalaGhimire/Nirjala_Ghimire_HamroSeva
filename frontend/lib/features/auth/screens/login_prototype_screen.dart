import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hamro_sewa_frontend/core/config/google_web_client_id.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/forgot_password_screen.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/signup_screen.dart';
import 'package:hamro_sewa_frontend/features/admin/screens/admin_shell_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_shell_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_shell_screen.dart';

/// Login: HamroSeva logo, username/password, and Google sign-in.
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
      final user = Map<String, dynamic>.from(response['user'] as Map);
      final role = (user['role'] ?? 'customer').toString().toLowerCase();
      // Route based on role: admin → AdminShellScreen, provider → ProviderShellScreen, else → CustomerShellScreen
      Widget widget;
      if (role == 'admin' || role == 'admin_user') {
        widget = const AdminShellScreen();
      } else if (role == 'provider' || role == 'prov') {
        widget = const ProviderShellScreen();
      } else {
        widget = const CustomerShellScreen();
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => widget),
        (route) => false,
      );
    }
  }

  Future<void> _socialLogin(String provider, String token) async {
    setState(() => _isLoading = true);
    try {
      final response =
          await ApiService.socialLogin(provider: provider, token: token)
              .timeout(const Duration(seconds: 15));
      await TokenStorage.saveTokens(
        accessToken: response['tokens']['access'],
        refreshToken: response['tokens']['refresh'],
      );
      if (response['user'] != null) {
        await TokenStorage.saveUser(
            Map<String, dynamic>.from(response['user'] as Map));
      }
      if (mounted) _navigateAfterLogin(response);
    } catch (e) {
      if (mounted) {
        final String msg = e is TimeoutException
            ? ApiService.connectionTimeoutHint
            : _cleanExceptionMessage(e,
                prefix: '${AppStrings.t(context, 'socialLoginFailed')}: ');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    final webClientId = googleWebClientId;
    if (webClientId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppStrings.t(context, 'googleWebClientIdMissing')),
        ));
      }
      return;
    }

    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile', 'openid'],
        serverClientId: webClientId,
      );

      // Force the chooser each time by clearing any previous sign-in.
      // Otherwise Google may reuse the last signed-in account automatically.
      await googleSignIn.signOut();

      final account = await googleSignIn.signIn();
      if (account == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(AppStrings.t(context, 'googleSignInCancelled'))));
        }
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(AppStrings.t(context, 'couldNotGetGoogleToken'))));
        }
        return;
      }
      await _socialLogin('google', idToken);
    } catch (e) {
      if (mounted) {
        final msg = _socialErrorMessage(e);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  /// User-friendly message for Google Sign-In plugin and config errors.
  String _socialErrorMessage(dynamic e) {
    final context = this.context;
    const prefix = 'Google: ';
    final s = e.toString();
    if (s.contains('MissingPluginException')) {
      return AppStrings.t(context, 'socialLoginPluginNotSetUp');
    }
    if (s.contains('ApiException: 10') || s.contains('sign_in_failed')) {
      return AppStrings.t(context, 'googleAddSha1');
    }
    // Play Services reports NETWORK_ERROR for bad OAuth/SHA-1 in some cases too.
    if (s.contains('ApiException: 7') ||
        s.contains('network_error') ||
        s.contains('NETWORK_ERROR')) {
      return AppStrings.t(context, 'googleSignInNetworkOrOAuth');
    }
    return _cleanExceptionMessage(e, prefix: prefix);
  }

  /// Convert backend error messages to user-friendly frontend messages
  String _getUserFriendlyErrorMessage(String backendError) {
    final error = backendError.toLowerCase();

    // Backend error → User-friendly message mapping
    if (error.contains('no user found')) {
      return AppStrings.t(context, 'noUserFound') ??
          'No user found. Please check your username or email.';
    }
    if (error.contains('invalid password')) {
      return AppStrings.t(context, 'invalidPassword') ??
          'Invalid password. Please try again.';
    }
    if (error.contains('user account is disabled')) {
      return AppStrings.t(context, 'accountDisabled') ??
          'Your account has been disabled. Please contact support.';
    }
    if (error.contains('email is not verified')) {
      return 'Your email is not verified yet. Please complete email verification first.';
    }
    if (error.contains('username and password are required')) {
      return AppStrings.t(context, 'usernamePasswordRequired') ??
          'Username and password are required.';
    }

    // Default: return original error
    return backendError;
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppStrings.t(context, 'pleaseEnterCredentials'))));
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Backend accepts username, email, or phone in the same field
      final response =
          await ApiService.login(username: username, password: password)
              .timeout(const Duration(seconds: 15));
      await TokenStorage.saveTokens(
        accessToken: response['tokens']['access'],
        refreshToken: response['tokens']['refresh'],
      );
      if (response['user'] != null) {
        await TokenStorage.saveUser(
            Map<String, dynamic>.from(response['user'] as Map));
      }
      if (mounted) _navigateAfterLogin(response);
    } catch (e) {
      if (mounted) {
        String msg;
        if (e is TimeoutException) {
          msg = ApiService.connectionTimeoutHint;
        } else {
          // Extract error message from exception and convert to user-friendly message
          final errorStr = e.toString();
          final cleanError = _cleanExceptionMessage(e, prefix: '');
          msg = _getUserFriendlyErrorMessage(cleanError);
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand block: icon + name + tagline (grouped, centered)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppTheme.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.handshake,
                            size: 48,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppStrings.t(context, 'hamroSeva'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.t(context, 'tagline'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: AppTheme.darkGrey.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _usernameController,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: AppStrings.t(context, 'usernameHint'),
                        prefixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: AppTheme.white,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
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
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        filled: true,
                        fillColor: AppTheme.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        ),
                        child: Text(
                          AppStrings.t(context, 'forgetPassword'),
                          style: const TextStyle(
                            color: AppTheme.primaryButton,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryButton,
                          foregroundColor: AppTheme.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: AppShimmerLoader(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                AppStrings.t(context, 'login'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: AppTheme.darkGrey.withOpacity(0.25),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            AppStrings.t(context, 'orLoginWith'),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.darkGrey.withOpacity(0.75),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: AppTheme.darkGrey.withOpacity(0.25),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _socialButton(
                      label: AppStrings.t(context, 'google'),
                      color: Colors.white,
                      textColor: Colors.grey.shade800,
                      icon: Icons.g_mobiledata_rounded,
                      onTap: _isLoading ? null : _loginWithGoogle,
                      fullWidth: true,
                    ),
                    const SizedBox(height: 28),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SignupScreen(),
                        ),
                      ),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            color: AppTheme.darkGrey,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text: AppStrings.t(context, 'dontHaveAccount'),
                            ),
                            TextSpan(
                              text: AppStrings.t(context, 'signUp'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
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
    bool fullWidth = false,
  }) {
    final useWhiteIcon = color.computeLuminance() < 0.4;
    final isLight = color.computeLuminance() > 0.6;
    final row = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment:
          fullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Icon(
          icon,
          color:
              textColor ?? (useWhiteIcon ? AppTheme.white : AppTheme.darkGrey),
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: textColor ??
                (useWhiteIcon ? AppTheme.white : AppTheme.darkGrey),
          ),
        ),
      ],
    );
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: row,
    );
    if (fullWidth) {
      content = SizedBox(width: double.infinity, child: content);
    }
    return Material(
      color: color,
      elevation: 1,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            isLight ? BorderSide(color: Colors.grey.shade300) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AbsorbPointer(
          absorbing: onTap == null,
          child: content,
        ),
      ),
    );
  }
}
