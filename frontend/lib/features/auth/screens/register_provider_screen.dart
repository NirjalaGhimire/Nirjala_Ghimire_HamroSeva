import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/utils/service_name_utils.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/registration_email_verification_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Provider registration: category from seva_servicecategory, then subcategory from seva_service.
class RegisterProviderScreen extends StatefulWidget {
  const RegisterProviderScreen({super.key});

  @override
  State<RegisterProviderScreen> createState() => _RegisterProviderScreenState();
}

/// Dark blue-grey for app bar and buttons; subtle buttery yellow for background.
const Color _ProviderSignupPrimary = Color(0xFF383A54);
const Color _ProviderSignupBackground =
    Color(0xFFFFF9E6); // very light buttery yellow

class _RegisterProviderScreenState extends State<RegisterProviderScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _district = TextEditingController();
  final _city = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _profession = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _idDocumentType = 'citizenship_card';
  String? _idDocumentPath;
  String? _certificationPath;
  String? _additionalDocumentPath;

  List<dynamic> _categories = [];
  List<dynamic> _subcategories = [];
  bool _categoriesLoading = true;
  bool _subcategoriesLoading = false;
  String? _selectedCategoryId;
  String? _selectedSubcategoryTitle;

  /// Multi-select service titles (same category) — synced to backend as services_offered.
  final Set<String> _selectedTitles = {};
  bool _useOtherProfession = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _categoriesLoading = true);
    try {
      final list = await ApiService.getCategories();
      if (mounted) {
        setState(() {
          _categories = list;
          _categoriesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _categories = [];
          _categoriesLoading = false;
        });
      }
    }
  }

  Future<void> _onCategoryChanged(String? categoryId) async {
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedSubcategoryTitle = null;
      _selectedTitles.clear();
      _subcategories = [];
    });
    if (categoryId == null || categoryId.isEmpty) return;
    setState(() => _subcategoriesLoading = true);
    try {
      final list =
          await ApiService.getServicesByCategory(categoryId, forSignup: true);
      if (!mounted) return;
      final out = dedupeCatalogRows(list);
      if (mounted) {
        setState(() {
          _subcategories = out;
          _subcategoriesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _subcategories = [];
          _subcategoriesLoading = false;
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
    _password.dispose();
    _passwordConfirm.dispose();
    _profession.dispose();
    super.dispose();
  }

  String _getProfessionForSubmit() {
    if (_useOtherProfession) return _profession.text.trim();
    if (_selectedTitles.isNotEmpty) {
      return _selectedTitles.join(', ');
    }
    return _selectedSubcategoryTitle ?? _profession.text.trim();
  }

  Future<void> _register() async {
    final profession = _getProfessionForSubmit();
    if (_username.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _district.text.trim().isEmpty ||
        _city.text.trim().isEmpty ||
        _password.text.trim().isEmpty ||
        _passwordConfirm.text.trim().isEmpty ||
        profession.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please fill all required fields (including District and City)')),
      );
      return;
    }

    if (_password.text != _passwordConfirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final cid = int.tryParse(_selectedCategoryId ?? '');
      List<Map<String, dynamic>>? servicesOffered;
      if (cid != null && _selectedTitles.isNotEmpty && !_useOtherProfession) {
        servicesOffered = _selectedTitles
            .map((t) => <String, dynamic>{'category_id': cid, 'title': t})
            .toList();
      }

      final response = await ApiService.registerProvider(
        username: _username.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        district: _district.text.trim(),
        city: _city.text.trim(),
        idDocumentType: _idDocumentPath != null && _certificationPath != null
            ? _idDocumentType
            : null,
        idDocumentPath: _idDocumentPath,
        certificationFilePath: _certificationPath,
        additionalDocumentPath: _additionalDocumentPath,
        password: _password.text,
        passwordConfirm: _passwordConfirm.text,
        profession: profession,
        servicesOffered: servicesOffered,
      );

      if (mounted) {
        final cooldown = int.tryParse(
                (response['resend_cooldown_seconds'] ?? '').toString()) ??
            60;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RegistrationEmailVerificationScreen(
              email: _email.text.trim(),
              role: 'provider',
              initialCooldownSeconds: cooldown,
            ),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Verification code sent. Check your email to complete registration.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final String msg = e is TimeoutException
            ? 'Connection timed out. Is the backend running? Run: python manage.py runserver 0.0.0.0:8000'
            : _cleanExceptionMessage(e, prefix: 'Registration failed: ');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFile(void Function(String path) onPicked) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null || path.isEmpty) return;
      setState(() => onPicked(path));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File selection failed. Try again.')),
      );
    }
  }

  String _fileName(String? path) {
    if (path == null || path.isEmpty) return 'No file selected';
    final parts = path.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? path : parts.last;
  }

  String _cleanExceptionMessage(dynamic e, {String prefix = ''}) {
    final s = e.toString();
    final cleaned = s.replaceFirst(RegExp(r'^Exception:\s*'), '');
    return prefix.isEmpty ? cleaned : '$prefix$cleaned';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ProviderSignupBackground,
      appBar: AppBar(
        title: const Text('Provider Registration'),
        backgroundColor: _ProviderSignupPrimary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Icon(Icons.work, size: 80, color: _ProviderSignupPrimary),
              const SizedBox(height: 20),
              const Text(
                'Create Provider Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _username,
                decoration: const InputDecoration(
                  labelText: "Username *",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email *",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone Number",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _district,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: "District *",
                  hintText: "e.g. Kathmandu",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.map_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _city,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: "City *",
                  hintText: "e.g. Thamel",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
              ),
              const SizedBox(height: 16),
              _categoriesLoading
                  ? const ListTile(title: Text('Loading categories...'))
                  : DropdownButtonFormField<String>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: "Select category * (from database)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Select category')),
                        ..._categories.map<DropdownMenuItem<String>>((c) {
                          final id = c['id']?.toString();
                          final name = (c['name'] ?? 'Category').toString();
                          return DropdownMenuItem(value: id, child: Text(name));
                        }),
                      ],
                      onChanged: (v) => _onCategoryChanged(v),
                    ),
              const SizedBox(height: 16),
              if (_selectedCategoryId != null) ...[
                _subcategoriesLoading
                    ? const ListTile(title: Text('Loading subcategories...'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Services you offer * (select one or more)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              ..._subcategories.map((s) {
                                final title =
                                    (s['title'] ?? '').toString().trim();
                                if (title.isEmpty)
                                  return const SizedBox.shrink();
                                final sel = _selectedTitles.contains(title);
                                return FilterChip(
                                  label: Text(title),
                                  selected: sel,
                                  selectedColor:
                                      _ProviderSignupPrimary.withValues(
                                          alpha: 0.15),
                                  checkmarkColor: _ProviderSignupPrimary,
                                  onSelected: (v) {
                                    setState(() {
                                      if (v) {
                                        _selectedTitles.add(title);
                                        _useOtherProfession = false;
                                      } else {
                                        _selectedTitles.remove(title);
                                      }
                                    });
                                  },
                                );
                              }),
                              FilterChip(
                                label: const Text('Other (type below)'),
                                selected: _useOtherProfession,
                                onSelected: (v) {
                                  setState(() {
                                    _useOtherProfession = v;
                                    if (v) _selectedTitles.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                if (_useOtherProfession) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _profession,
                    decoration: const InputDecoration(
                      labelText: "Your profession / service *",
                      border: OutlineInputBorder(),
                      hintText: "e.g., Plumber, Electrician",
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password *",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verification Documents (optional)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _idDocumentType,
                      decoration: const InputDecoration(
                        labelText: 'Identity document type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'national_id',
                            child: Text('National ID card')),
                        DropdownMenuItem(
                            value: 'citizenship_card',
                            child: Text('Citizenship card')),
                        DropdownMenuItem(
                            value: 'passport', child: Text('Passport')),
                      ],
                      onChanged: (v) => setState(
                          () => _idDocumentType = v ?? 'citizenship_card'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _pickFile((p) => _idDocumentPath = p),
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('Upload identity document'),
                    ),
                    Text(
                      _fileName(_idDocumentPath),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _pickFile((p) => _certificationPath = p),
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: const Text('Upload service certificate'),
                    ),
                    Text(
                      _fileName(_certificationPath),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _pickFile((p) => _additionalDocumentPath = p),
                      icon: const Icon(Icons.attach_file),
                      label:
                          const Text('Upload additional document (optional)'),
                    ),
                    Text(
                      _fileName(_additionalDocumentPath),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordConfirm,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: "Confirm Password *",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () => setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ProviderSignupPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const AppShimmerLoader(color: Colors.white)
                      : const Text('Register', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Already have an account? Login',
                    style: TextStyle(
                        color: _ProviderSignupPrimary,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
