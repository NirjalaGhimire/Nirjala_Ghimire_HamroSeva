import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _me;
  List<dynamic> _services = [];
  List<dynamic> _history = [];

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
      final services = await ApiService.listServices();
      final history = await ApiService.myRequests();

      if (!mounted) return;
      setState(() {
        _me = me;
        _services = services;
        _history = history;
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

  Future<void> _openRequestDialog(int serviceId, String serviceTitle) async {
    final controller = TextEditingController();

    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Request: $serviceTitle"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Optional note (e.g., time, location, details)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Send Request"),
          ),
        ],
      ),
    );

    if (note == null) return;

    try {
      await ApiService.createRequest(serviceId: serviceId, note: note);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Request sent ✅")),
      );

      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = (_me?["username"] ?? "Customer").toString();
    final email = (_me?["email"] ?? "").toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Customer Home"),
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
                          subtitle: email.isEmpty ? "Welcome to HamroSeva" : email,
                          icon: Icons.person,
                        ),
                        const SizedBox(height: 18),

                        // SERVICES
                        Row(
                          children: const [
                            Icon(Icons.home_repair_service),
                            SizedBox(width: 8),
                            Text(
                              "Available Services",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (_services.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Center(child: Text("No services available right now.")),
                          )
                        else
                          ..._services.map((s) {
                            final id = s["id"] as int?;
                            final title = (s["title"] ?? s["name"] ?? "Service").toString();
                            final desc = (s["description"] ?? "").toString();

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
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      child: Icon(Icons.build_circle_outlined),
                                    ),
                                    const SizedBox(width: 12),
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
                                          if (desc.isNotEmpty) ...[
                                            const SizedBox(height: 5),
                                            Text(
                                              desc,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.black54),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      height: 40,
                                      child: ElevatedButton(
                                        onPressed: id == null
                                            ? null
                                            : () => _openRequestDialog(id, title),
                                        child: const Text("Request"),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),

                        const SizedBox(height: 10),

                        // HISTORY
                        Row(
                          children: const [
                            Icon(Icons.history),
                            SizedBox(width: 8),
                            Text(
                              "Request History",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (_history.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text("No requests yet."),
                          )
                        else
                          ..._history.map((r) {
                            final serviceName = (r["service_name"] ??
                                    r["service_title"] ??
                                    r["service"] ??
                                    "Service")
                                .toString();
                            final status = (r["status"] ?? "PENDING").toString().toUpperCase();
                            final createdAt = (r["created_at"] ?? r["created"] ?? "").toString();

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: ListTile(
                                  title: Text(serviceName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: createdAt.isEmpty
                                      ? Text("Status: $status")
                                      : Text("$createdAt\nStatus: $status"),
                                  isThreeLine: createdAt.isNotEmpty,
                                  trailing: _StatusChip(status: status),
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
  final IconData icon;

  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
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
            CircleAvatar(radius: 22, child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(status));
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
