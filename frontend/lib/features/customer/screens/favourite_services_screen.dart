import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/select_provider_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Favourite Services – services the customer has booked (from backend).
class FavouriteServicesScreen extends StatefulWidget {
  const FavouriteServicesScreen({super.key});

  @override
  State<FavouriteServicesScreen> createState() => _FavouriteServicesScreenState();
}

class _FavouriteServicesScreenState extends State<FavouriteServicesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getUserBookings();
      final raw = List<dynamic>.from(list);
      final seen = <int>{};
      final List<Map<String, dynamic>> services = [];
      for (final b in raw) {
        final m = b as Map<String, dynamic>;
        final sid = m['service_id'] ?? m['serviceId'];
        if (sid == null) continue;
        final id = sid is int ? sid : int.tryParse(sid.toString());
        if (id == null || seen.contains(id)) continue;
        seen.add(id);
        final title = (m['service_title'] ?? '').toString();
        final amt = m['total_amount'];
        final price = amt != null ? (amt is num ? (amt).toDouble() : 0.0) : 0.0;
        services.add({
          'id': id.toString(),
          'title': title.isEmpty ? 'Service' : title,
          'category': '',
          'price': price,
        });
      }
      if (mounted) {
        setState(() {
        _items = services;
        _loading = false;
      });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _error = e.toString();
        _items = [];
        _loading = false;
      });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Favourite Services', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.customerPrimary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[700])),
                        const SizedBox(height: 16),
                        TextButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('No favourites yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                          const SizedBox(height: 8),
                          Text('Services you book will appear here', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final s = _items[index];
                        final title = (s['title'] ?? '').toString();
                        final category = (s['category'] ?? '').toString();
                        final price = (s['price'] ?? 0) is num ? (s['price'] as num).toDouble() : 0.0;
                        final id = (s['id'] ?? '').toString();
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.customerPrimary.withOpacity(0.15),
                              child: const Icon(Icons.build_circle_outlined, color: AppTheme.customerPrimary),
                            ),
                            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(category.isEmpty ? 'Rs ${price.toStringAsFixed(0)}' : '$category • Rs ${price.toStringAsFixed(0)}'),
                            trailing: const Icon(Icons.chevron_right, color: AppTheme.customerPrimary),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SelectProviderScreen(
                                    categoryId: id,
                                    categoryTitle: title,
                                    categoryIcon: Icons.build,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
