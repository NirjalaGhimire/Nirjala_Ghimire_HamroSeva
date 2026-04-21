import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Result returned to [CustomerHomeTabScreen] for provider/service filtering.
/// Both null = show all providers (no location filter).
class LocationFilterResult {
  const LocationFilterResult({this.district, this.city});

  final String? district;
  final String? city;

  String label(BuildContext context) {
    if (district == null && city == null) {
      return AppStrings.t(context, 'allServicesAvailable');
    }
    if (district != null && city != null) return '$district, $city';
    if (district != null) {
      return '${AppStrings.t(context, 'district')}: $district';
    }
    return '${AppStrings.t(context, 'city')}: $city';
  }
}

/// Pick district (optional), then city (optional), then Apply.
/// Values come from registered providers in the database — not a fixed city list.
class LocationServicesScreen extends StatefulWidget {
  const LocationServicesScreen({
    super.key,
    this.initialDistrict,
    this.initialCity,
  });

  final String? initialDistrict;
  final String? initialCity;

  @override
  State<LocationServicesScreen> createState() => _LocationServicesScreenState();
}

class _LocationServicesScreenState extends State<LocationServicesScreen> {
  List<String> _districts = [];
  List<String> _cities = [];
  bool _districtsLoading = true;
  bool _citiesLoading = false;

  String? _selectedDistrict;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _selectedDistrict = widget.initialDistrict?.trim().isEmpty == true
        ? null
        : widget.initialDistrict?.trim();
    _selectedCity = widget.initialCity?.trim().isEmpty == true
        ? null
        : widget.initialCity?.trim();
    _loadDistricts();
    _loadCities();
  }

  Future<void> _loadDistricts() async {
    setState(() => _districtsLoading = true);
    try {
      final list = await ApiService.getLocationDistricts();
      if (mounted) {
        setState(() {
          _districts = list;
          final sel = _selectedDistrict;
          if (sel != null && !_districts.contains(sel)) {
            _districts = [..._districts, sel]..sort();
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _districts = []);
    } finally {
      if (mounted) setState(() => _districtsLoading = false);
    }
  }

  Future<void> _loadCities() async {
    setState(() => _citiesLoading = true);
    try {
      final list =
          await ApiService.getLocationCities(district: _selectedDistrict);
      if (mounted) {
        setState(() {
          _cities = list;
          final sel = _selectedCity;
          if (sel != null && !_cities.contains(sel)) {
            _cities = [..._cities, sel]..sort();
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cities = []);
    } finally {
      if (mounted) setState(() => _citiesLoading = false);
    }
  }

  void _onDistrictChanged(String? value) {
    setState(() {
      _selectedDistrict = value;
      _selectedCity = null;
    });
    _loadCities();
  }

  void _applyAndPop() {
    Navigator.of(context).pop(
      LocationFilterResult(
        district: _selectedDistrict,
        city: _selectedCity,
      ),
    );
  }

  void _clearAndPop() {
    Navigator.of(context).pop(const LocationFilterResult());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          AppStrings.t(context, 'locationAndServices'),
          style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: ListTile(
              leading:
                  const Icon(Icons.public, color: AppTheme.customerPrimary),
              title: Text(
                AppStrings.t(context, 'allServicesAvailable'),
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(AppStrings.t(
                  context, 'showProvidersFromAllDistrictsAndCities')),
              trailing: const Icon(Icons.chevron_right),
              onTap: _clearAndPop,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppStrings.t(context, 'filterByArea'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.t(context,
                'chooseDistrictFirstThenOptionallyNarrowByCityProvidersAndLocations'),
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          if (_districtsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child:
                    AppShimmerLoader(color: AppTheme.customerPrimary),
              ),
            )
          else
            DropdownButtonFormField<String?>(
              initialValue: _selectedDistrict,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: AppStrings.t(context, 'district'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.map_outlined),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(AppStrings.t(context, 'anyDistrict')),
                ),
                ..._districts.map(
                  (d) => DropdownMenuItem<String?>(value: d, child: Text(d)),
                ),
              ],
              onChanged: _onDistrictChanged,
            ),
          const SizedBox(height: 16),
          if (_citiesLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child:
                    AppShimmerLoader(color: AppTheme.customerPrimary),
              ),
            )
          else
            DropdownButtonFormField<String?>(
              initialValue: _selectedCity,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: AppStrings.t(context, 'city'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(AppStrings.t(context, 'anyCity')),
                ),
                ..._cities.map(
                  (c) => DropdownMenuItem<String?>(value: c, child: Text(c)),
                ),
              ],
              onChanged: (v) => setState(() => _selectedCity = v),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyAndPop,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.customerPrimary,
                foregroundColor: AppTheme.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(AppStrings.t(context, 'applyFilter')),
            ),
          ),
        ],
      ),
    );
  }
}
