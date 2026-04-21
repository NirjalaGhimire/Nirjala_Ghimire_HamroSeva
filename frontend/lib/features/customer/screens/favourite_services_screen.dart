import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/place_order_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Favourite Services – backend-persisted service favorites for current customer.
class FavouriteServicesScreen extends StatefulWidget {
  const FavouriteServicesScreen({super.key});

  @override
  State<FavouriteServicesScreen> createState() =>
      _FavouriteServicesScreenState();
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
      final list = await ApiService.getFavoriteServices();
      final services = <Map<String, dynamic>>[];
      for (final row in List<dynamic>.from(list)) {
        if (row is Map<String, dynamic>) {
          services.add(Map<String, dynamic>.from(row));
        } else if (row is Map) {
          services.add(Map<String, dynamic>.from(row));
        }
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

  Future<void> _removeService(int serviceId) async {
    setState(() {
      _items = _items
          .where(
              (s) => (s['service_id'] ?? -1).toString() != serviceId.toString())
          .toList();
    });
    try {
      await ApiService.removeFavoriteService(serviceId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.t(context, 'couldNotRemoveService')}: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'favouriteServices'),
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
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite_border,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(AppStrings.t(context, 'noFavouritesYet'),
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey[600])),
                          const SizedBox(height: 8),
                          Text(AppStrings.t(context, 'tapHeartServiceCards'),
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final s = _items[index];
                        final title = (s['service_name'] ??
                                AppStrings.t(context, 'service'))
                            .toString();
                        final category = (s['category_name'] ?? '').toString();
                        final provider = (s['provider_name'] ?? '').toString();
                        final serviceId =
                            int.tryParse((s['service_id'] ?? '').toString());
                        final categoryId = (s['category_id'] ?? '').toString();
                        final priceRaw = s['price'];
                        final price = priceRaw is num
                            ? priceRaw.toDouble()
                            : double.tryParse((priceRaw ?? '').toString()) ??
                                0.0;
                        final quoteType =
                            (s['quote_type'] ?? 'fixed').toString();
                        final isAvailable = s['is_available'] != false;
                        final unavailableReason =
                            (s['unavailable_reason'] ?? '').toString();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppTheme.customerPrimary.withOpacity(0.15),
                              child: const Icon(Icons.build_circle_outlined,
                                  color: AppTheme.customerPrimary),
                            ),
                            title: Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  [
                                    if (category.isNotEmpty) category,
                                    if (provider.isNotEmpty) provider,
                                  ].join(' • '),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  quoteType == 'quoted'
                                      ? AppStrings.t(
                                          context, 'quoteBasedPricing')
                                      : 'Rs ${price.toStringAsFixed(0)}',
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
                              width: 96,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right,
                                        color: AppTheme.customerPrimary),
                                    onPressed: (!isAvailable ||
                                            serviceId == null)
                                        ? null
                                        : () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    PlaceOrderScreen(
                                                  categoryId: categoryId,
                                                  categoryTitle:
                                                      category.isEmpty
                                                          ? title
                                                          : category,
                                                  categoryIcon: Icons
                                                      .build_circle_outlined,
                                                  serviceId: serviceId,
                                                  serviceTitle: title,
                                                  price: quoteType == 'quoted'
                                                      ? 0
                                                      : price,
                                                ),
                                              ),
                                            );
                                          },
                                    tooltip: 'Open service',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.favorite,
                                        color: AppTheme.linkRed),
                                    onPressed: serviceId == null
                                        ? null
                                        : () => _removeService(serviceId),
                                    tooltip: 'Remove from favourites',
                                  ),
                                ],
                              ),
                            ),
                            onTap: () {
                              if (!isAvailable || serviceId == null) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PlaceOrderScreen(
                                    categoryId: categoryId,
                                    categoryTitle:
                                        category.isEmpty ? title : category,
                                    categoryIcon: Icons.build_circle_outlined,
                                    serviceId: serviceId,
                                    serviceTitle: title,
                                    price: quoteType == 'quoted' ? 0 : price,
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
