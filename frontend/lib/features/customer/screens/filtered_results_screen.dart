import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/filter_by_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/location_services_screen.dart'
    show LocationFilterResult, LocationServicesScreen;
import 'package:hamro_sewa_frontend/features/customer/screens/shop_detail_screen.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/place_order_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

class FilteredResultsScreen extends StatefulWidget {
  const FilteredResultsScreen({
    super.key,
    this.initialDistrict,
    this.initialCity,
    this.initialQuery = '',
    this.initialFilters,
  });

  final String? initialDistrict;
  final String? initialCity;
  final String initialQuery;
  final Map<String, dynamic>? initialFilters;

  @override
  State<FilteredResultsScreen> createState() => _FilteredResultsScreenState();
}

class _FilteredResultsScreenState extends State<FilteredResultsScreen> {
  late final TextEditingController _queryController;

  String? _district;
  String? _city;
  Map<String, dynamic>? _filters;
  List<Map<String, dynamic>> _allServices = [];
  Set<int> _favoriteProviderIds = <int>{};
  Set<int> _favoriteServiceIds = <int>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _district = widget.initialDistrict?.trim().isEmpty == true
        ? null
        : widget.initialDistrict?.trim();
    _city = widget.initialCity?.trim().isEmpty == true
        ? null
        : widget.initialCity?.trim();
    _filters = widget.initialFilters == null
        ? null
        : Map<String, dynamic>.from(widget.initialFilters!);
    _queryController = TextEditingController(text: widget.initialQuery.trim());
    _queryController.addListener(_onQueryChanged);
    _loadResults();
    _loadFavoriteSummary();
  }

  @override
  void dispose() {
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    if (mounted) setState(() {});
  }

  String _normalizeLocationValue(String? value) {
    return value == null
        ? ''
        : value
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(RegExp(r'^[, ]+|[, ]+$'), '');
  }

  String _normalizeSelectedLocationValue(String? value) {
    final normalized = _normalizeLocationValue(value);
    if (normalized.isEmpty) return '';
    const anyValues = {
      'any',
      'any district',
      'any city',
      'all',
      'all locations',
      'all services available',
      'select district',
      'select city',
      'none',
      'null',
      'undefined',
    };
    return anyValues.contains(normalized) ? '' : normalized;
  }

  Set<String> _locationParts(String? value) {
    final normalized = _normalizeLocationValue(value);
    if (normalized.isEmpty) return <String>{};
    return normalized
        .split(RegExp(r'[,/|]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toSet();
  }

  bool _isGenericServiceLocation(String? value) {
    const genericValues = {
      'online',
      'remote',
      'virtual',
      'anywhere',
      'nationwide',
      'all nepal',
      'all over nepal',
    };
    return genericValues.contains(_normalizeLocationValue(value));
  }

  bool _matchesSelectedLocation(Map<String, dynamic> service) {
    final selectedDistrict = _normalizeSelectedLocationValue(_district);
    final selectedCity = _normalizeSelectedLocationValue(_city);
    if (selectedDistrict.isEmpty && selectedCity.isEmpty) {
      return true;
    }

    final providerDistrict =
        _normalizeLocationValue(service['provider_district']?.toString());
    final providerCity =
        _normalizeLocationValue(service['provider_city']?.toString());
    final serviceLocation = service['location']?.toString();
    final normalizedServiceLocation = _normalizeLocationValue(serviceLocation);
    final serviceLocationParts = _locationParts(serviceLocation);

    var districtMatches = true;
    var cityMatches = true;

    if (selectedDistrict.isNotEmpty) {
      if (providerDistrict.isNotEmpty) {
        districtMatches = providerDistrict == selectedDistrict;
      } else if (selectedCity.isNotEmpty) {
        districtMatches = true;
      } else {
        districtMatches = serviceLocationParts.contains(selectedDistrict);
      }
    }

    if (selectedCity.isNotEmpty) {
      final hasSpecificServiceLocation = normalizedServiceLocation.isNotEmpty &&
          !_isGenericServiceLocation(serviceLocation);
      cityMatches = hasSpecificServiceLocation
          ? serviceLocationParts.contains(selectedCity)
          : providerCity == selectedCity;
    }

    return districtMatches && cityMatches;
  }

  Future<void> _loadResults() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list =
          await ApiService.getServices(district: _district, city: _city);
      final services = <Map<String, dynamic>>[];
      for (final item in List<dynamic>.from(list)) {
        if (item is Map<String, dynamic>) {
          if (_matchesSelectedLocation(item)) services.add(item);
          continue;
        }
        if (item is Map) {
          final service = Map<String, dynamic>.from(item);
          if (_matchesSelectedLocation(service)) services.add(service);
        }
      }
      if (!mounted) return;
      setState(() {
        _allServices = services;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allServices = [];
        _loading = false;
        _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
    }
  }

  Future<void> _loadFavoriteSummary() async {
    try {
      final summary = await ApiService.getFavoritesSummary();
      final providerIds = <int>{};
      for (final v
          in List<dynamic>.from(summary['favorite_provider_ids'] ?? [])) {
        final n = v is int ? v : int.tryParse(v.toString());
        if (n != null) providerIds.add(n);
      }
      final serviceIds = <int>{};
      for (final v
          in List<dynamic>.from(summary['favorite_service_ids'] ?? [])) {
        final n = v is int ? v : int.tryParse(v.toString());
        if (n != null) serviceIds.add(n);
      }
      if (mounted) {
        setState(() {
          _favoriteProviderIds = providerIds;
          _favoriteServiceIds = serviceIds;
        });
      }
    } catch (_) {
      // Keep filtered results usable if favorites summary fails.
    }
  }

  Future<void> _toggleProviderFavorite(int providerId) async {
    final already = _favoriteProviderIds.contains(providerId);
    setState(() {
      if (already) {
        _favoriteProviderIds.remove(providerId);
      } else {
        _favoriteProviderIds.add(providerId);
      }
    });
    try {
      if (already) {
        await ApiService.removeFavoriteProvider(providerId);
      } else {
        await ApiService.addFavoriteProvider(providerId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (already) {
          _favoriteProviderIds.add(providerId);
        } else {
          _favoriteProviderIds.remove(providerId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update favorite: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
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
            'Could not update favorite: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  bool _matchesSearchQuery(Map<String, dynamic> service) {
    final query = _queryController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    final haystacks = [
      (service['title'] ?? '').toString().toLowerCase(),
      (service['category_name'] ?? service['category'] ?? '')
          .toString()
          .toLowerCase(),
      (service['provider_name'] ?? '').toString().toLowerCase(),
      (service['location'] ?? '').toString().toLowerCase(),
    ];
    return haystacks.any((value) => value.contains(query));
  }

  /// CRITICAL: Only display services that have valid provider information.
  /// Filter out corrupted or incomplete service rows that may lack provider_id or provider_name.
  bool _isValidService(Map<String, dynamic> service) {
    final providerId = service['provider_id'];
    final providerName = (service['provider_name'] ?? '').toString().trim();
    final title = (service['title'] ?? '').toString().trim();

    // Must have provider_id, provider_name, and title
    if (providerId == null || providerName.isEmpty || title.isEmpty) {
      return false;
    }

    return true;
  }

  bool _matchesSelectedFilters(Map<String, dynamic> service) {
    final filters = _filters;
    if (filters == null) return true;

    final shopId = filters['shop']?.toString();
    final providerId = filters['provider']?.toString();
    final serviceCategoryId = filters['service']?.toString();
    final rowProviderId = service['provider_id']?.toString();
    final rowCategoryId = service['category_id']?.toString();

    if (shopId != null && shopId.isNotEmpty && rowProviderId != shopId) {
      return false;
    }
    if (providerId != null &&
        providerId.isNotEmpty &&
        rowProviderId != providerId) {
      return false;
    }
    if (serviceCategoryId != null &&
        serviceCategoryId.isNotEmpty &&
        rowCategoryId != serviceCategoryId) {
      return false;
    }

    final range = filters['dateRange'];
    if (range is Map<String, dynamic>) {
      final start = DateTime.tryParse((range['start'] ?? '').toString());
      final end = DateTime.tryParse((range['end'] ?? '').toString());
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

  List<Map<String, dynamic>> get _filteredServices {
    return _allServices
        .where(_isValidService)
        .where(_matchesSearchQuery)
        .where(_matchesSelectedFilters)
        .toList();
  }

  List<Map<String, dynamic>> get _filteredProviders {
    final providersByKey = <String, Map<String, dynamic>>{};
    for (final service in _filteredServices) {
      final providerId = service['provider_id'];
      final fallbackName =
          (service['provider_name'] ?? 'Provider').toString().trim();
      final key = providerId != null
          ? 'provider:$providerId'
          : 'provider:${fallbackName.toLowerCase()}';
      providersByKey.putIfAbsent(
        key,
        () => {
          'id': providerId,
          'username': fallbackName.isEmpty ? 'Provider' : fallbackName,
          'profession':
              (service['provider_profession'] ?? '').toString().trim(),
          'city': (service['provider_city'] ?? '').toString().trim(),
          'district': (service['provider_district'] ?? '').toString().trim(),
          'verification_status':
              (service['provider_verification_status'] ?? 'unverified')
                  .toString(),
        },
      );
    }
    final providers = providersByKey.values.toList();
    providers.sort(
      (a, b) => (a['username'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['username'] ?? '').toString().toLowerCase()),
    );
    return providers;
  }

  String get _locationScopeLabel {
    if ((_district?.isNotEmpty ?? false) && (_city?.isNotEmpty ?? false)) {
      return '$_district, $_city';
    }
    if (_city?.isNotEmpty ?? false) return 'City: $_city';
    if (_district?.isNotEmpty ?? false) return 'District: $_district';
    return 'All locations';
  }

  String get _resultsScopeTitle {
    if (_city?.isNotEmpty ?? false) return _city!;
    if (_district?.isNotEmpty ?? false) return _district!;
    return 'all locations';
  }

  String _formatDateLabel(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  List<String> get _activeFilterLabels {
    final labels = <String>[];
    final query = _queryController.text.trim();
    if (query.isNotEmpty) labels.add('Search: $query');
    if (_district?.isNotEmpty ?? false) labels.add('District: $_district');
    if (_city?.isNotEmpty ?? false) labels.add('City: $_city');
    final filters = _filters;
    if (filters == null) return labels;
    final shopLabel = filters['shopLabel']?.toString();
    final serviceLabel = filters['serviceLabel']?.toString();
    final providerLabel = filters['providerLabel']?.toString();
    final dateRange = filters['dateRange'];
    if (shopLabel != null && shopLabel.isNotEmpty) {
      labels.add('Shop: $shopLabel');
    }
    if (serviceLabel != null && serviceLabel.isNotEmpty) {
      labels.add('Service: $serviceLabel');
    }
    if (providerLabel != null && providerLabel.isNotEmpty) {
      labels.add('Provider: $providerLabel');
    }
    if (dateRange is Map<String, dynamic>) {
      final start = DateTime.tryParse((dateRange['start'] ?? '').toString());
      final end = DateTime.tryParse((dateRange['end'] ?? '').toString());
      if (start != null && end != null) {
        labels.add(
            'Date: ${_formatDateLabel(start)} to ${_formatDateLabel(end)}');
      }
    }
    return labels;
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.of(context).push<LocationFilterResult?>(
      MaterialPageRoute(
        builder: (_) => LocationServicesScreen(
          initialDistrict: _district,
          initialCity: _city,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _district = result.district;
      _city = result.city;
    });
    await _loadResults();
  }

  Future<void> _openFilterPicker() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>?>(
      MaterialPageRoute(
        builder: (_) => FilterByScreen(
          initialCategory: _initialFilterTabIndex(),
          initialFilters: _filters,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _filters = result == null || result.isEmpty ? null : result;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _district = null;
      _city = null;
      _filters = null;
      _queryController.clear();
    });
    _loadResults();
  }

  void _openProvider(Map<String, dynamic> provider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopDetailScreen(provider: provider),
      ),
    );
  }

  void _openService(Map<String, dynamic> service) {
    final serviceIdRaw = (service['id'] ?? '').toString();
    final title = (service['title'] ?? '').toString();
    final categoryId = (service['category_id'] ?? '').toString().trim();
    final categoryTitle =
        (service['category_name'] ?? service['category'] ?? title)
            .toString()
            .trim();
    if (categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppStrings.t(context, 'categoryNotAvailableForService')),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceOrderScreen(
          categoryId: categoryId,
          categoryTitle: categoryTitle.isEmpty ? title : categoryTitle,
          categoryIcon: Icons.build_circle_outlined,
          serviceId: int.tryParse(serviceIdRaw),
          serviceTitle: title,
        ),
      ),
    );
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

  bool get _hasAnyActiveFilter => _activeFilterLabels.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final filteredServices = _filteredServices;
    final filteredProviders = _filteredProviders;

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          AppStrings.t(context, 'filteredResults'),
          style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _openFilterPicker,
          ),
          if (_hasAnyActiveFilter)
            TextButton(
              onPressed: _clearAllFilters,
              child: Text(
                AppStrings.t(context, 'clear'),
                style: TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadResults,
        color: AppTheme.customerPrimary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                hintText: AppStrings.t(context, 'searchWithinResults'),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppTheme.customerPrimary,
                ),
                suffixIcon: _queryController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _queryController.clear(),
                      ),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _openLocationPicker,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: Colors.grey[600],
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _locationScopeLabel,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openFilterPicker,
              icon: const Icon(Icons.tune),
              label: Text(AppStrings.t(context, 'filterBy')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.customerPrimary,
                side: const BorderSide(color: AppTheme.customerPrimary),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            if (_activeFilterLabels.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selected filters',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _activeFilterLabels
                          .map(
                            (label) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.customerPrimary.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.customerPrimary,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.customerPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.customerPrimary.withOpacity(0.16),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.place_outlined,
                    color: AppTheme.customerPrimary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Results for $_resultsScopeTitle',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _loading
                              ? 'Loading matching services and providers...'
                              : 'Showing ${filteredServices.length} services from ${filteredProviders.length} providers.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.orange.shade900),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(
                  child: AppShimmerLoader(
                    color: AppTheme.customerPrimary,
                  ),
                ),
              )
            else if (_error == null && filteredServices.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_outlined,
                      size: 44,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No matching providers or services found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try a different city or adjust the selected filters.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else ...[
              _buildProvidersSection(filteredProviders),
              const SizedBox(height: 24),
              _buildServicesSection(filteredServices),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProvidersSection(List<Map<String, dynamic>> providers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Providers in $_resultsScopeTitle',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkGrey,
          ),
        ),
        const SizedBox(height: 12),
        if (providers.isEmpty)
          Text(
            'No providers found for the selected filters.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          )
        else
          ListView.separated(
            itemCount: providers.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final provider = providers[index];
              final providerId = provider['id'] is int
                  ? provider['id'] as int
                  : int.tryParse((provider['id'] ?? '').toString());
              final name = (provider['username'] ?? 'Provider').toString();
              final profession =
                  (provider['profession'] ?? '').toString().trim();
              final city = (provider['city'] ?? '').toString().trim();
              final district = (provider['district'] ?? '').toString().trim();

              // STRICT verification check: Only 'approved' is verified
              final verificationStatus =
                  (provider['provider_verification_status'] ??
                          provider['verification_status'] ??
                          'unverified')
                      .toString()
                      .toLowerCase()
                      .trim();
              final isVerified = verificationStatus == 'approved';

              // Validation: Check if provider location data exists
              final providerCity =
                  (provider['provider_city'] ?? '').toString().trim();
              final providerDistrict =
                  (provider['provider_district'] ?? '').toString().trim();
              final hasLocationData =
                  providerCity.isNotEmpty || providerDistrict.isNotEmpty;

              final locationText = providerCity.isNotEmpty
                  ? providerCity
                  : providerDistrict.isNotEmpty
                      ? providerDistrict
                      : '';
              return Material(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => _openProvider(provider),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              AppTheme.customerPrimary.withOpacity(0.15),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'P',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.customerPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkGrey,
                                ),
                              ),
                              if (profession.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  profession,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                              if (locationText.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        locationText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isVerified
                                    ? Colors.green.withOpacity(0.12)
                                    : Colors.orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isVerified ? 'Verified' : 'Unverified',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isVerified
                                      ? Colors.green[800]
                                      : Colors.orange[800],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                providerId != null &&
                                        _favoriteProviderIds
                                            .contains(providerId)
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: AppTheme.linkRed,
                              ),
                              onPressed: providerId == null
                                  ? null
                                  : () => _toggleProviderFavorite(providerId),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildServicesSection(List<Map<String, dynamic>> services) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Services in $_resultsScopeTitle',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkGrey,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          itemCount: services.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final service = services[index];
            final title = (service['title'] ?? '').toString();
            final serviceId = service['id'] is int
                ? service['id'] as int
                : int.tryParse((service['id'] ?? '').toString());
            final category =
                (service['category_name'] ?? service['category'] ?? '')
                    .toString();
            final provider =
                (service['provider_name'] ?? 'Provider').toString();
            final location = (service['location'] ?? '').toString().trim();
            return Material(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => _openService(service),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppTheme.customerPrimary.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.build_circle_outlined,
                          color: AppTheme.customerPrimary,
                        ),
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
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkGrey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (category.isNotEmpty) category,
                                if (provider.isNotEmpty) provider,
                              ].join(' - '),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                            if (location.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      location,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              serviceId != null &&
                                      _favoriteServiceIds.contains(serviceId)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: AppTheme.linkRed,
                            ),
                            onPressed: serviceId == null
                                ? null
                                : () => _toggleServiceFavorite(serviceId),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
