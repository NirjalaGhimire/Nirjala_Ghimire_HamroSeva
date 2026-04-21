import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

/// My Profile: allows users to view and update their name/email/phone.
///
/// This screen loads the currently-saved profile from TokenStorage and
/// also fetches latest profile data from the backend when possible.
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _editMode = false;
  Map<String, dynamic>? _profile;

  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getUserProfile();
      if (!mounted) return;
      _setProfile(data);
    } catch (_) {
      final saved = await TokenStorage.getSavedUser();
      if (mounted) _setProfile(saved);
    }
  }

  void _setProfile(Map<String, dynamic>? data) {
    setState(() {
      _profile = data ?? {};
      _loading = false;
      _username.text = (_profile?['username'] ?? '').toString();
      _email.text = (_profile?['email'] ?? '').toString();
      _phone.text = (_profile?['phone'] ?? '').toString();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await ApiService.updateProfile({
        'username': _username.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      });
      await TokenStorage.saveUser(Map<String, dynamic>.from(updated));
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _editMode = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t(context, 'profileUpdated'))));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        title: Text(AppStrings.t(context, 'myProfile'),
            style: const TextStyle(
                color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
        actions: [
          if (!_loading && !_editMode)
            TextButton(
              onPressed: () => setState(() => _editMode = true),
              child: Text(AppStrings.t(context, 'edit'),
                  style: TextStyle(
                      color: AppTheme.white, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: AppShimmerLoader(color: AppTheme.darkGrey))
          : _profile == null
              ? Center(
                  child: Text(AppStrings.t(context, 'couldNotLoadProfile')))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: AppTheme.darkGrey.withOpacity(0.2),
                          child: Text(
                            (_profile?['username'] as String? ??
                                    _profile?['email'] as String? ??
                                    ' ')[0]
                                .toUpperCase(),
                            style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkGrey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(AppStrings.t(context, 'accountInformation'),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkGrey)),
                      const SizedBox(height: 12),
                      if (_editMode) ...[
                        TextField(
                          controller: _username,
                          decoration: InputDecoration(
                              labelText: AppStrings.t(context, 'name'),
                              border: const OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                              labelText: AppStrings.t(context, 'email'),
                              border: const OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                              labelText: AppStrings.t(context, 'phone'),
                              border: const OutlineInputBorder()),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.darkGrey,
                            foregroundColor: AppTheme.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: AppShimmerLoader(
                                      color: Colors.white, strokeWidth: 2))
                              : Text(AppStrings.t(context, 'save')),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() => _editMode = false),
                          child: Text(AppStrings.t(context, 'cancel')),
                        ),
                      ] else ...[
                        _infoCard(
                            context,
                            AppStrings.t(context, 'name'),
                            (_profile?['username'] ?? _profile?['email'] ?? '—')
                                .toString()),
                        _infoCard(context, AppStrings.t(context, 'email'),
                            (_profile?['email'] ?? '—').toString()),
                        _infoCard(
                          context,
                          AppStrings.t(context, 'phone'),
                          (_profile?['phone'] ?? '').toString().trim().isEmpty
                              ? '—'
                              : (_profile?['phone'] ?? '—').toString(),
                        ),
                        _infoCard(
                            context,
                            AppStrings.t(context, 'accountType'),
                            (_profile?['role'] ??
                                    AppStrings.t(context, 'customer'))
                                .toString()),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _infoCard(BuildContext context, String label, String value) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 100,
                child: Text(label,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500))),
          ],
        ),
      ),
    );
  }
}
