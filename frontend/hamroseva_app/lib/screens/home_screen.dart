import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _me;
  List<dynamic> _services = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final me = await ApiService.me(); // auto-refresh inside
      final services = await ApiService.listServices(); // auto-refresh inside

      if (!mounted) return;
      setState(() {
        _me = me;
        _services = services;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString();
      // If token missing/invalid -> send back to login
      if (msg.contains("No access token") ||
          msg.contains("token_not_valid") ||
          msg.contains("Authentication credentials were not provided")) {
        await ApiService.logout();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        return;
      }

      setState(() {
        _error = msg;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _requestService(int serviceId) async {
    try {
      await ApiService.createRequest(serviceId: serviceId, note: "");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Request sent successfully ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Request failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = (_me?["username"] ?? "").toString();
    final email = (_me?["email"] ?? "").toString();
    final role = (_me?["role"] ?? "").toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text("HamroSeva"),
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadAll,
          ),
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(
                    message: _error!,
                    onRetry: _loadAll,
                    onLogout: _logout,
                  )
                : RefreshIndicator(
                    onRefresh: _loadAll,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _ProfileCard(
                          username: username,
                          email: email,
                          role: role,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Available Services",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (_services.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 20),
                            child: Center(
                              child: Text("No services found."),
                            ),
                          )
                        else
                          ..._services.map((s) {
                            final id = s["id"] as int?;
                            final title =
                                (s["title"] ?? s["name"] ?? "Service")
                                    .toString();
                            final desc = (s["description"] ?? "").toString();

                            return _ServiceCard(
                              title: title,
                              description: desc,
                              onRequest: (id == null)
                                  ? null
                                  : () => _requestService(id),
                            );
                          }),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String username;
  final String email;
  final String role;

  const _ProfileCard({
    required this.username,
    required this.email,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              child: Text(
                (username.isNotEmpty ? username[0].toUpperCase() : "U"),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username.isEmpty ? "User" : username,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.black.withOpacity(0.05),
                    ),
                    child: Text(
                      role.isEmpty ? "UNKNOWN" : role,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onRequest;

  const _ServiceCard({
    required this.title,
    required this.description,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 38,
              child: OutlinedButton(
                onPressed: onRequest,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Request"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56),
              const SizedBox(height: 12),
              const Text(
                "Something went wrong",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onRetry,
                      child: const Text("Retry"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onLogout,
                      child: const Text("Logout"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
