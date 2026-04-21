import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Result returned when user confirms location: address + coordinates.
class LocationResult {
  const LocationResult({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
  final String address;
  final double latitude;
  final double longitude;
}

/// Select location: search address (Places autocomplete), pin on map, or use current location.
/// Returns [LocationResult] with address, lat, lng.
class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({
    super.key,
    this.initialAddress,
    this.initialLat,
    this.initialLng,
  });

  final String? initialAddress;
  final double? initialLat;
  final double? initialLng;

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();

  Set<Marker> _markers = {};
  String _address = '';
  double? _latitude;
  double? _longitude;

  bool _searching = false;
  List<Map<String, dynamic>> _predictions = [];
  Timer? _debounce;
  bool _loadingCurrent = false;
  bool _mapReady = false;

  static const LatLng _defaultCenter = LatLng(27.7172, 85.3240); // Kathmandu

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _address = widget.initialAddress!;
      _searchController.text = _address;
    }
    if (widget.initialLat != null && widget.initialLng != null) {
      _latitude = widget.initialLat;
      _longitude = widget.initialLng;
      _updateMarker();
    }
  }

  LatLng get _center {
    if (_latitude != null && _longitude != null) {
      return LatLng(_latitude!, _longitude!);
    }
    return _defaultCenter;
  }

  void _updateMarker() {
    if (_latitude == null || _longitude == null) {
      setState(() => _markers = {});
      return;
    }
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('booking_location'),
          position: LatLng(_latitude!, _longitude!),
          draggable: true,
          onDragEnd: (LatLng pos) {
            _latitude = pos.latitude;
            _longitude = pos.longitude;
            _reverseGeocode(pos.latitude, pos.longitude);
          },
        ),
      };
    });
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
      _updateMarker();
    });
    _reverseGeocode(position.latitude, position.longitude);
  }

  /// Fallback address when reverse geocode fails or returns empty (e.g. billing not enabled).
  String _coordinatesAddress(double lat, double lng) =>
      '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final addr = await ApiService.reverseGeocode(lat, lng);
      if (!mounted) return;
      final useAddress =
          addr.trim().isNotEmpty ? addr : _coordinatesAddress(lat, lng);
      setState(() => _address = useAddress);
      _searchController.text = useAddress;
    } catch (_) {
      if (mounted) {
        final fallback = _coordinatesAddress(lat, lng);
        setState(() => _address = fallback);
        _searchController.text = fallback;
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _predictions = [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _searching = true);
      try {
        final result = await ApiService.getPlacesAutocompleteWithError(value);
        if (!mounted) return;
        final list = result['predictions'] as List<dynamic>? ?? [];
        setState(() {
          _predictions =
              list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _searching = false;
        });
        final err = result['error'] as String?;
        final hint = result['hint'] as String?;
        if (mounted && (err != null && err.isNotEmpty)) {
          String msg = hint != null ? '$err — $hint' : err;
          if (msg.contains('Billing') || msg.length > 120) {
            msg = AppStrings.t(context, 'enableBillingAddressSearchHint');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.orange[800],
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (mounted && list.isEmpty && value.trim().length >= 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(AppStrings.t(context, 'noPlacesFoundSetGoogleMapsKey')),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _searching = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${AppStrings.t(context, 'searchFailed')}: $e'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    });
  }

  Future<void> _onSelectPrediction(Map<String, dynamic> pred) async {
    final placeId = pred['place_id'] as String?;
    if (placeId == null || placeId.isEmpty) return;
    setState(() => _searching = true);
    try {
      final details = await ApiService.getPlaceDetails(placeId);
      if (!mounted || details == null) {
        setState(() => _searching = false);
        return;
      }
      final lat = details['latitude'] as num?;
      final lng = details['longitude'] as num?;
      final addr = details['formatted_address'] as String? ??
          pred['description'] as String? ??
          '';
      if (lat != null && lng != null) {
        setState(() {
          _latitude = lat.toDouble();
          _longitude = lng.toDouble();
          _address = addr ?? '';
          _searchController.text = _address;
          _predictions = [];
          _searching = false;
        });
        _updateMarker();
        final controller = await _mapController.future;
        await controller.animateCamera(
          CameraUpdate.newLatLng(LatLng(_latitude!, _longitude!)),
        );
      } else {
        setState(() => _searching = false);
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _loadingCurrent = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text(AppStrings.t(context, 'locationPermissionNeeded')),
              ),
            );
          }
          setState(() => _loadingCurrent = false);
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _loadingCurrent = false;
      });
      _updateMarker();
      await _reverseGeocode(pos.latitude, pos.longitude);
      final controller = await _mapController.future;
      await controller.animateCamera(
        CameraUpdate.newLatLng(LatLng(_latitude!, _longitude!)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${AppStrings.t(context, 'couldNotGetLocation')}: $e')),
        );
        setState(() => _loadingCurrent = false);
      }
    }
  }

  void _confirm() {
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppStrings.t(context, 'tapMapOrSearchSetLocation'))),
      );
      return;
    }
    final address = _address.trim().isEmpty
        ? _coordinatesAddress(_latitude!, _longitude!)
        : _address;
    Navigator.of(context).pop(LocationResult(
      address: address,
      latitude: _latitude!,
      longitude: _longitude!,
    ));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightLavender,
      appBar: AppBar(
        title: Text(
          AppStrings.t(context, 'selectLocation'),
          style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: AppStrings.t(context, 'searchAddress'),
                    prefixIcon:
                        const Icon(Icons.search, color: AppTheme.darkGrey),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: AppShimmerLoader(strokeWidth: 2),
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _loadingCurrent ? null : _useCurrentLocation,
                      icon: _loadingCurrent
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: AppShimmerLoader(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 20),
                      label: Text(_loadingCurrent
                          ? AppStrings.t(context, 'gettingLocation')
                          : AppStrings.t(context, 'useCurrentLocation')),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                if (_predictions.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _predictions.length,
                      itemBuilder: (context, i) {
                        final p = _predictions[i];
                        final desc = p['description'] as String? ?? '';
                        return ListTile(
                          leading:
                              const Icon(Icons.place, color: AppTheme.darkGrey),
                          title: Text(
                            desc,
                            style: const TextStyle(
                                fontSize: 14, color: AppTheme.darkGrey),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _onSelectPrediction(p),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _center,
                      zoom: _latitude != null && _longitude != null ? 15 : 12,
                    ),
                    mapType: MapType.normal,
                    markers: _markers,
                    onMapCreated: (controller) {
                      _mapController.complete(controller);
                      setState(() => _mapReady = true);
                    },
                    onTap: _onMapTap,
                    myLocationButtonEnabled: false,
                    myLocationEnabled: true,
                    mapToolbarEnabled: false,
                    zoomControlsEnabled: false,
                    liteModeEnabled: false,
                  ),
                  Center(
                    child: _markers.isEmpty
                        ? Icon(
                            Icons.place,
                            size: 48,
                            color: Colors.red[400],
                          )
                        : const SizedBox.shrink(),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Material(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Text(
                          AppStrings.t(context, 'tapMapSetLocationHint'),
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.darkGrey,
                  foregroundColor: AppTheme.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(AppStrings.t(context, 'confirmLocation')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
