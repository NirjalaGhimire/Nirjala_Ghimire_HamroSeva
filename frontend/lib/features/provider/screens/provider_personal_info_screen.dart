import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

/// Personal information: view mode with Edit button; edit mode with Save/Cancel.
class ProviderPersonalInfoScreen extends StatefulWidget {
  const ProviderPersonalInfoScreen({super.key});

  @override
  State<ProviderPersonalInfoScreen> createState() => _ProviderPersonalInfoScreenState();
}

class _ProviderPersonalInfoScreenState extends State<ProviderPersonalInfoScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _saving = false;
  bool _editMode = false;
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _profession = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _profession.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getUserProfile();
      if (mounted) {
        setState(() {
          _profile = Map<String, dynamic>.from(data);
          _loading = false;
          _username.text = (_profile!['username'] ?? '').toString();
          _email.text = (_profile!['email'] ?? '').toString();
          _phone.text = (_profile!['phone'] ?? '').toString();
          _profession.text = (_profile!['profession'] ?? '').toString();
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      final user = await TokenStorage.getSavedUser();
      if (mounted) {
        setState(() {
        _profile = user;
        _loading = false;
        _username.text = (_profile?['username'] ?? '').toString();
        _email.text = (_profile?['email'] ?? '').toString();
        _phone.text = (_profile?['phone'] ?? '').toString();
        _profession.text = (_profile?['profession'] ?? '').toString();
      });
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final data = await ApiService.updateProfile({
        'username': _username.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'profession': _profession.text.trim().isEmpty ? null : _profession.text.trim(),
      });
      await TokenStorage.saveUser(Map<String, dynamic>.from(data));
      if (mounted) {
        setState(() {
          _profile = data;
          _editMode = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
        } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Personal Information', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        actions: [
          if (!_editMode && _profile != null)
            TextButton(
              onPressed: () => setState(() => _editMode = true),
              child: const Text('Edit', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.customerPrimary))
          : _profile == null
              ? const Center(child: Text('Could not load profile'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _editMode
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _username,
                              decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _profession,
                              decoration: const InputDecoration(labelText: 'Profession', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _saving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.customerPrimary,
                                foregroundColor: AppTheme.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: _saving
                                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Save'),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => setState(() => _editMode = false),
                              child: const Text('Cancel'),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _row('Username', (_profile!['username'] ?? '—').toString()),
                            _row('Email', (_profile!['email'] ?? '—').toString()),
                            _row('Phone', (_profile!['phone'] ?? '').toString().isEmpty ? '—' : (_profile!['phone']).toString()),
                            _row('Profession', (_profile!['profession'] ?? '').toString().isEmpty ? '—' : (_profile!['profession']).toString()),
                            _row('Role', (_profile!['role'] ?? '—').toString()),
                          ],
                        ),
                ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
