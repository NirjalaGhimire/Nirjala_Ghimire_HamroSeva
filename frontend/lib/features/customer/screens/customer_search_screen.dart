import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/filter_by_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/filtered_results_screen.dart';
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
  Set<int> _favoriteServiceIds = <int>{};
  bool _loading = true;
  String? _error;

  void _onQueryChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _loadServices();
    _loadFavoriteSummary();
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

  Future<void> _loadFavoriteSummary() async {
    try {
      final summary = await ApiService.getFavoritesSummary();
      final ids = <int>{};
      for (final v
          in List<dynamic>.from(summary['favorite_service_ids'] ?? [])) {
        final n = v is int ? v : int.tryParse(v.toString());
        if (n != null) ids.add(n);
      }
      if (mounted) {
        setState(() => _favoriteServiceIds = ids);
      }
    } catch (_) {
      // Keep search usable even if favorites summary fails.
    }
  }

  int _initialFilterTabIndex() {
    final filters = _filters;
    if (filters == null) return 0;
    final provider = (filters['provider'] ?? '').toString().trim();
    if (provider.isNotEmpty) return 3;
    final dateRange = filters['dateRange'];
    if (dateRange is Map<String, dynamic> && dateRange.isNotEmpty) return 2;
    final service = (filters['service'] ?? '').toString().trim();
    if (service.isNotEmpty) return 1;
    return 0;
  }

  Future<void> _toggleServiceFavorite(int serviceId) async {
    final already = _favoriteServiceIds.contains(serviceId);
    setState(() {
      if (already) {
        _favoriteServiceIds.remove(serviceId);
      } else {
        _favoriteServiceIds.add(serviceId);
      }
    });
    try {
      if (already) {
        await ApiService.removeFavoriteService(serviceId);
      } else {
        await ApiService.addFavoriteService(serviceId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (already) {
          _favoriteServiceIds.add(serviceId);
        } else {
          _favoriteServiceIds.remove(serviceId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.t(context, 'couldNotUpdateFavorite')}: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _openFilter() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>?>(
      MaterialPageRoute(
        builder: (_) => FilterByScreen(
          initialCategory: _initialFilterTabIndex(),
          initialFilters: _filters,
          onApply: (f) => setState(() => _filters = f),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _filters = result);
    if (result != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FilteredResultsScreen(
            initialQuery: _query.text.trim(),
            initialFilters: result,
          ),
        ),
      );
    }
  }

  /// Validate that a service has required fields and valid provider info.
  /// CRITICAL: Only return services that have provider_id AND provider_name.
  bool _isValidService(Map<String, dynamic> service) {
    final providerId = service['provider_id'];
    final providerName = (service['provider_name'] ?? '').toString().trim();

    // Must have provider_id and provider_name
    if (providerId == null || providerName.isEmpty) {
      return false;
    }

    // Must have title and category
    final title = (service['title'] ?? '').toString().trim();
    final category = (service['category_name'] ?? service['category'] ?? '')
        .toString()
        .trim();
    if (title.isEmpty) {
      return false;
    }

    return true;
  }

  bool _matchesAppliedFilters(Map<String, dynamic> service) {
    final filters = _filters;
    if (filters == null) return true;

    final providerId = service['provider_id']?.toString();
    final categoryId = service['category_id']?.toString();
    final shopId = filters['shop']?.toString();
    final selectedProviderId = filters['provider']?.toString();
    final selectedServiceId = filters['service']?.toString();

    if (shopId != null && shopId.isNotEmpty && providerId != shopId) {
      return false;
    }
    if (selectedProviderId != null &&
        selectedProviderId.isNotEmpty &&
        providerId != selectedProviderId) {
      return false;
    }
    if (selectedServiceId != null &&
        selectedServiceId.isNotEmpty &&
        categoryId != selectedServiceId) {
      return false;
    }

    final dateRange = filters['dateRange'];
    if (dateRange is Map<String, dynamic>) {
      final start = DateTime.tryParse((dateRange['start'] ?? '').toString());
      final end = DateTime.tryParse((dateRange['end'] ?? '').toString());
      final createdAt =
          DateTime.tryParse((service['created_at'] ?? '').toString());
      if (start != null && end != null) {
        if (createdAt == null) return false;
        final createdDate =
            DateTime(createdAt.year, createdAt.month, createdAt.day);
        final startDate = DateTime(start.year, start.month, start.day);
        final endDate = DateTime(end.year, end.month, end.day);
        if (createdDate.isBefore(startDate) || createdDate.isAfter(endDate)) {
          return false;
        }
      }
    }

    return true;
  }

  List<dynamic> get _filteredServices {
    final q = _query.text.trim().toLowerCase();
    return _services.where((s) {
      final m = s as Map<String, dynamic>;
      // CRITICAL: Only display services with valid provider info
      if (!_isValidService(m)) return false;
      if (!_matchesAppliedFilters(m)) return false;
      if (q.isEmpty) return true;
      final title = (m['title'] ?? '').toString().toLowerCase();
      final cat =
          (m['category_name'] ?? m['category'] ?? '').toString().toLowerCase();
      final provider = (m['provider_name'] ?? '').toString().toLowerCase();
      return title.contains(q) || cat.contains(q) || provider.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          AppStrings.t(context, 'search'),
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
                      prefixIcon: const Icon(Icons.search,
                          color: AppTheme.customerPrimary),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
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
                  const Icon(Icons.filter_list,
                      size: 16, color: AppTheme.customerPrimary),
                  const SizedBox(width: 6),
                  Text(AppStrings.t(context, 'filtersApplied'),
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.customerPrimary)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _filters = null),
                    child: Text(AppStrings.t(context, 'clear'),
                        style: TextStyle(color: AppTheme.linkRed)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppStrings.t(context, 'popularServices'),
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
                ? const AppPageShimmer()
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red[700])),
                            const SizedBox(height: 12),
                            TextButton(
                                onPressed: _loadServices,
                                child: Text(AppStrings.t(context, 'retry'))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredServices.length,
                        itemBuilder: (context, index) {
                          final s =
                              _filteredServices[index] as Map<String, dynamic>;
                          final id = (s['id'] ?? '').toString();
                          final sid = int.tryParse(id);
                          final title = (s['title'] ?? '').toString();
                          final categoryId =
                              (s['category_id'] ?? '').toString().trim();
                          final category =
                              (s['category_name'] ?? s['category'] ?? '')
                                  .toString();
                          final provider =
                              (s['provider_name'] ?? '').toString();
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
                                backgroundColor:
                                    AppTheme.customerPrimary.withOpacity(0.15),
                                child: const Icon(Icons.build_circle_outlined,
                                    color: AppTheme.customerPrimary),
                              ),
                              title: Text(
                                title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                [
                                  if (category.isNotEmpty) category,
                                  if (provider.isNotEmpty) provider,
                                ].join(' • '),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                              trailing: SizedBox(
                                width: 88,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        sid != null &&
                                                _favoriteServiceIds
                                                    .contains(sid)
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: AppTheme.linkRed,
                                      ),
                                      onPressed: sid == null
                                          ? null
                                          : () => _toggleServiceFavorite(sid),
                                    ),
                                    const Icon(Icons.chevron_right,
                                        color: AppTheme.customerPrimary),
                                  ],
                                ),
                              ),
                              onTap: () {
                                if (categoryId.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Category not available for this service.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SelectProviderScreen(
                                      categoryId: categoryId,
                                      categoryTitle: category.isNotEmpty
                                          ? category
                                          : title,
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
