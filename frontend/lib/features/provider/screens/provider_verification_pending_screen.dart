import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_shell_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/verify_id_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

class ProviderVerificationPendingScreen extends StatefulWidget {
  const ProviderVerificationPendingScreen({super.key});

  @override
  State<ProviderVerificationPendingScreen> createState() =>
      _ProviderVerificationPendingScreenState();
}

class _ProviderVerificationPendingScreenState
    extends State<ProviderVerificationPendingScreen> {
  bool _loading = true;
  String _status = 'pending';
  String _reason = '';

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getProviderVerificationStatus();
      if (!mounted) return;
      final normalizedStatus =
          (data['verification_status'] ?? 'unverified').toString().toLowerCase();
      final isActiveProvider = data['is_active_provider'] == true;
      final saved = await TokenStorage.getSavedUser() ?? <String, dynamic>{};
      saved['verification_status'] = normalizedStatus;
      saved['is_active_provider'] = isActiveProvider;
      saved['rejection_reason'] = (data['rejection_reason'] ?? '').toString();
      saved['reviewed_at'] = data['reviewed_at'];
      saved['reviewed_by'] = data['reviewed_by'];
      saved['submitted_at'] = data['submitted_at'];
      await TokenStorage.saveUser(saved);
      if (normalizedStatus == 'approved' && isActiveProvider) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ProviderShellScreen()),
          (route) => false,
        );
        return;
      }
      setState(() {
        _status = normalizedStatus;
        _reason = (data['rejection_reason'] ?? '').toString();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String get _title {
    switch (_status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Verification Rejected';
      case 'pending':
        return 'Pending Verification';
      case 'unverified':
        return 'Unverified';
      default:
        return 'Pending Verification';
    }
  }

  String get _message {
    switch (_status) {
      case 'rejected':
        return 'Your provider verification was rejected. Please update your documents and contact admin.';
      case 'pending':
        return 'Your verification documents are pending admin review.';
      case 'unverified':
        return 'You are currently unverified. You can still use your provider account and submit documents anytime.';
      case 'approved':
        return 'Your provider account is approved. Please re-login to continue.';
      default:
        return 'Your provider account is active and currently unverified.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Verification'),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const AppShimmerLoader(color: AppTheme.customerPrimary)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_outlined, size: 72, color: Colors.orange[700]),
                    const SizedBox(height: 14),
                    Text(
                      _title,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15),
                    ),
                    if (_reason.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Reason: $_reason',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red[700], fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      onPressed: _loadStatus,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Status'),
                    ),
                    if (_status == 'rejected' || _status == 'unverified') ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const VerifyIdScreen()))
                            .then((_) => _loadStatus()),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Re-upload Documents'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () async {
                        await TokenStorage.clearTokens();
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginPrototypeScreen()),
                          (route) => false,
                        );
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

