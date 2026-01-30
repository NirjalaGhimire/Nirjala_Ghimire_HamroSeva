import 'package:flutter/material.dart';
import '../services/token_storage.dart';
import '../services/api_service.dart';

class SplashDecider extends StatefulWidget {
  const SplashDecider({super.key});

  @override
  State<SplashDecider> createState() => _SplashDeciderState();
}

class _SplashDeciderState extends State<SplashDecider> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final access = await TokenStorage.getAccessToken();

    // If token exists -> validate using /me then go to home_decider
    if (access != null) {
      try {
        await ApiService.me();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home_decider');
        return;
      } catch (_) {
        await TokenStorage.clear();
      }
    }

    // no token -> login
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
