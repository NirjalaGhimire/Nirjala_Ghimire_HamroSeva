import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

/// Provider's own services – real data from API.
class ProviderServicesScreen extends StatefulWidget {
  const ProviderServicesScreen({super.key});

  @override
  State<ProviderServicesScreen> createState() => _ProviderServicesScreenState();
}

class _ProviderServicesScreenState extends State<ProviderServicesScreen> {
  List<dynamic> _services = [];
  bool _loading = true;
  String? _error;

  String _statusLabel(String? rawStatus) {
    final status = (rawStatus ?? '').trim().toLowerCase();
    switch (status) {
      case 'active':
        return 'Available';
      case 'inactive':
        return 'Temporarily unavailable';
      case 'paused':
        return 'Paused';
      default:
        return 'Status not set';
    }
  }

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
      final user = await TokenStorage.getSavedUser();
      final id = user?['id'];
      if (id == null) {
        if (mounted) {
          setState(() {
          _error = 'Not logged in';
          _loading = false;
        });
        }
        return;
      }
      final providerId = id is int ? id : int.tryParse(id.toString());
      if (providerId == null) {
        if (mounted) {
          setState(() {
          _error = 'Invalid user';
          _loading = false;
        });
        }
        return;
      }
      final list = await ApiService.getServicesForProvider(providerId);
      if (mounted) {
        setState(() {
        _services = list;
        _loading = false;
      });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
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
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('My Services', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
      ),
      body: _loading
          ? const AppPageShimmer()
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700])),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _services.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('No services yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                          const SizedBox(height: 8),
                          Text('Services you add will appear here.', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _services.length,
                        itemBuilder: (context, index) {
                          final s = _services[index] as Map<String, dynamic>;
                          final title = s['title'] as String? ?? 'Service';
                          final description =
                              (s['description'] as String? ?? '').trim();
                          final statusLabel =
                              _statusLabel(s['status'] as String?);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 6),
                                  Text(
                                    'Quotation based',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.customerPrimary,
                                    ),
                                  ),
                                  if (description.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
