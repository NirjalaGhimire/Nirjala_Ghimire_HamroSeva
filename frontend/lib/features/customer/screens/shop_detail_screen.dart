import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/place_order_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
  Map<String, dynamic>? _profile;
  Map<String, dynamic> _profileSummary = const {};
  List<Map<String, dynamic>> _services = [];
  Set<int> _favoriteServiceIds = <int>{};
  Set<int> _favoriteProviderIds = <int>{};
  bool _loadingServices = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    if (widget.provider != null) _loadServices();
    _loadFavoriteSummary();
  }

  Future<void> _loadProfile() async {
    final prov = widget.provider;
    if (prov == null) return;
    final providerId = prov['id'] is int
        ? prov['id'] as int
        : int.tryParse((prov['id'] ?? '').toString());
    if (providerId == null) return;
    try {
      final profile = await ApiService.getProviderProfile(providerId);
      if (!mounted) return;
      setState(() {
        _profile = profile['user'] is Map
            ? Map<String, dynamic>.from(profile['user'] as Map)
            : Map<String, dynamic>.from(prov);
        _profileSummary = profile['summary'] is Map
            ? Map<String, dynamic>.from(profile['summary'] as Map)
            : const {};
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _profile = Map<String, dynamic>.from(prov);
          _profileSummary = const {};
        });
      }
    }
  }

  Future<void> _loadFavoriteSummary() async {
    try {
      final summary = await ApiService.getFavoritesSummary();
      final serviceIds = <int>{};
      for (final v
          in List<dynamic>.from(summary['favorite_service_ids'] ?? [])) {
        final n = v is int ? v : int.tryParse(v.toString());
        if (n != null) serviceIds.add(n);
      }
      final providerIds = <int>{};
      for (final v
          in List<dynamic>.from(summary['favorite_provider_ids'] ?? [])) {
        final n = v is int ? v : int.tryParse(v.toString());
        if (n != null) providerIds.add(n);
      }
      if (mounted) {
        setState(() {
          _favoriteServiceIds = serviceIds;
          _favoriteProviderIds = providerIds;
        });
      }
    } catch (_) {
      // Ignore heart-state errors; shop detail remains available.
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

  Future<void> _loadServices() async {
    final prov = widget.provider;
    if (prov == null) return;
    setState(() => _loadingServices = true);
    try {
      final categories = await ApiService.getCategories();
      if (categories.isEmpty) {
        if (mounted)
          setState(() {
            _services = [];
            _loadingServices = false;
          });
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
      if (mounted)
        setState(() {
          _services = allServices;
          _loadingServices = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _services = [];
          _loadingServices = false;
        });
    }
  }

  Future<void> _contactProvider() async {
    final p = _profile ?? widget.provider;
    if (p == null) return;

    final phone = (p['phone'] ?? p['provider_phone'] ?? '').toString().trim();
    final email = (p['email'] ?? p['provider_email'] ?? '').toString().trim();

    try {
      if (phone.isNotEmpty) {
        final uri = Uri.parse('tel:$phone');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      if (email.isNotEmpty) {
        final uri = Uri.parse('mailto:$email');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppStrings.t(context, 'contactDetailsNotAvailableForProvider')),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.t(context, 'couldNotOpenContactDetails')}: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile ?? widget.provider;
    if (p == null) {
      return Scaffold(
        backgroundColor: AppTheme.white,
        appBar: AppBar(
          title: Text(AppStrings.t(context, 'providerProfile'),
              style: TextStyle(
                  color: AppTheme.white, fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.customerPrimary,
          foregroundColor: AppTheme.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              AppStrings.t(context, 'openShopFromListToSeeDetails'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
          ),
        ),
      );
    }

    final name = (p['username'] ?? 'Provider').toString();
    final providerId = p['id'] is int
        ? p['id'] as int
        : int.tryParse((p['id'] ?? '').toString());
    final profession = (p['profession'] ?? '').toString().trim();
    final qualification = (p['qualification'] ?? '').toString().trim();
    final imageUrl = (p['profile_image_url'] ?? '').toString().trim();
    final district = (p['district'] ?? '').toString().trim();
    final city = (p['city'] ?? '').toString().trim();
    final verificationStatus =
        (p['verification_status'] ?? '').toString().toLowerCase().trim();
    final isVerified = verificationStatus == 'approved';
    final ratingAverage = (() {
      final value = _profileSummary['rating_average'];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    })();
    final ratingCount = (() {
      final value = _profileSummary['rating_count'];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    })();

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'providerProfile'),
            style:
                TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        actions: [
          if (providerId != null)
            IconButton(
              icon: Icon(
                _favoriteProviderIds.contains(providerId)
                    ? Icons.favorite
                    : Icons.favorite_border,
              ),
              onPressed: () => _toggleProviderFavorite(providerId),
              tooltip: AppStrings.t(context, 'favouriteProvider'),
            ),
        ],
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
                      backgroundColor:
                          AppTheme.customerPrimary.withOpacity(0.15),
                      child: imageUrl.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                imageUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'P',
                                  style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.customerPrimary),
                                ),
                              ),
                            )
                          : Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'P',
                              style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.customerPrimary),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    if (profession.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.work_outline,
                              size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(profession,
                              style: TextStyle(color: Colors.grey[700])),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      qualification.isNotEmpty
                          ? qualification
                          : AppStrings.t(context, 'qualificationNotProvided'),
                      style: TextStyle(color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                    if (district.isNotEmpty || city.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        [district, city]
                            .where((value) => value.isNotEmpty)
                            .join(', '),
                        style: TextStyle(color: Colors.grey[700]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isVerified
                            ? Colors.green.withOpacity(0.12)
                            : Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isVerified
                            ? AppStrings.t(context, 'verified')
                            : AppStrings.t(context, 'unverified'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isVerified
                              ? Colors.green[800]
                              : Colors.orange[800],
                        ),
                      ),
                    ),
                    if (ratingCount > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '${ratingAverage.toStringAsFixed(1)} ($ratingCount ${AppStrings.t(context, ratingCount == 1 ? 'reviewSingular' : 'reviewPlural')})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(AppStrings.t(context, 'servicesFromThisProvider'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_loadingServices)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child: AppShimmerLoader(
                          color: AppTheme.customerPrimary)))
            else if (_services.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(AppStrings.t(context, 'noServicesListedYet'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              )
            else
              ..._services.map((s) => _serviceTile(s)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _contactProvider,
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(AppStrings.t(context, 'contactProvider')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.customerPrimary,
                  foregroundColor: AppTheme.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceTile(Map<String, dynamic> service) {
    final label = (service['title'] ??
            service['service_name'] ??
            service['name'] ??
            AppStrings.t(context, 'service'))
        .toString();
    final serviceId = service['id'] is int
        ? service['id'] as int
        : int.tryParse((service['id'] ?? '').toString());
    final categoryId = (service['category_id'] ?? '').toString();
    final categoryName = (service['category_name'] ?? '').toString();
    final isFav = serviceId != null && _favoriteServiceIds.contains(serviceId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.customerPrimary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          dense: true,
          title: Text(label),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: AppTheme.linkRed,
                ),
                onPressed: serviceId == null
                    ? null
                    : () => _toggleServiceFavorite(serviceId),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right,
                    color: AppTheme.customerPrimary),
                onPressed: serviceId == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlaceOrderScreen(
                              categoryId: categoryId,
                              categoryTitle:
                                  categoryName.isEmpty ? label : categoryName,
                              categoryIcon: Icons.build_circle_outlined,
                              serviceId: serviceId,
                              serviceTitle: label,
                              price: 0,
                            ),
                          ),
                        );
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
