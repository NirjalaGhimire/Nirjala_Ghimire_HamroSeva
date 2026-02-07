import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/place_order_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Step 1: Show services (subcategories) under the category, no providers.
/// Step 2: When user selects a service, show only providers for that service.
class SelectProviderScreen extends StatefulWidget {
  const SelectProviderScreen({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
    required this.categoryIcon,
  });

  final String categoryId;
  final String categoryTitle;
  final IconData categoryIcon;

  @override
  State<SelectProviderScreen> createState() => _SelectProviderScreenState();
}

class _SelectProviderScreenState extends State<SelectProviderScreen> {
  /// All subcategory titles for step 1 (from forSignup=true so every category shows all options).
  List<dynamic> _allTitlesRows = [];
  /// Filtered rows (provider matches service) for step 2 – used to show providers or "no provider" dialog.
  List<dynamic> _filteredProviderRows = [];
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _selectedService;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedService = null;
    });
    try {
      final id = widget.categoryId;
      final isNumeric = int.tryParse(id) != null;
      if (isNumeric) {
        final allTitles = await ApiService.getServicesByCategory(id, forSignup: true);
        final filtered = await ApiService.getServicesByCategory(id, forSignup: false);
        if (mounted) {
          setState(() {
            _allTitlesRows = allTitles;
            _filteredProviderRows = filtered;
            _loading = false;
          });
        }
      } else {
        final all = await ApiService.getServices();
        final titleLower = widget.categoryTitle.toLowerCase().trim();
        final list = all.where((s) {
          final catName = (s['category_name'] ?? s['category'] ?? '').toString().toLowerCase();
          final serviceTitle = (s['title'] ?? '').toString().toLowerCase();
          if (catName.contains(titleLower) || titleLower.contains(catName)) return true;
          final stem = titleLower.length >= 5 ? titleLower.substring(0, 5) : titleLower;
          if (stem.length >= 4 && (catName.contains(stem) || catName.startsWith(stem) || serviceTitle.contains(stem))) return true;
          return false;
        }).toList();
        if (mounted) {
          setState(() {
            _allTitlesRows = list;
            _filteredProviderRows = list;
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
          _allTitlesRows = [];
          _filteredProviderRows = [];
        });
      }
    }
  }

  /// Unique services (by title) for step 1 – show all subcategories from DB even if no providers.
  List<Map<String, dynamic>> get _uniqueServices {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final row in _allTitlesRows) {
      final title = (row['title'] ?? 'Service').toString().trim();
      if (title.isEmpty || seen.contains(title)) continue;
      seen.add(title);
      final id = row['id'];
      final tid = id is int ? id : int.tryParse(id?.toString() ?? '');
      out.add({'id': tid ?? 0, 'title': title});
    }
    return out;
  }

  /// Providers for the selected service (filtered list – only matching providers).
  List<Map<String, dynamic>> get _providerRowsForSelectedService {
    if (_selectedService == null) return [];
    final wantTitle = (_selectedService!['title'] ?? '').toString().trim();
    if (wantTitle.isEmpty) return [];
    return _filteredProviderRows
        .where((row) => (row['title'] ?? '').toString().trim() == wantTitle)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _onSelectService(Map<String, dynamic> service) {
    final title = (service['title'] ?? '').toString().trim();
    final providers = _filteredProviderRows
        .where((row) => (row['title'] ?? '').toString().trim() == title)
        .toList();
    if (providers.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No provider available'),
          content: Text(
            'No service provider is available for "$title" at the moment. Please try another service or check back later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _selectedService = service);
  }

  void _onBackFromProviders() {
    setState(() => _selectedService = null);
  }

  void _onSelectProvider(Map<String, dynamic> row) {
    final id = row['id'];
    final title = (row['title'] ?? 'Service') as String;
    final providerName = (row['provider_name'] ?? 'Provider') as String;
    final price = (row['price'] != null)
        ? (double.tryParse(row['price'].toString()) ?? 0.0)
        : 0.0;
    if (id == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PlaceOrderScreen(
          categoryId: widget.categoryId,
          categoryTitle: widget.categoryTitle,
          categoryIcon: widget.categoryIcon,
          serviceId: id is int ? id : int.tryParse(id.toString()) ?? 0,
          serviceTitle: title,
          providerName: providerName,
          price: price,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          _selectedService == null ? 'Choose service' : 'Choose provider',
          style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        leading: _selectedService != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _onBackFromProviders,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadServices,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.customerPrimary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 16),
              TextButton(onPressed: _loadServices, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_selectedService == null) {
      // Step 1: list of services (subcategories) only, no providers
      final services = _uniqueServices;
      if (services.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.build_circle_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No services under ${widget.categoryTitle} yet',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: _loadServices,
        color: AppTheme.customerPrimary,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final s = services[index];
            final title = (s['title'] ?? 'Service') as String;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: InkWell(
                onTap: () => _onSelectService(s),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.customerPrimary.withOpacity(0.15),
                        child: const Icon(Icons.build_circle_outlined, size: 28, color: AppTheme.customerPrimary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppTheme.darkGrey),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    // Step 2: providers for the selected service
    final providers = _providerRowsForSelectedService;
    final serviceTitle = _selectedService!['title'] as String? ?? 'Service';
    if (providers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No providers registered for $serviceTitle yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _onBackFromProviders,
              child: const Text('Back to services'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadServices,
      color: AppTheme.customerPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: providers.length,
        itemBuilder: (context, index) {
          final row = providers[index];
          final title = (row['title'] ?? 'Service') as String;
          final providerName = (row['provider_name'] ?? 'Provider') as String;
          final price = row['price']?.toString() ?? '0';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: InkWell(
              onTap: () => _onSelectProvider(row),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.customerPrimary.withOpacity(0.15),
                      child: Text(
                        providerName.isNotEmpty ? providerName[0].toUpperCase() : 'P',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.customerPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            providerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Rs. $price',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.customerPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: AppTheme.darkGrey),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
