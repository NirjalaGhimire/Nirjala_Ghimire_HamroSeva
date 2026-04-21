import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/core/utils/nepal_time.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_notifications_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_profile_tab_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_search_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/filtered_results_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/shop_detail_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/location_services_screen.dart'
    show LocationServicesScreen, LocationFilterResult;
import 'package:hamro_sewa_frontend/features/customer/screens/customer_new_request_screen.dart';
import 'package:hamro_sewa_frontend/core/referral_share_content.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/referral_loyalty_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_categories_tab_screen.dart';
import 'package:hamro_sewa_frontend/features/ai/screens/ai_assistant_screen.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/place_order_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Customer Home tab: avatar + name, location bar, carousel, Upcoming Booking, Refer banner.
class CustomerHomeTabScreen extends StatefulWidget {
  const CustomerHomeTabScreen({super.key});

  @override
  State<CustomerHomeTabScreen> createState() => _CustomerHomeTabScreenState();
}

class _CustomerHomeTabScreenState extends State<CustomerHomeTabScreen> {
  int _carouselIndex = 0;
  Map<String, dynamic>? _user;

  /// Home "Popular Services" filter: both null = all providers (by provider district/city in DB).
  String? _filterDistrict;
  String? _filterCity;
  List<Map<String, dynamic>> _services = [];
  List<dynamic> _bookings = [];
  int _notificationCount = 0;
  bool _loadingData = true;
  bool _sharingReferral = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadData();
  }

  Future<void> _loadUser() async {
    final user = await TokenStorage.getSavedUser();
    if (mounted) setState(() => _user = user);
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
    final selectedDistrict = _normalizeSelectedLocationValue(_filterDistrict);
    final selectedCity = _normalizeSelectedLocationValue(_filterCity);
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

  bool get _hasLocationFilter {
    return _normalizeSelectedLocationValue(_filterDistrict).isNotEmpty ||
        _normalizeSelectedLocationValue(_filterCity).isNotEmpty;
  }

  String get _resultsLocationLabel {
    final city = _filterCity?.trim();
    if (city != null && city.isNotEmpty) return city;
    final district = _filterDistrict?.trim();
    if (district != null && district.isNotEmpty) return district;
    return 'selected location';
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

  List<Map<String, dynamic>> get _displayServices {
    final validated = _services.where(_isValidService).toList();
    return validated.take(8).toList();
  }

  List<Map<String, dynamic>> get _filteredProviders {
    final providersByKey = <String, Map<String, dynamic>>{};
    for (final service in _services) {
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
          'profession': (service['provider_profession'] ?? '').toString(),
          'city': (service['provider_city'] ?? '').toString(),
          'district': (service['provider_district'] ?? '').toString(),
          'verification_status':
              (service['provider_verification_status'] ?? 'unverified')
                  .toString(),
          'is_verified': service['provider_is_verified'] == true,
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

  Future<void> _loadData() async {
    setState(() {
      _loadingData = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getServices(),
        ApiService.getUserBookings(),
        ApiService.getCustomerNotifications(),
      ]);
      if (mounted) {
        final services = <Map<String, dynamic>>[];
        for (final item in List<dynamic>.from(results[0])) {
          if (item is Map<String, dynamic>) {
            services.add(item);
            continue;
          }
          if (item is Map) {
            services.add(Map<String, dynamic>.from(item));
          }
        }
        final bookings = List<dynamic>.from(results[1]);
        final notifications = results[2];
        setState(() {
          _services = services;
          _bookings = bookings;
          _notificationCount = notifications.length;
          _loadingData = false;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        if (e is SessionExpiredException ||
            e.toString().contains('token not valid') ||
            e.toString().contains('SESSION_EXPIRED') ||
            e.toString().toLowerCase().contains('log in again')) {
          await TokenStorage.clearTokens();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPrototypeScreen()),
            (_) => false,
          );
          return;
        }
        final isConnectionError = e.toString().contains('Connection refused') ||
            e.toString().contains('Connection timed out') ||
            e.toString().contains('SocketException') ||
            e.toString().contains('Failed host lookup');
        setState(() {
          _services = [];
          _bookings = [];
          _notificationCount = 0;
          _loadingData = false;
          _loadError = isConnectionError
              ? 'Cannot reach server. Start the backend: python manage.py runserver 0.0.0.0:8000'
              : e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        });
      }
    }
  }

  void _openPlaceOrder(String serviceId, String serviceTitle) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceOrderScreen(
          categoryId: serviceId,
          categoryTitle: serviceTitle,
          categoryIcon: Icons.build_circle_outlined,
          serviceId: int.tryParse(serviceId),
          serviceTitle: serviceTitle,
        ),
      ),
    );
  }

  void _openProvider(Map<String, dynamic> provider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopDetailScreen(provider: provider),
      ),
    );
  }

  String get _locationScopeLabel {
    if (_filterDistrict == null && _filterCity == null) {
      return AppStrings.t(context, 'allServicesAvailable');
    }
    if (_filterDistrict != null && _filterCity != null) {
      return '$_filterDistrict, $_filterCity';
    }
    if (_filterDistrict != null) {
      return '${AppStrings.t(context, 'district')}: $_filterDistrict';
    }
    return '${AppStrings.t(context, 'city')}: $_filterCity';
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?['username'] ?? _user?['email'] ?? 'User';
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadUser();
            await _loadData();
          },
          color: AppTheme.customerPrimary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(name),
                if (_loadError != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Material(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange.shade800, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _loadError!,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _buildLocationBar(),
                _buildAiAssistantEntry(context),
                _buildCarousel(),
                _buildPopularServices(),
                _buildUpcomingBooking(),
                _buildReferBanner(),
                _buildNewRequestSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const CustomerProfileTabScreen()),
              ),
              borderRadius: BorderRadius.circular(24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.customerPrimary.withOpacity(0.2),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.customerPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGrey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppTheme.darkGrey),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustomerSearchScreen()),
            ),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: _notificationCount > 0,
              smallSize: 8,
              child: const Icon(Icons.notifications_outlined,
                  color: AppTheme.darkGrey),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const CustomerNotificationsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () async {
            final result =
                await Navigator.of(context).push<LocationFilterResult?>(
              MaterialPageRoute(
                builder: (_) => LocationServicesScreen(
                  initialDistrict: _filterDistrict,
                  initialCity: _filterCity,
                ),
              ),
            );
            if (result != null && mounted) {
              setState(() {
                _filterDistrict = result.district;
                _filterCity = result.city;
              });
              if ((result.district?.trim().isNotEmpty ?? false) ||
                  (result.city?.trim().isNotEmpty ?? false)) {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FilteredResultsScreen(
                      initialDistrict: result.district,
                      initialCity: result.city,
                    ),
                  ),
                );
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined,
                    color: Colors.grey[600], size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _locationScopeLabel,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiAssistantEntry(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Material(
        color: AppTheme.customerPrimary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: AppTheme.customerPrimary, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t(context, 'aiAssistant'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.t(
                            context, 'askInYourOwnWordsSearchProvidersFirst'),
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const List<String> _carouselImageUrls = [
    'https://picsum.photos/seed/hamrosewa1/400/160',
    'https://picsum.photos/seed/hamrosewa2/400/160',
    'https://picsum.photos/seed/hamrosewa3/400/160',
  ];

  Widget _buildCarousel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: PageView.builder(
                itemCount: 3,
                onPageChanged: (i) => setState(() => _carouselIndex = i),
                itemBuilder: (context, index) {
                  return Image.network(
                    _carouselImageUrls[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 160,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: AppTheme.customerPrimary.withOpacity(0.15),
                        child: Center(
                          child: AppShimmerLoader(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    (loadingProgress.expectedTotalBytes ?? 1)
                                : null,
                            color: AppTheme.customerPrimary,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppTheme.customerPrimary.withOpacity(0.15),
                        child: Center(
                          child: Icon(
                            index == 0
                                ? Icons.home_repair_service
                                : Icons.image_not_supported_outlined,
                            size: 56,
                            color: AppTheme.customerPrimary.withOpacity(0.6),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _carouselIndex == i
                      ? AppTheme.customerPrimary
                      : Colors.grey[300],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularServices() {
    final items = _displayServices;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.t(context, 'popularServices'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 12),
          _loadingData
              ? const SizedBox(
                  height: 140,
                  child: Center(
                      child: AppShimmerLoader(color: AppTheme.customerPrimary)))
              : SizedBox(
                  height: 140,
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            (_filterDistrict != null || _filterCity != null)
                                ? AppStrings.t(
                                    context,
                                    'noServiceProvidersAvailableInThisLocation',
                                  )
                                : AppStrings.t(context, 'noServicesAvailable'),
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[600]),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final s = items[index] as Map<String, dynamic>;
                            final id = (s['id'] ?? s['id']?.toString() ?? '')
                                .toString();
                            final title = (s['title'] ?? '').toString();
                            final category =
                                (s['category_name'] ?? s['category'] ?? '')
                                    .toString();
                            final provider =
                                (s['provider_name'] ?? '').toString().trim();
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Material(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () => _openPlaceOrder(id, title),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 160,
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 64,
                                          decoration: BoxDecoration(
                                            color: AppTheme.customerPrimary
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                                Icons.build_circle_outlined,
                                                size: 32,
                                                color:
                                                    AppTheme.customerPrimary),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          title,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          [
                                            if (category.isNotEmpty) category,
                                            if (provider.isNotEmpty) provider,
                                          ].join(' • '),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600]),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ],
      ),
    );
  }

  Widget _buildFilteredResultsBanner() {
    final providerCount = _filteredProviders.length;
    final serviceCount = _services.length;
    final summary = _loadingData
        ? 'Loading services for $_locationScopeLabel'
        : 'Showing $serviceCount services from $providerCount providers in $_locationScopeLabel';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
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
                    'Filtered results for $_resultsLocationLabel',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProvidersSection() {
    final providers = _filteredProviders;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Providers in $_resultsLocationLabel',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingData)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: AppShimmerLoader(
                  color: AppTheme.customerPrimary,
                ),
              ),
            )
          else if (providers.isEmpty)
            Center(
              child: Text(
                'No providers found in $_resultsLocationLabel.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            )
          else
            ListView.separated(
              itemCount: providers.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final provider = providers[index];
                final name = (provider['username'] ?? 'Provider').toString();
                final profession =
                    (provider['profession'] ?? '').toString().trim();
                final city = (provider['city'] ?? '').toString().trim();
                final district = (provider['district'] ?? '').toString().trim();
                final isVerified = (provider['verification_status'] ?? '')
                        .toString()
                        .toLowerCase()
                        .trim() ==
                    'approved';
                final locationText = city.isNotEmpty
                    ? city
                    : district.isNotEmpty
                        ? district
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
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildServicesSection() {
    final items = _displayServices;
    if (_hasLocationFilter) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Services in $_resultsLocationLabel',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: AppShimmerLoader(
                    color: AppTheme.customerPrimary,
                  ),
                ),
              )
            else if (items.isEmpty)
              Center(
                child: Text(
                  'No services found in $_resultsLocationLabel.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              )
            else
              ListView.separated(
                itemCount: items.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final service = items[index];
                  final id = (service['id'] ?? '').toString();
                  final title = (service['title'] ?? '').toString();
                  final category =
                      (service['category_name'] ?? service['category'] ?? '')
                          .toString();
                  final provider =
                      (service['provider_name'] ?? 'Provider').toString();
                  final location =
                      (service['location'] ?? '').toString().trim();
                  return Material(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => _openPlaceOrder(id, title),
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
                                color:
                                    AppTheme.customerPrimary.withOpacity(0.14),
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
                                    ].join(' • '),
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
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.t(context, 'popularServices'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 12),
          _loadingData
              ? const SizedBox(
                  height: 140,
                  child: Center(
                    child: AppShimmerLoader(
                      color: AppTheme.customerPrimary,
                    ),
                  ),
                )
              : SizedBox(
                  height: 140,
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            AppStrings.t(context, 'noServicesAvailable'),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final service = items[index];
                            final id = (service['id'] ?? '').toString();
                            final title = (service['title'] ?? '').toString();
                            final category = (service['category_name'] ??
                                    service['category'] ??
                                    '')
                                .toString();
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Material(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () => _openPlaceOrder(id, title),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 160,
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 64,
                                          decoration: BoxDecoration(
                                            color: AppTheme.customerPrimary
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.build_circle_outlined,
                                              size: 32,
                                              color: AppTheme.customerPrimary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          category,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ],
      ),
    );
  }

  Widget _buildUpcomingBooking() {
    final today = nepalNow();
    final todayDate = DateTime(today.year, today.month, today.day);
    final upcoming = _bookings.where((b) {
      final status = ((b as Map)['status'] as String?)?.toLowerCase() ?? '';
      if (status == 'cancelled' ||
          status == 'rejected' ||
          status == 'completed') {
        return false;
      }
      final dateStr = b['booking_date']?.toString();
      final timeStr = b['booking_time']?.toString();
      if (dateStr == null || dateStr.isEmpty) return true;
      final dt = parseBookingDateTime(dateStr, timeStr);
      if (dt == null) return true;
      final bookingDate = DateTime(dt.year, dt.month, dt.day);
      return !bookingDate.isBefore(todayDate);
    }).toList();
    upcoming.sort((a, b) {
      final aDate = parseBookingDateTime((a as Map)['booking_date']?.toString(),
          (a)['booking_time']?.toString());
      final bDate = parseBookingDateTime((b as Map)['booking_date']?.toString(),
          (b)['booking_time']?.toString());
      if (aDate == null || bDate == null) return 0;
      return aDate.compareTo(bDate);
    });
    final booking =
        upcoming.isNotEmpty ? upcoming.first as Map<String, dynamic> : null;
    final serviceTitle = booking?['service_title']?.toString() ?? '';
    final bookingDate = booking?['booking_date']?.toString() ?? '';
    final bookingTime = booking?['booking_time']?.toString() ?? '';
    final status = (booking?['status'] ?? '').toString().trim().toLowerCase();
    final paymentStatus = _derivePaymentStatus(booking);
    String dateTimeStr = '';
    if (bookingDate.isNotEmpty) {
      final dt = parseBookingDateTime(bookingDate, bookingTime);
      if (dt != null) {
        dateTimeStr = '${AppStrings.t(context, 'date')}: ${_formatDate(dt)}';
        dateTimeStr +=
            '  ${AppStrings.t(context, 'time')}: ${_formatTime('${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:00')}';
      } else {
        dateTimeStr = '${AppStrings.t(context, 'date')}: $bookingDate';
        if (bookingTime.isNotEmpty) {
          dateTimeStr +=
              '  ${AppStrings.t(context, 'time')}: ${_formatTime(bookingTime)}';
        }
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.t(context, 'upcomingBooking'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 12),
          if (booking == null)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    AppStrings.t(context, 'noUpcomingBookings'),
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ),
              ),
            )
          else
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                serviceTitle.isEmpty ? 'Booking' : serviceTitle,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkGrey,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                dateTimeStr.isEmpty ? '—' : dateTimeStr,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Booking Status: ',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[700]),
                                  ),
                                  Text(
                                    _statusLabel(status),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _bookingStatusColor(status),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.payment_outlined,
                                      size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Payment Status: ',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[700]),
                                  ),
                                  Text(
                                    _statusLabel(paymentStatus),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _paymentStatusColor(paymentStatus),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () =>
                              _showUpcomingBookingSheet(context, booking),
                          borderRadius: BorderRadius.circular(24),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                AppTheme.customerPrimary.withOpacity(0.2),
                            child: const Icon(Icons.person,
                                color: AppTheme.customerPrimary),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () =>
                              _confirmCancelBooking(context, booking),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppTheme.customerPrimary.withOpacity(0.2),
                            foregroundColor: AppTheme.customerPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showUpcomingBookingSheet(
      BuildContext context, Map<String, dynamic> booking) {
    final serviceTitle =
        booking['service_title'] ?? booking['title'] ?? 'Service';
    final providerName = booking['provider_name'] ?? 'Provider';
    final status = ((booking['status'] as String?) ?? '').toLowerCase().trim();
    final paymentStatus = _derivePaymentStatus(booking);
    final bookingDate = booking['booking_date']?.toString() ?? '—';
    final bookingTime = booking['booking_time']?.toString() ?? '—';
    final amount = booking['total_amount'];
    final amountStr =
        amount != null ? 'Rs ${(amount as num).toStringAsFixed(0)}' : '—';
    final bookingId = booking['id']?.toString() ?? '';
    final email = (booking['provider_email'] as String?)?.trim() ?? '';
    final phone = (booking['provider_phone'] as String?)?.trim() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              serviceTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _detailRow(AppStrings.t(context, 'provider'), providerName),
            _detailRow(AppStrings.t(context, 'status'), _statusLabel(status)),
            _detailRow(
                AppStrings.t(context, 'payment'), _statusLabel(paymentStatus)),
            _detailRow(AppStrings.t(context, 'date'), bookingDate),
            _detailRow(AppStrings.t(context, 'time'), bookingTime),
            _detailRow(AppStrings.t(context, 'amount'), amountStr),
            const SizedBox(height: 16),
            if (phone.isNotEmpty || email.isNotEmpty) ...[
              Text(
                AppStrings.t(context, 'contactProvider'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              if (phone.isNotEmpty)
                ListTile(
                  leading:
                      const Icon(Icons.phone, color: AppTheme.customerPrimary),
                  title: Text(AppStrings.t(context, 'callNow')),
                  subtitle: Text(phone),
                  onTap: () async {
                    final uri = Uri(scheme: 'tel', path: phone);
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                    if (context.mounted) Navigator.pop(ctx);
                  },
                ),
              if (email.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.email_outlined,
                      color: AppTheme.customerPrimary),
                  title: Text(AppStrings.t(context, 'email')),
                  subtitle: Text(email),
                  onTap: () async {
                    final uri = Uri.parse('mailto:$email');
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                    if (context.mounted) Navigator.pop(ctx);
                  },
                ),
              const SizedBox(height: 8),
            ],
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.t(context, 'close')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _derivePaymentStatus(Map<String, dynamic>? booking) {
    final rawPayment =
        ((booking?['payment_status'] ?? '').toString()).trim().toLowerCase();
    if (rawPayment.isNotEmpty) return rawPayment;

    final bookingStatus =
        ((booking?['status'] ?? '').toString()).trim().toLowerCase();
    if (bookingStatus == 'paid' ||
        bookingStatus == 'completed' ||
        bookingStatus == 'refunded' ||
        bookingStatus == 'refund_pending' ||
        bookingStatus == 'refund_rejected') {
      return bookingStatus == 'paid' || bookingStatus == 'completed'
          ? 'completed'
          : bookingStatus;
    }
    return 'pending';
  }

  String _statusLabel(String value) {
    final raw = value.trim().toLowerCase();
    if (raw.isEmpty) return '—';
    switch (raw) {
      case 'awaiting_payment':
        return 'Awaiting Payment';
      case 'cancel_req':
        return 'Cancellation Requested';
      case 'refund_p_approved':
        return 'Refund Provider Approved';
      case 'refund_p_rejected':
        return 'Refund Provider Rejected';
      case 'refund_pending':
        return 'Refund Pending';
      case 'refund_rejected':
        return 'Refund Rejected';
      default:
        return raw
            .split('_')
            .map(
                (p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
            .join(' ');
    }
  }

  Color _bookingStatusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'accepted':
      case 'confirmed':
      case 'paid':
      case 'completed':
      case 'refunded':
        return Colors.green;
      case 'cancelled':
      case 'rejected':
      case 'refund_rejected':
      case 'refund_p_rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Color _paymentStatusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'completed':
      case 'refunded':
        return Colors.green;
      case 'failed':
      case 'refund_rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Future<void> _confirmCancelBooking(
      BuildContext context, Map<String, dynamic> booking) async {
    final id = booking['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.t(context, 'cancelBookingQuestion')),
        content: Text(
          AppStrings.t(context, 'cancelUpcomingBookingHint'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.t(context, 'no')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.t(context, 'yesCancel'),
                style: TextStyle(color: Colors.red[700])),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.updateBookingStatus(id, 'cancelled');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t(context, 'bookingCancelled'))),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${AppStrings.t(context, 'failedToCancel')}: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  static String _formatDate(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String _formatTime(String t) {
    if (t.isEmpty) return '';
    if (t.length >= 5 && t.contains(':')) {
      final parts = t.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m =
          parts.length > 1 ? int.tryParse(parts[1].substring(0, 2)) ?? 0 : 0;
      final period = h >= 12 ? 'PM' : 'AM';
      final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '$h12:${m.toString().padLeft(2, '0')} $period';
    }
    return t;
  }

  Future<void> _shareReferralFromHome() async {
    if (_sharingReferral) return;
    setState(() => _sharingReferral = true);

    try {
      final profile = await ApiService.getReferralProfile();
      final code = profile['referral_code'] as String?;

      if (code == null || code.trim().isEmpty) {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ReferralLoyaltyScreen()),
        );
        return;
      }

      final message = ReferralShareContent.buildMessage(code);
      final waUri = Uri.parse(
        'https://wa.me/?text=${Uri.encodeComponent(message)}',
      );

      var launched = false;
      try {
        launched = await launchUrl(
          waUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        launched = false;
      }

      if (!launched) {
        // Fallback: copy message so user can paste into WhatsApp/Messenger.
        await Clipboard.setData(ClipboardData(text: message));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Referral message copied. Paste it in WhatsApp/Messenger.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load your referral code. Please open Referral & Loyalty and try again.',
          ),
        ),
      );
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ReferralLoyaltyScreen()),
      );
    } finally {
      if (mounted) setState(() => _sharingReferral = false);
    }
  }

  Widget _buildReferBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Material(
        color: AppTheme.customerPrimary,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.t(context, 'referFriendsEarnPoints'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.t(context, 'inviteFriendsEarnRewards'),
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _sharingReferral ? null : _shareReferralFromHome,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.white,
                    side: const BorderSide(color: AppTheme.white),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _sharingReferral
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: AppShimmerLoader(
                            strokeWidth: 2,
                            color: AppTheme.white,
                          ),
                        )
                      : Text(AppStrings.t(context, 'inviteNow')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewRequestSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.t(context, 'findServices'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.t(context, 'browseCategoriesAndBookService'),
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const CustomerCategoriesTabScreen()),
            ),
            icon: const Icon(Icons.grid_view_rounded, size: 20),
            label: Text(AppStrings.t(context, 'browseCategories')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.customerPrimary,
              side: const BorderSide(color: AppTheme.customerPrimary),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
          const SizedBox(height: 24),
          Material(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    AppStrings.t(context, 'cantFindServiceAskAdmin'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CustomerNewRequestScreen(),
                      ),
                    ),
                    child: Text(
                      AppStrings.t(context, 'newRequest'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
