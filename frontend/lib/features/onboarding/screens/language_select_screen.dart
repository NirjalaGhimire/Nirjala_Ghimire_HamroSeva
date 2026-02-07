import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/locale/locale_notifier.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

/// Onboarding-2: Select your language, then Confirm -> Login.
class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  static const String _en = 'English';
  static const String _ne = 'नेपाली';

  String _selected = _en;

  String get _selectedCode => _selected == _ne ? 'ne' : 'en';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightLavender,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 80),
              const Icon(Icons.language, size: 80, color: AppTheme.darkGrey),
              const SizedBox(height: 48),
              Text(
                AppStrings.t(context, 'selectYourLanguage'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selected,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    items: [_en, _ne].map((s) {
                      return DropdownMenuItem(value: s, child: Text(s));
                    }).toList(),
                    onChanged: (v) => setState(() => _selected = v ?? _en),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final notifier = context.read<LocaleNotifier>();
                    await notifier.setLocale(_selectedCode == 'ne'
                        ? const Locale('ne')
                        : const Locale('en'));
                    await TokenStorage.setOnboardingSeen(true);
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginPrototypeScreen()),
                    );
                  },
                  child: Text(AppStrings.t(context, 'confirm')),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
