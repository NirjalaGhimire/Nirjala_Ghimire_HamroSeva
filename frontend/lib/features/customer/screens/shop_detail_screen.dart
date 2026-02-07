import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Shop detail for a provider. Pass [provider] to show real data; otherwise shows empty state.
class ShopDetailScreen extends StatefulWidget {
  const ShopDetailScreen({
    super.key,
    this.provider,
  });

  /// Provider map from API (id, username, profession, etc.). If null, shows empty state.
  final Map<String, dynamic>? provider;

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  List<Map<String, dynamic>> _services = [];
  bool _loadingServices = false;

  @override
  void initState() {
    super.initState();
    if (widget.provider != null) _loadServices();
  }

  Future<void> _loadServices() async {
    final prov = widget.provider;
    if (prov == null) return;
    setState(() => _loadingServices = true);
    try {
      final categories = await ApiService.getCategories();
      if (categories.isEmpty) {
        if (mounted) setState(() { _services = []; _loadingServices = false; });
        return;
      }
      final categoryIds = categories.map((c) => c['id']).toSet();
      final allServices = <Map<String, dynamic>>[];
      for (final catId in categoryIds) {
        final list = await ApiService.getServicesByCategory(catId);
        for (final s in list) {
          if (s is Map && s['provider_id'] == prov['id']) {
            allServices.add(Map<String, dynamic>.from(s));
          }
        }
            }
      if (mounted) setState(() { _services = allServices; _loadingServices = false; });
    } catch (_) {
      if (mounted) setState(() { _services = []; _loadingServices = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    if (p == null) {
      return Scaffold(
        backgroundColor: AppTheme.white,
        appBar: AppBar(
          title: const Text('Shop details', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.customerPrimary,
          foregroundColor: AppTheme.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Open a shop from the list to see details.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
          ),
        ),
      );
    }

    final name = (p['username'] ?? 'Provider').toString();
    final profession = (p['profession'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Shop details', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppTheme.customerPrimary.withOpacity(0.15),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'P',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.customerPrimary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    if (profession.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.work_outline, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(profession, style: TextStyle(color: Colors.grey[700])),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Services from this shop', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_loadingServices)
              const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: AppTheme.customerPrimary)))
            else if (_services.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No services listed yet.', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              )
            else
              ..._services.map((s) => _serviceChip((s['title'] ?? s['service_name'] ?? s['name'] ?? 'Service').toString())),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Contact shop'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.customerPrimary,
                  foregroundColor: AppTheme.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Chip(
        label: Text(label),
        backgroundColor: AppTheme.customerPrimary.withOpacity(0.1),
        side: BorderSide(color: AppTheme.customerPrimary.withOpacity(0.3)),
      ),
    );
  }
}
