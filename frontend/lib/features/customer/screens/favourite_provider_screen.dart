import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/shop_detail_screen.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/select_provider_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Favourite Providers – backend-persisted provider favorites for current customer.
class FavouriteProviderScreen extends StatefulWidget {
  const FavouriteProviderScreen({super.key});

  @override
  State<FavouriteProviderScreen> createState() =>
      _FavouriteProviderScreenState();
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

  Future<void> _removeProvider(int providerId) async {
    setState(() => _providers = _providers
        .where(
            (p) => (p['provider_id'] ?? -1).toString() != providerId.toString())
        .toList());
    try {
      await ApiService.removeFavoriteProvider(providerId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.t(context, 'couldNotRemoveProvider')}: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
      _load();
    }
  }

  void _openProviderProfile(Map<String, dynamic> provider) {
    final p = <String, dynamic>{
      'id': provider['provider_id'],
      'username': provider['provider_name'],
      'profession': provider['provider_profession'],
      'profile_image_url': provider['profile_image_url'],
      'verification_status': provider['verification_status'],
      'district': provider['district'],
      'city': provider['city'],
    };
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ShopDetailScreen(provider: p)),
    );
  }

  void _bookProvider(Map<String, dynamic> provider) {
    final categoryId = (provider['category_id'] ?? '').toString();
    final categoryName = (provider['category_name'] ?? '').toString();
    if (categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppStrings.t(context, 'noCategoryForProviderYet'))),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SelectProviderScreen(
          categoryId: categoryId,
          categoryTitle: categoryName.isEmpty
              ? AppStrings.t(context, 'service')
              : categoryName,
          categoryIcon: Icons.build_circle_outlined,
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getFavoriteProviders();
      final providers = <Map<String, dynamic>>[];
      for (final row in List<dynamic>.from(list)) {
        if (row is Map<String, dynamic>) {
          providers.add(Map<String, dynamic>.from(row));
        } else if (row is Map) {
          providers.add(Map<String, dynamic>.from(row));
        }
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
        title: Text(AppStrings.t(context, 'favouriteProviders'),
            style:
                TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
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
          ? const Center(
              child: AppShimmerLoader(color: AppTheme.customerPrimary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red[700])),
                        const SizedBox(height: 16),
                        TextButton(
                            onPressed: _load,
                            child: Text(AppStrings.t(context, 'retry'))),
                      ],
                    ),
                  ),
                )
              : _providers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_outline,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(AppStrings.t(context, 'noFavouriteProvidersYet'),
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey[600])),
                          const SizedBox(height: 8),
                          Text(
                              AppStrings.t(context, 'tapHeartProviderProfiles'),
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _providers.length,
                      itemBuilder: (context, index) {
                        final p = _providers[index];
                        final providerId =
                            int.tryParse((p['provider_id'] ?? '').toString());
                        final providerName = (p['provider_name'] ??
                                AppStrings.t(context, 'provider'))
                            .toString();
                        final categoryName =
                            (p['category_name'] ?? '').toString();
                        final profession =
                            (p['provider_profession'] ?? '').toString();
                        final ratingAverage = p['rating_average'];
                        final ratingCount = int.tryParse(
                                (p['rating_count'] ?? '0').toString()) ??
                            0;
                        final isVerified = p['is_verified'] == true;
                        final isAvailable = p['is_available'] != false;
                        final unavailableReason =
                            (p['unavailable_reason'] ?? '').toString();
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
                              backgroundColor:
                                  AppTheme.customerPrimary.withOpacity(0.2),
                              child: Text(
                                (providerName.isNotEmpty
                                        ? providerName[0]
                                        : 'U')
                                    .toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.customerPrimary),
                              ),
                            ),
                            title: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  providerName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                if (isVerified)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      AppStrings.t(context, 'verified'),
                                      style: TextStyle(
                                        color: Colors.green[800],
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (categoryName.isNotEmpty ||
                                    profession.isNotEmpty)
                                  Text(
                                    categoryName.isNotEmpty
                                        ? categoryName
                                        : profession,
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  ratingCount > 0 && ratingAverage != null
                                      ? '${AppStrings.t(context, 'rating')} ${ratingAverage.toString()} ($ratingCount)'
                                      : AppStrings.t(context, 'noRatingsYet'),
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                ),
                                if (!isAvailable)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      unavailableReason.isEmpty
                                          ? AppStrings.t(context, 'unavailable')
                                          : unavailableReason,
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.red[700]),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: SizedBox(
                              width: 120,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.visibility_outlined,
                                        color: AppTheme.customerPrimary),
                                    iconSize: 24,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                        width: 36, height: 36),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _openProviderProfile(p),
                                    tooltip:
                                        AppStrings.t(context, 'viewProfile'),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.event_available_outlined,
                                        color: AppTheme.customerPrimary),
                                    iconSize: 24,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                        width: 36, height: 36),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: isAvailable
                                        ? () => _bookProvider(p)
                                        : null,
                                    tooltip:
                                        AppStrings.t(context, 'bookService'),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.favorite,
                                        color: AppTheme.linkRed),
                                    iconSize: 24,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                        width: 36, height: 36),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: providerId == null
                                        ? null
                                        : () => _removeProvider(providerId),
                                    tooltip: AppStrings.t(
                                        context, 'removeFromFavourites'),
                                  ),
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
