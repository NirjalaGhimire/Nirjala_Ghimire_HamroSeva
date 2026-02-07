import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';

class CreatePasswordSuccessScreen extends StatelessWidget {
  const CreatePasswordSuccessScreen({super.key});

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
                'Create New Password',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
              ),
              const SizedBox(height: 8),
              Text(
                'Create your new password to login',
                style: TextStyle(fontSize: 14, color: AppTheme.darkGrey.withOpacity(0.8)),
              ),
              const SizedBox(height: 48),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppTheme.darkGrey.withOpacity(0.1),
                        child: const Icon(Icons.check, size: 48, color: AppTheme.darkGrey),
                      ),
                      const SizedBox(height: 24),
                      const Text('Success', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
                      const SizedBox(height: 8),
                      Text(
                        'You have successfully reset your password.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppTheme.darkGrey.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const LoginPrototypeScreen()),
                            (route) => false,
                          ),
                          child: const Text('Login'),
                        ),
                      ),
                    ],
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
