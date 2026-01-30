import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RegisterProviderScreen extends StatefulWidget {
  const RegisterProviderScreen({super.key});

  @override
  State<RegisterProviderScreen> createState() => _RegisterProviderScreenState();
}

class _RegisterProviderScreenState extends State<RegisterProviderScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  // ✅ 6 professions (matches backend choices)
  final List<Map<String, String>> _professions = const [
    {"key": "CARPENTER", "label": "Carpenter"},
    {"key": "ELECTRICIAN", "label": "Electrician"},
    {"key": "HOUSE_CLEANING", "label": "House Cleaning"},
    {"key": "PAINTER", "label": "Painter"},
    {"key": "PLUMBER", "label": "Plumber"},
    {"key": "HAIR_STYLIST", "label": "Hair Stylist"},
  ];

  String? _selectedProfession = "CARPENTER";

  String? _validate() {
    final u = _username.text.trim();
    final e = _email.text.trim();
    final p = _phone.text.trim();
    final pw = _password.text.trim();

    if (u.isEmpty) return "Username is required";
    if (e.isEmpty || !e.contains("@")) return "Enter a valid email";
    if (p.isEmpty || p.length < 7) return "Enter a valid phone number";
    if (pw.length < 6) return "Password must be at least 6 characters";
    if (_selectedProfession == null || _selectedProfession!.isEmpty) {
      return "Please select a profession";
    }
    return null;
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _loading = true);

    try {
      await ApiService.registerProvider(
        username: _username.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text.trim(),
        profession: _selectedProfession!, // ✅ send to backend
      );

      // verify token works
      await ApiService.me();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/home_decider");
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registration failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Provider")),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  const Icon(Icons.work_outline, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    "Become a Service Provider",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Create a provider account to offer services",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 28),

                  // Username
                  TextField(
                    controller: _username,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(label: "Username", icon: Icons.person),
                  ),
                  const SizedBox(height: 14),

                  // Email
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(label: "Email", icon: Icons.email),
                  ),
                  const SizedBox(height: 14),

                  // Phone
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(label: "Phone", icon: Icons.phone),
                  ),
                  const SizedBox(height: 14),

                  // Profession dropdown ✅
                  DropdownButtonFormField<String>(
                    value: _selectedProfession,
                    decoration: _decoration(label: "Profession", icon: Icons.badge),
                    items: _professions
                        .map(
                          (p) => DropdownMenuItem<String>(
                            value: p["key"],
                            child: Text(p["label"]!),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedProfession = val),
                  ),
                  const SizedBox(height: 14),

                  // Password
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    onSubmitted: (_) => _loading ? null : _register(),
                    decoration: _decoration(
                      label: "Password",
                      icon: Icons.lock,
                      suffix: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Register button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_loading ? "Creating..." : "Register Provider"),
                    ),
                  ),

                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Back"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
