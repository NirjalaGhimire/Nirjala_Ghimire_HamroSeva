import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/token_storage.dart';

class HomeDecider extends StatefulWidget {
  const HomeDecider({super.key});

  @override
  State<HomeDecider> createState() => _HomeDeciderState();
}

class _HomeDeciderState extends State<HomeDecider> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    try {
      final me = await ApiService.me();

      // ✅ adjust this key if your backend uses different name
      // common: "role" => "CUSTOMER"/"PROVIDER"
      final roleRaw = (me["role"] ?? "").toString().toUpperCase();

      if (!mounted) return;

      if (roleRaw.contains("PROVIDER")) {
        Navigator.pushReplacementNamed(context, '/provider_home');
      } else {
        Navigator.pushReplacementNamed(context, '/customer_home');
      }
    } catch (_) {
      await TokenStorage.clear();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
