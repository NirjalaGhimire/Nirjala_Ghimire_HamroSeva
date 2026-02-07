import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Favourite Provider – providers the customer has booked (from backend bookings).
class FavouriteProviderScreen extends StatefulWidget {
  const FavouriteProviderScreen({super.key});

  @override
  State<FavouriteProviderScreen> createState() => _FavouriteProviderScreenState();
}

class _FavouriteProviderScreenState extends State<FavouriteProviderScreen> {
  List<Map<String, dynamic>> _providers = [];
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
      final seen = <String>{};
      final List<Map<String, dynamic>> providers = [];
      for (final b in raw) {
        final m = b as Map<String, dynamic>;
        final name = (m['provider_name'] ?? '').toString();
        if (name.isEmpty) continue;
        final key = name;
        if (seen.contains(key)) continue;
        seen.add(key);
        final service = (m['service_title'] ?? '').toString();
        providers.add({
          'id': key.hashCode.abs().toString(),
          'name': name,
          'service': service.isEmpty ? 'Service provider' : service,
        });
      }
      if (mounted) {
        setState(() {
        _providers = providers;
        _loading = false;
      });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _error = e.toString();
        _providers = [];
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
        title: const Text('Favourite Provider', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
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
              : _providers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_outline, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('No providers yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                          const SizedBox(height: 8),
                          Text('Providers you book will appear here', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _providers.length,
                      itemBuilder: (context, index) {
                        final p = _providers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.customerPrimary.withOpacity(0.2),
                              child: Text(
                                (p['name'] ?? 'U')[0].toString().toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.customerPrimary),
                              ),
                            ),
                            title: Text(p['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(p['service']!, style: TextStyle(color: Colors.grey[600])),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.customerPrimary),
                                  onPressed: () {},
                                ),
                                IconButton(
                                  icon: const Icon(Icons.star, color: Colors.amber),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
