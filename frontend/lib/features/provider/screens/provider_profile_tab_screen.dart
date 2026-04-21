import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/help_desk_screen.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/about_screen.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/change_password_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/all_shops_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_notifications_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_personal_info_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_reviews_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_services_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_time_slots_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/shop_documents_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/verify_id_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/widgets/provider_app_bar.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/language_settings_screen.dart';
import 'package:hamro_sewa_frontend/features/profile/screens/theme_settings_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/delete_account_screen.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

/// Provider Profile: user card, core provider tools, settings, and account actions.
class ProviderProfileTabScreen extends StatefulWidget {
  const ProviderProfileTabScreen({super.key});

  @override
  State<ProviderProfileTabScreen> createState() =>
      _ProviderProfileTabScreenState();
}

class _ProviderProfileTabScreenState extends State<ProviderProfileTabScreen> {
  Map<String, dynamic>? _profile;
  List<dynamic> _services = [];
  bool _loading = true;
  String? _loadError;
  bool _uploadingAvatar = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final p = await ApiService.getUserProfile();
      final saved = await TokenStorage.getSavedUser() ?? <String, dynamic>{};
      final merged = <String, dynamic>{
        ...saved,
        ...Map<String, dynamic>.from(p),
      };
      final backendQualification = (p['qualification'] ?? '').toString().trim();
      if (backendQualification.isEmpty) {
        final savedQualification = (saved['qualification'] ?? '').toString().trim();
        if (savedQualification.isNotEmpty) {
          merged['qualification'] = savedQualification;
        }
      }
      await TokenStorage.saveUser(merged);
      final id = p['id'];
      final providerId = id is int ? id : int.tryParse(id?.toString() ?? '');
      List<dynamic> services = [];
      if (providerId != null) {
        services = await ApiService.getServicesForProvider(providerId);
      }
      if (mounted) {
        setState(() {
          _profile = merged;
          _services = services;
          _loading = false;
        });
      }
    } catch (e) {
      final fallback = await TokenStorage.getSavedUser();
      if (mounted) {
        setState(() {
          _profile = fallback;
          _loadError = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  String _fullName(Map<String, dynamic>? p) {
    if (p == null) return AppStrings.t(context, 'serviceProvider');
    final fn = (p['first_name'] as String?)?.trim() ?? '';
    final ln = (p['last_name'] as String?)?.trim() ?? '';
    final combined = '$fn $ln'.trim();
    if (combined.isNotEmpty) return combined;
    return (p['username'] as String?) ?? AppStrings.t(context, 'serviceProvider');
  }

  Future<void> _pickAndUploadAvatar() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t(context, 'profilePhotoUploadNotSupported'))),
      );
      return;
    }
    try {
      final x = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 88,
      );
      if (x == null) return;
      if (!File(x.path).existsSync()) return;
      setState(() => _uploadingAvatar = true);
      final updated = await ApiService.uploadProfileImage(x.path);
      await TokenStorage.saveUser(Map<String, dynamic>.from(updated));
      if (mounted) {
        setState(() {
          _profile = updated;
          _uploadingAvatar = false;
        });
        final w = updated['warning'] as String?;
        if (w != null && w.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(w)));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _editQualification() async {
    final ctrl = TextEditingController(
      text: (_profile?['qualification'] ?? '').toString(),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.t(context, 'qualification')),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: AppStrings.t(context, 'qualificationExampleHint'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.t(context, 'cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.customerPrimary,
              foregroundColor: AppTheme.white,
            ),
            child: Text(AppStrings.t(context, 'save')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final u = await ApiService.updateProfile({'qualification': ctrl.text.trim()});
      final saved = await TokenStorage.getSavedUser() ?? <String, dynamic>{};
      final merged = <String, dynamic>{
        ...saved,
        ...Map<String, dynamic>.from(u),
      };
      if ((merged['qualification'] ?? '').toString().trim().isEmpty &&
          ctrl.text.trim().isNotEmpty) {
        merged['qualification'] = ctrl.text.trim();
      }
      await TokenStorage.saveUser(merged);
      setState(() => _profile = merged);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t(context, 'qualificationSaved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _profile;
    final name = _fullName(user);
    final email = user?['email'] ?? AppStrings.t(context, 'unavailable');
    return Scaffold(
          backgroundColor: AppTheme.white,
          appBar: AppBar(
            title: Text(
              AppStrings.t(context, 'profile'),
              style:
                  TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppTheme.customerPrimary,
            foregroundColor: AppTheme.white,
            elevation: 0,
            shape: providerAppBarShape,
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ProviderNotificationsScreen()),
                ),
              ),
            ],
          ),
          body: _loading
              ? const Center(
                  child: AppShimmerLoader(color: AppTheme.customerPrimary),
                )
              : RefreshIndicator(
                  color: AppTheme.customerPrimary,
                  onRefresh: _refreshProfile,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_loadError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _loadError!,
                            style: TextStyle(color: Colors.orange[800], fontSize: 13),
                          ),
                        ),
                      _buildProfileHeader(name, email, user),
                      const SizedBox(height: 20),
                      _sectionHeader(AppStrings.t(context, 'generalSection')),
                        _tile(context, Icons.person_outline, AppStrings.t(context, 'personalInformation'),
                          onTap: () =>
                            _push(context, const ProviderPersonalInfoScreen())),
                        _tile(context, Icons.store, AppStrings.t(context, 'shop'),
                          onTap: () => _push(context, const AllShopsScreen())),
                        _tile(context, Icons.description, AppStrings.t(context, 'shopDocument'),
                          onTap: () => _push(context, const ShopDocumentsScreen())),
                        _tile(context, Icons.assignment, AppStrings.t(context, 'services'),
                          onTap: () => _push(context, const ProviderServicesScreen())),
                        _tile(context, Icons.schedule, AppStrings.t(context, 'timeSlots'),
                          onTap: () => _push(context, const ProviderTimeSlotsScreen())),
                        _tile(context, Icons.badge, AppStrings.t(context, 'verifyYourId'),
                          onTap: () => _push(context, const VerifyIdScreen())),
                        _tile(context, Icons.headset_mic_outlined, AppStrings.t(context, 'helpDesk'),
                          onTap: () => _push(context, const HelpDeskScreen())),
                        _tile(context, Icons.star_outline, AppStrings.t(context, 'ratingsAndReviews'),
                          onTap: () => _push(context, const ProviderReviewsScreen())),
              const SizedBox(height: 20),
              _sectionHeader(AppStrings.t(context, 'settingSection')),
              _tile(context, Icons.light_mode_outlined, AppStrings.t(context, 'appTheme'),
                  onTap: () => _push(context, const ThemeSettingsScreen())),
              _tile(context, Icons.language, AppStrings.t(context, 'language'),
                  onTap: () => _push(context, const LanguageSettingsScreen())),
              _tile(context, Icons.lock_outline, AppStrings.t(context, 'changePassword'),
                  onTap: () => _push(context, const ChangePasswordScreen())),
              _tile(context, Icons.info_outline, AppStrings.t(context, 'about'),
                  onTap: () => _push(context, const AboutScreen())),
              const SizedBox(height: 20),
              _sectionHeader(AppStrings.t(context, 'dangerZoneSection'), color: Colors.red),
              _tile(context, Icons.delete_outline, AppStrings.t(context, 'deleteAccount'),
                  isDanger: true,
                  onTap: () => _push(context, const DeleteAccountScreen())),
              _tile(context, Icons.logout, AppStrings.t(context, 'logout'),
                  isDanger: true, onTap: () => _showLogoutDialog(context)),
              const SizedBox(height: 16),
              const Center(
                  child: Text('v1.0.0',
                      style: TextStyle(fontSize: 12, color: Colors.grey))),
              const SizedBox(height: 24),
                    ],
                  ),
                ),
        );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildProfileHeader(
    String name,
    String email,
    Map<String, dynamic>? user,
  ) {
    final profession = (user?['profession'] ?? '').toString().trim();
    final qualification = (user?['qualification'] ?? '').toString().trim();
    final imageUrl = (user?['profile_image_url'] ?? '').toString().trim();
    final verificationStatus =
        (user?['verification_status'] ?? 'unverified').toString().trim().toLowerCase();
    final rejectionReason = (user?['rejection_reason'] ?? '').toString().trim();

    final titles = <String>{};
    for (final s in _services) {
      if (s is Map) {
        final t = (s['title'] ?? '').toString().trim();
        if (t.isNotEmpty) titles.add(t);
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipOval(
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _avatarPlaceholder(name),
                            )
                          : _avatarPlaceholder(name),
                    ),
                    if (_uploadingAvatar)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: AppShimmerLoader(
                                strokeWidth: 2,
                                color: AppTheme.white,
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
                          onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.camera_alt, color: AppTheme.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppStrings.t(context, 'tapCameraToUpdatePhoto'),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _profileInfoRow(Icons.work_outline, AppStrings.t(context, 'profession'), profession.isEmpty ? AppStrings.t(context, 'unavailable') : profession),
            const SizedBox(height: 12),
            _verificationStatusRow(verificationStatus, rejectionReason),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _profileInfoRow(
                    Icons.school_outlined,
                    AppStrings.t(context, 'qualification'),
                    qualification.isEmpty ? AppStrings.t(context, 'notSetTapEditToAdd') : qualification,
                  ),
                ),
                IconButton(
                  onPressed: _editQualification,
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.customerPrimary),
                  tooltip: AppStrings.t(context, 'editQualification'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.t(context, 'offeredServices'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            if (titles.isEmpty)
              Text(
                AppStrings.t(context, 'noServicesLinkedYet'),
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: titles
                    .map(
                      (t) => Chip(
                        label: Text(t),
                        backgroundColor: AppTheme.customerPrimary.withValues(alpha: 0.12),
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _verificationStatusRow(String status, String reason) {
    String label;
    Color bg;
    Color fg;
    switch (status) {
      case 'approved':
        label = AppStrings.t(context, 'verified');
        bg = Colors.green.withValues(alpha: 0.14);
        fg = Colors.green.shade800;
        break;
      case 'rejected':
        label = AppStrings.t(context, 'unverified');
        bg = Colors.red.withValues(alpha: 0.12);
        fg = Colors.red.shade800;
        break;
      case 'pending':
        label = AppStrings.t(context, 'pendingVerification');
        bg = Colors.indigo.withValues(alpha: 0.12);
        fg = Colors.indigo.shade700;
        break;
      default:
        label = AppStrings.t(context, 'unverified');
        bg = Colors.blueGrey.withValues(alpha: 0.12);
        fg = Colors.blueGrey.shade800;
        break;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.verified_user_outlined, size: 20, color: AppTheme.customerPrimary),
            const SizedBox(width: 8),
            Text(
              AppStrings.t(context, 'verificationStatus'),
              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
              ),
            ),
          ],
        ),
        if (status == 'rejected' && reason.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 28),
            child: Text(
              '${AppStrings.t(context, 'reason')}: $reason',
              style: TextStyle(fontSize: 12, color: Colors.red[700]),
            ),
          ),
      ],
    );
  }

  Widget _avatarPlaceholder(String name) {
    return Container(
      width: 80,
      height: 80,
      color: AppTheme.customerPrimary.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : AppStrings.t(context, 'providerInitial'),
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppTheme.customerPrimary,
        ),
      ),
    );
  }

  Widget _profileInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.customerPrimary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, color: AppTheme.darkGrey, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color ?? AppTheme.customerPrimary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title, {
    String? trailing,
    bool isGreen = false,
    bool isDanger = false,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon,
            color: isDanger ? Colors.red : AppTheme.darkGrey, size: 22),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDanger ? Colors.red : AppTheme.darkGrey,
          ),
        ),
        trailing: trailing != null
            ? Text(trailing,
                style: TextStyle(
                    color: isGreen ? Colors.green : Colors.grey[600],
                    fontWeight: FontWeight.w600))
            : const Icon(Icons.chevron_right,
                color: AppTheme.darkGrey, size: 20),
        onTap: onTap ?? (isDanger && title == AppStrings.t(context, 'logout') ? null : () {}),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: AppTheme.customerPrimary,
              child: Icon(Icons.logout, color: AppTheme.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(AppStrings.t(context, 'comeBackSoon'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(AppStrings.t(context, 'confirmLogoutQuestion'),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await TokenStorage.clearTokens();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const LoginPrototypeScreen()),
                      (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.customerPrimary,
                  foregroundColor: AppTheme.white,
                ),
                child: Text(AppStrings.t(context, 'yesLogout')),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.t(context, 'cancel'),
                  style: TextStyle(color: AppTheme.linkRed)),
            ),
          ],
        ),
      ),
    );
  }
}
