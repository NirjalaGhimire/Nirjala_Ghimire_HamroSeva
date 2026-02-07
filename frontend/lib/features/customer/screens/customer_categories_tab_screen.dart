import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_search_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/filter_by_screen.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/select_provider_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Customer Categories tab: loads categories from DB (GET /api/categories/) when possible,
/// so categories match providers/services in the database. Fallback to static list if API fails.
class CustomerCategoriesTabScreen extends StatefulWidget {
  const CustomerCategoriesTabScreen({super.key});

  @override
  State<CustomerCategoriesTabScreen> createState() => _CustomerCategoriesTabScreenState();
}

class _CustomerCategoriesTabScreenState extends State<CustomerCategoriesTabScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  static const List<Map<String, dynamic>> _fallbackCategories = [
    {'id': 'ac_cool', 'title': 'AC Cool', 'icon': Icons.ac_unit},
    {'id': 'automotive', 'title': 'Automot', 'icon': Icons.directions_car},
    {'id': 'carpenter', 'title': 'Carpente', 'icon': Icons.carpenter},
    {'id': 'cleaning', 'title': 'Cleaning', 'icon': Icons.cleaning_services},
    {'id': 'cooking', 'title': 'Cooking', 'icon': Icons.restaurant},
    {'id': 'electrician', 'title': 'Electricia', 'icon': Icons.electrical_services},
    {'id': 'gardener', 'title': 'Gardene', 'icon': Icons.eco},
    {'id': 'laundry', 'title': 'Laundry', 'icon': Icons.local_laundry_service},
    {'id': 'painter', 'title': 'Painter', 'icon': Icons.format_paint},
    {'id': 'pandit', 'title': 'Pandit', 'icon': Icons.self_improvement},
    {'id': 'pest_control', 'title': 'Pest Cor', 'icon': Icons.bug_report},
    {'id': 'photography', 'title': 'Photogra', 'icon': Icons.camera_alt},
    {'id': 'plumber', 'title': 'Plumber', 'icon': Icons.plumbing},
    {'id': 'remote', 'title': 'Remote', 'icon': Icons.laptop},
    {'id': 'salon', 'title': 'Salon', 'icon': Icons.face_retouching_natural},
    {'id': 'sanitization', 'title': 'Sanitizat', 'icon': Icons.medical_services},
    {'id': 'security', 'title': 'Security', 'icon': Icons.security},
    {'id': 'smart_home', 'title': 'Smart Ho', 'icon': Icons.home_repair_service},
    {'id': 'tailor', 'title': 'Tailor', 'icon': Icons.checkroom},
  ];

  /// Map DB category name (lowercase) to icon so grid matches backend categories.
  static IconData _iconForCategoryName(String name) {
    final n = (name ?? '').toString().toLowerCase();
    if (n.contains('clean')) return Icons.cleaning_services;
    if (n.contains('plumb')) return Icons.plumbing;
    if (n.contains('electric')) return Icons.electrical_services;
    if (n.contains('home') && n.contains('service')) return Icons.home_repair_service;
    if (n.contains('beauty') || n.contains('wellness') || n.contains('salon')) return Icons.face_retouching_natural;
    if (n.contains('education') || n.contains('tutor')) return Icons.school;
    if (n.contains('tech')) return Icons.laptop;
    if (n.contains('transport')) return Icons.directions_car;
    if (n.contains('health')) return Icons.medical_services;
    if (n.contains('event') || n.contains('photo') || n.contains('cater')) return Icons.camera_alt;
    return Icons.category;
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final list = await ApiService.getCategories();
      if (list.isEmpty) {
        if (mounted) setState(() { _categories = List.from(_fallbackCategories); _loading = false; });
        return;
      }
      final cats = <Map<String, dynamic>>[];
      for (final c in list) {
        final id = c['id'];
        final name = (c['name'] ?? c['title'] ?? 'Category').toString();
        cats.add({
          'id': id is int ? id.toString() : id.toString(),
          'title': name,
          'icon': _iconForCategoryName(name),
        });
      }
      if (mounted) setState(() { _categories = cats; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _categories = List.from(_fallbackCategories); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text(
          'Categories',
          style: TextStyle(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustomerSearchScreen(hint: 'Search for categories...')),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FilterByScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final id = (cat['id'] ?? '').toString();
                  final title = (cat['title'] ?? 'Category').toString();
                  final icon = cat['icon'] as IconData? ?? Icons.category;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SelectProviderScreen(
                              categoryId: id,
                              categoryTitle: title,
                              categoryIcon: icon,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 36, color: AppTheme.customerPrimary),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                title.length > 10 ? '${title.substring(0, 10)}…' : title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkGrey,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
