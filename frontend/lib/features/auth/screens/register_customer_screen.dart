import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/referral_link_service.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/registration_email_verification_screen.dart';

class RegisterCustomerScreen extends StatefulWidget {
  const RegisterCustomerScreen({super.key, this.initialReferralCode});

  final String? initialReferralCode;

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
  final _district = TextEditingController();
  final _city = TextEditingController();
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
    final prefill = widget.initialReferralCode?.trim().isNotEmpty == true
        ? widget.initialReferralCode!.trim()
        : ReferralLinkService.pendingReferralCode;
    if (prefill != null && prefill.isNotEmpty) {
      _referralCode.text = prefill.toUpperCase();
    }
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
    _district.dispose();
    _city.dispose();
    _referralCode.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_username.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _district.text.trim().isEmpty ||
        _city.text.trim().isEmpty ||
        _password.text.trim().isEmpty ||
        _passwordConfirm.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppStrings.t(context, 'fillAllRequiredFieldsDistrictCity'))),
      );
      return;
    }

    if (_password.text != _passwordConfirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t(context, 'passwordsDoNotMatch'))),
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
        district: _district.text.trim(),
        city: _city.text.trim(),
        password: _password.text,
        passwordConfirm: _passwordConfirm.text,
        referralCode: _referralCode.text.trim().isEmpty
            ? null
            : _referralCode.text.trim(),
      );

      if (mounted) {
        final cooldown = int.tryParse(
                (response['resend_cooldown_seconds'] ?? '').toString()) ??
            60;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RegistrationEmailVerificationScreen(
              email: _email.text.trim(),
              role: 'customer',
              initialCooldownSeconds: cooldown,
            ),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Verification code sent. Check your email to complete registration.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final String msg = e is TimeoutException
            ? AppStrings.t(context, 'connectionTimedOutRunBackend')
            : _cleanExceptionMessage(e,
                prefix: '${AppStrings.t(context, 'registrationFailed')}: ');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
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
        title: Text(AppStrings.t(context, 'customerRegistration')),
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
              Text(
                AppStrings.t(context, 'createCustomerAccount'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _username,
                decoration: InputDecoration(
                  labelText: '${AppStrings.t(context, 'username')} *',
                  border: OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: '${AppStrings.t(context, 'email')} *',
                  border: OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: AppStrings.t(context, 'phoneNumber'),
                  border: OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _district,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: '${AppStrings.t(context, 'district')} *',
                  hintText: AppStrings.t(context, 'districtHintKathmandu'),
                  border: OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.map_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _city,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: '${AppStrings.t(context, 'city')} *',
                  hintText: AppStrings.t(context, 'cityHintThamel'),
                  border: OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_city_outlined),
                ),
              ),
              const SizedBox(height: 16),
              _providersLoading
                  ? ListTile(
                      title: Text(AppStrings.t(context, 'loadingProviders')))
                  : DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _selectedProviderId,
                      decoration: InputDecoration(
                        labelText:
                            AppStrings.t(context, 'preferredProviderOptional'),
                        border: OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person_search),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: null,
                            child: Text(AppStrings.t(context, 'none'))),
                        ..._providers.where((p) {
                          final id = p['id'];
                          return id != null &&
                              (id is int ||
                                  int.tryParse(id.toString()) != null);
                        }).map<DropdownMenuItem<int>>((p) {
                          final id = p['id'] is int
                              ? p['id'] as int
                              : int.tryParse(p['id'].toString())!;
                          final name = (p['username'] ?? '').toString();
                          final prof =
                              (p['profession'] ?? '').toString().trim();
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(
                              prof.isEmpty ? name : '$name ($prof)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (v) => setState(() => _selectedProviderId = v),
                    ),
              const SizedBox(height: 16),
              TextField(
                controller: _referralCode,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: AppStrings.t(context, 'referralCodeOptional'),
                  hintText: AppStrings.t(context, 'referralCodeHint'),
                  border: OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.card_giftcard),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.t(context, 'referralCodeHelpText'),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: '${AppStrings.t(context, 'password')} *',
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
                  labelText: '${AppStrings.t(context, 'confirmPassword')} *',
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
                      ? const AppShimmerLoader(color: Colors.white)
                      : Text(
                          AppStrings.t(context, 'register'),
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  AppStrings.t(context, 'alreadyHaveAccountLogin'),
                  style: TextStyle(
                      color: _CustomerSignupPrimary,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
