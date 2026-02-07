import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/filter_by_screen.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/select_provider_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Full search UI: search field, filter button, and results (services from backend).
class CustomerSearchScreen extends StatefulWidget {
  const CustomerSearchScreen({super.key, this.hint = 'Search for services...'});

  final String hint;

  @override
  State<CustomerSearchScreen> createState() => _CustomerSearchScreenState();
}

class _CustomerSearchScreenState extends State<CustomerSearchScreen> {
  final TextEditingController _query = TextEditingController();
  Map<String, dynamic>? _filters;
  List<dynamic> _services = [];
  bool _loading = true;
  String? _error;

  void _onQueryChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _loadServices();
    _query.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _query.removeListener(_onQueryChanged);
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getServices();
      if (mounted) {
        setState(() {
        _services = List<dynamic>.from(list);
        _loading = false;
      });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _error = e.toString();
        _services = [];
        _loading = false;
      });
      }
    }
  }

  Future<void> _openFilter() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => FilterByScreen(
          onApply: (f) => setState(() => _filters = f),
        ),
      ),
    );
    if (result != null) setState(() => _filters = result);
  }

  List<dynamic> get _filteredServices {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return _services;
    return _services.where((s) {
      final m = s as Map<String, dynamic>;
      final title = (m['title'] ?? '').toString().toLowerCase();
      final cat = (m['category_name'] ?? m['category'] ?? '').toString().toLowerCase();
      final provider = (m['provider_name'] ?? '').toString().toLowerCase();
      return title.contains(q) || cat.contains(q) || provider.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text(
          'Search',
          style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      prefixIcon: const Icon(Icons.search, color: AppTheme.customerPrimary),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onSubmitted: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppTheme.customerPrimary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _openFilter,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(Icons.tune, color: AppTheme.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_filters != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 16, color: AppTheme.customerPrimary),
                  const SizedBox(width: 6),
                  const Text('Filters applied', style: TextStyle(fontSize: 12, color: AppTheme.customerPrimary)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _filters = null),
                    child: const Text('Clear', style: TextStyle(color: AppTheme.linkRed)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Popular Services',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.customerPrimary))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[700])),
                            const SizedBox(height: 12),
                            TextButton(onPressed: _loadServices, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredServices.length,
                        itemBuilder: (context, index) {
                          final s = _filteredServices[index] as Map<String, dynamic>;
                          final id = (s['id'] ?? '').toString();
                          final title = (s['title'] ?? '').toString();
                          final category = (s['category_name'] ?? s['category'] ?? '').toString();
                          final price = s['price'] != null ? (s['price'] is num ? (s['price'] as num).toDouble() : 0.0) : 0.0;
                          final provider = (s['provider_name'] ?? '').toString();
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.customerPrimary.withOpacity(0.15),
                                child: const Icon(Icons.build_circle_outlined, color: AppTheme.customerPrimary),
                              ),
                              title: Text(
                                title,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                [if (category.isNotEmpty) category, 'Rs ${price.toStringAsFixed(0)}', if (provider.isNotEmpty) provider]
                                    .join(' • '),
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
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
          ),
        ],
      ),
    );
  }
}
