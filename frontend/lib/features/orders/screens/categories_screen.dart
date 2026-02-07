import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/select_provider_screen.dart';

/// Categories screen: grid of service categories (Cleaning, Repairing, Electrician, Carpenter, etc.).
/// Selected category gets blue border; tap to go to Place order.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String? _selectedId;

  static const List<Map<String, dynamic>> _categories = [
    {'id': 'cleaning', 'title': 'Cleaning', 'icon': Icons.cleaning_services},
    {'id': 'repairing', 'title': 'Repairing', 'icon': Icons.build},
    {'id': 'electrician', 'title': 'Electrician', 'icon': Icons.electrical_services},
    {'id': 'carpenter', 'title': 'Carpenter', 'icon': Icons.carpenter},
    {'id': 'plumber', 'title': 'Plumber', 'icon': Icons.plumbing},
    {'id': 'beautician', 'title': 'Beautician', 'icon': Icons.face_retouching_natural},
    {'id': 'driver', 'title': 'Driver', 'icon': Icons.directions_car},
    {'id': 'tutor', 'title': 'Tutor', 'icon': Icons.school},
    {'id': 'photographer', 'title': 'Photographer', 'icon': Icons.camera_alt},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightLavender,
      appBar: AppBar(
        title: const Text('Categories', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
      ),
      body: Padding(
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
            final id = cat['id'] as String;
            final selected = _selectedId == id;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedId = id);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SelectProviderScreen(
                      categoryId: id,
                      categoryTitle: cat['title'] as String,
                      categoryIcon: cat['icon'] as IconData,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? Colors.blue : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(cat['icon'] as IconData, size: 40, color: AppTheme.darkGrey),
                    const SizedBox(height: 8),
                    Text(
                      cat['title'] as String,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkGrey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
