import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/shop_detail_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/widgets/provider_app_bar.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// All Shops: list of providers from database (no mock data).
class AllShopsScreen extends StatefulWidget {
  const AllShopsScreen({super.key});

  @override
  State<AllShopsScreen> createState() => _AllShopsScreenState();
}

class _AllShopsScreenState extends State<AllShopsScreen> {
  List<dynamic> _shops = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getProviders();
      if (mounted) {
        setState(() {
          _shops = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _shops = [];
          _loading = false;
        });
      }
    }
  }

  bool _isVerified(Map<String, dynamic> shop) {
    final status =
        (shop['verification_status'] ?? '').toString().toLowerCase().trim();
    return status == 'approved';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        title: Text(AppStrings.t(context, 'allShops'),
            style:
                TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        elevation: 0,
        shape: providerAppBarShape,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: AppStrings.t(context, 'searchHere'),
                prefixIcon:
                    const Icon(Icons.search, color: AppTheme.customerPrimary),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: AppShimmerLoader(color: AppTheme.customerPrimary))
                : _shops.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.store_outlined,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              AppStrings.t(context, 'noProvidersYet'),
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppStrings.t(context, 'providersWillAppearHere'),
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[500]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadShops,
                        color: AppTheme.customerPrimary,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _shops.length,
                          itemBuilder: (context, index) {
                            final s = _shops[index];
                            final name =
                              (s['username'] ?? s['name'] ?? AppStrings.t(context, 'serviceProvider'))
                                    .toString();
                            final profession =
                                (s['profession'] ?? '').toString().trim();
                            final verified =
                                _isVerified(Map<String, dynamic>.from(s));
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ShopDetailScreen(
                                        provider: Map<String, dynamic>.from(s),
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: AppTheme
                                            .customerPrimary
                                            .withOpacity(0.15),
                                        child: Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : AppStrings.t(context, 'providerInitial'),
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.customerPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            if (profession.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(Icons.work_outline,
                                                      size: 14,
                                                      color: Colors.grey[600]),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      profession,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600]),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            const SizedBox(height: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: verified
                                                    ? Colors.green
                                                        .withOpacity(0.12)
                                                    : Colors.orange
                                                        .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                verified
                                                  ? AppStrings.t(context, 'verified')
                                                  : AppStrings.t(context, 'unverified'),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: verified
                                                      ? Colors.green[800]
                                                      : Colors.orange[800],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right,
                                          color: Colors.grey[600]),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
