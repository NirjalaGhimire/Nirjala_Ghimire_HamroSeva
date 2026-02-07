import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';

/// Full UI: Location / All services available – select area and service scope.
class LocationServicesScreen extends StatefulWidget {
  const LocationServicesScreen({super.key});

  @override
  State<LocationServicesScreen> createState() => _LocationServicesScreenState();
}

class _LocationServicesScreenState extends State<LocationServicesScreen> {
  String _selectedScope = 'All services available';
  final List<Map<String, String>> _areas = [
    {'id': 'all', 'name': 'All services available'},
    {'id': 'kathmandu', 'name': 'Kathmandu'},
    {'id': 'lalitpur', 'name': 'Lalitpur'},
    {'id': 'bhaktapur', 'name': 'Bhaktapur'},
    {'id': 'pokhara', 'name': 'Pokhara'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Location & services', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _areas.length,
        itemBuilder: (context, index) {
          final a = _areas[index];
          final selected = _selectedScope == a['name'];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: selected ? AppTheme.customerPrimary : Colors.grey[300]!,
                width: selected ? 2 : 1,
              ),
            ),
            child: ListTile(
              leading: Icon(
                Icons.location_on_outlined,
                color: selected ? AppTheme.customerPrimary : Colors.grey,
              ),
              title: Text(
                a['name']!,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? AppTheme.customerPrimary : AppTheme.darkGrey,
                ),
              ),
              trailing: selected ? const Icon(Icons.check_circle, color: AppTheme.customerPrimary) : null,
              onTap: () {
                setState(() => _selectedScope = a['name']!);
                Navigator.of(context).pop(_selectedScope);
              },
            ),
          );
        },
      ),
    );
  }
}
