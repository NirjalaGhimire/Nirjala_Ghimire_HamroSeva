import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _me;
  List<dynamic> _incoming = [];

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
      final me = await ApiService.me();
      final incoming = await ApiService.providerIncomingRequests();

      if (!mounted) return;
      setState(() {
        _me = me;
        _incoming = incoming;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _accept(int requestId) async {
    try {
      await ApiService.acceptRequest(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Accepted ✅")),
      );
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Accept failed: $e")),
      );
    }
  }

  Future<void> _reject(int requestId) async {
    try {
      await ApiService.rejectRequest(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rejected ❌")),
      );
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Reject failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = (_me?["username"] ?? "Provider").toString();
    final email = (_me?["email"] ?? "").toString();
    final profession = (_me?["profession"] ?? "").toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Provider Home"),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: "Logout",
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(error: _error!, onRetry: _loadAll)
                : RefreshIndicator(
                    onRefresh: _loadAll,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _HeaderCard(
                          title: "Hi, $username",
                          subtitle: email.isEmpty ? "Service Provider" : email,
                          profession: profession,
                        ),
                        const SizedBox(height: 18),

                        Row(
                          children: const [
                            Icon(Icons.inbox),
                            SizedBox(width: 8),
                            Text(
                              "Incoming Requests",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (_incoming.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: Text("No incoming requests right now.")),
                          )
                        else
                          ..._incoming.map((r) {
                            final id = r["id"] as int?;
                            final customerName =
                                (r["customer_name"] ?? r["customer"] ?? "Customer").toString();
                            final serviceName =
                                (r["service_name"] ?? r["service_title"] ?? r["service"] ?? "Service").toString();
                            final note = (r["note"] ?? "").toString();
                            final status = (r["status"] ?? "PENDING").toString().toUpperCase();

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.black12),
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      serviceName,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                    ),
                                    const SizedBox(height: 6),
                                    Text("Customer: $customerName",
                                        style: const TextStyle(color: Colors.black54)),
                                    if (note.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text("Note: $note"),
                                    ],
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Chip(label: Text(status)),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: (id == null) ? null : () => _reject(id),
                                          child: const Text("Reject"),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: (id == null) ? null : () => _accept(id),
                                          child: const Text("Accept"),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String profession;

  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.profession,
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
          children: [
            const CircleAvatar(radius: 22, child: Icon(Icons.work_outline)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                  if (profession.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Chip(label: Text(profession)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60),
            const SizedBox(height: 10),
            const Text("Something went wrong", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onRetry, child: const Text("Retry")),
          ],
        ),
      ),
    );
  }
}
