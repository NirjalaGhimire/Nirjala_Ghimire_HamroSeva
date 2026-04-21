import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:image_picker/image_picker.dart';

class CustomerPersonalProfileScreen extends StatefulWidget {
  const CustomerPersonalProfileScreen({super.key});

  @override
  State<CustomerPersonalProfileScreen> createState() =>
      _CustomerPersonalProfileScreenState();
}

class _CustomerPersonalProfileScreenState
    extends State<CustomerPersonalProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  bool _uploadingImage = false;
  String _profileImageUrl = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getCurrentCustomerProfile();
      _applyProfile(data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _applyProfile(Map<String, dynamic> data) {
    if (!mounted) return;
    _fullName.text = (data['full_name'] ?? '').toString();
    _email.text = (data['email'] ?? '').toString();
    _phone.text = (data['phone'] ?? '').toString();
    _location.text = (data['location'] ?? '').toString();
    _profileImageUrl = (data['profile_image_url'] ?? '').toString().trim();
    setState(() => _loading = false);
    _syncTokenUser(data);
  }

  Future<void> _syncTokenUser(Map<String, dynamic> profile) async {
    final saved = await TokenStorage.getSavedUser() ?? <String, dynamic>{};
    final merged = <String, dynamic>{
      ...saved,
      'username': (profile['full_name'] ?? saved['username'] ?? '').toString(),
      'email': (profile['email'] ?? saved['email'] ?? '').toString(),
      'phone': (profile['phone'] ?? saved['phone'] ?? '').toString(),
      'profile_image_url': (profile['profile_image_url'] ?? saved['profile_image_url'] ?? '')
          .toString(),
      'location': (profile['location'] ?? saved['location'] ?? '').toString(),
    };
    await TokenStorage.saveUser(merged);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await ApiService.updateCurrentCustomerProfile({
        'full_name': _fullName.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'location': _location.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _saving = false;
        _profileImageUrl =
            (updated['profile_image_url'] ?? _profileImageUrl).toString();
      });
      await _syncTokenUser(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image upload is not supported on web yet.')),
      );
      return;
    }
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1200,
      );
      if (picked == null) return;
      if (!File(picked.path).existsSync()) return;
      setState(() => _uploadingImage = true);
      final data = await ApiService.uploadCustomerProfileImage(picked.path);
      if (!mounted) return;
      setState(() {
        _uploadingImage = false;
        _profileImageUrl = (data['profile_image_url'] ?? '').toString();
      });
      await _syncTokenUser(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Personal Information',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(
              child: AppShimmerLoader(color: AppTheme.customerPrimary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor:
                              AppTheme.customerPrimary.withValues(alpha: 0.12),
                            backgroundImage: _profileImageUrl.isNotEmpty
                                ? NetworkImage(_profileImageUrl)
                                : null,
                            child: _profileImageUrl.isEmpty
                                ? Text(
                                    _fullName.text.trim().isNotEmpty
                                        ? _fullName.text.trim()[0].toUpperCase()
                                        : 'C',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.customerPrimary,
                                    ),
                                  )
                                : null,
                          ),
                          if (_uploadingImage)
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black26,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: AppShimmerLoader(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Material(
                              color: AppTheme.customerPrimary,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _uploadingImage ? null : _pickAndUploadImage,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _fullName,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return 'Email is required';
                        final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(value);
                        return ok ? null : 'Enter a valid email';
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Phone number is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _location,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Location / address (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: _saving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.customerPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: AppShimmerLoader(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
