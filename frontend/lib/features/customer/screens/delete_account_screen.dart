import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

/// Full UI: Delete Account – warning and confirm (no "coming soon").
class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'deleteAccount'),
            style:
                TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red,
        foregroundColor: AppTheme.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              AppStrings.t(context, 'thisActionCannotBeUndone'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.t(context, 'deleteAccountWarningText'),
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(AppStrings.t(context, 'beforeYouContinue'),
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _bullet(AppStrings.t(context, 'deleteAccountBullet1')),
            _bullet(AppStrings.t(context, 'deleteAccountBullet2')),
            _bullet(AppStrings.t(context, 'deleteAccountBullet3')),
            const SizedBox(height: 32),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => _showConfirmDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: AppTheme.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(AppStrings.t(context, 'deleteMyAccount')),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppStrings.t(context, 'cancel'),
                  style: TextStyle(color: AppTheme.customerPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
              child: Text(text, style: TextStyle(color: Colors.grey[700]))),
        ],
      ),
    );
  }

  void _showConfirmDialog(BuildContext context) {
    final passwordController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(AppStrings.t(context, 'confirmDeletion')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.t(context, 'enterPasswordToConfirmDeletion'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: AppStrings.t(context, 'password'),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: Text(AppStrings.t(context, 'cancel')),
              ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final password = passwordController.text.trim();
                        setState(() => isLoading = true);
                        try {
                          await ApiService.deleteAccount(password: password);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      '${AppStrings.t(context, 'unableToDeleteAccount')}: ${e.toString()}')),
                            );
                          }
                          setState(() => isLoading = false);
                          return;
                        }
                        if (context.mounted) {
                          Navigator.pop(ctx);
                        }
                        await TokenStorage.clearTokens();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const LoginPrototypeScreen()),
                            (route) => false,
                          );
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: AppShimmerLoader(strokeWidth: 2),
                      )
                    : Text(AppStrings.t(context, 'delete'),
                        style: const TextStyle(color: Colors.red)),
              ),
            ],
          );
        });
      },
    );
  }
}
