import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/add_details_screen.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/add_photo_screen.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/select_location_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Asks **admins** to add a new service type that is not in the app yet (not a provider booking).
class CustomerNewRequestScreen extends StatefulWidget {
  const CustomerNewRequestScreen({super.key});

  @override
  State<CustomerNewRequestScreen> createState() =>
      _CustomerNewRequestScreenState();
}

class _CustomerNewRequestScreenState extends State<CustomerNewRequestScreen> {
  final _serviceName = TextEditingController();

  String? _address;
  double? _latitude;
  double? _longitude;
  String _details = '';
  List<String> _photoPaths = [];

  bool _submitting = false;

  @override
  void dispose() {
    _serviceName.dispose();
    super.dispose();
  }

  Future<void> _pickAddress() async {
    final result = await Navigator.of(context).push<LocationResult>(
      MaterialPageRoute(
        builder: (_) => SelectLocationScreen(
          initialAddress: _address,
          initialLat: _latitude,
          initialLng: _longitude,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _address = result.address;
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
    }
  }

  Future<void> _addDetails() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AddDetailsScreen(initialDetails: _details),
      ),
    );
    if (result != null && mounted) setState(() => _details = result);
  }

  Future<void> _addPhotos() async {
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => AddPhotoScreen(initialPaths: List.from(_photoPaths)),
      ),
    );
    if (result != null && mounted) setState(() => _photoPaths = result);
  }

  Future<void> _submitRequest() async {
    final name = _serviceName.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.t(context, 'enterNameOfServiceToAdd')),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final urls = <String>[];
      if (!kIsWeb && _photoPaths.isNotEmpty) {
        for (final path in _photoPaths) {
          if (!File(path).existsSync()) continue;
          try {
            final url = await ApiService.uploadBookingRequestImage(path);
            urls.add(url);
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${AppStrings.t(context, 'couldNotUploadImage')}: ${e.toString().replaceFirst('Exception: ', '')}',
                ),
              ),
            );
            setState(() => _submitting = false);
            return;
          }
        }
      }

      await ApiService.submitServiceCategoryRequest(
        requestedServiceName: name,
        description: _details.trim().isEmpty ? null : _details.trim(),
        address: (_address == null || _address!.trim().isEmpty)
            ? null
            : _address!.trim(),
        latitude: _latitude,
        longitude: _longitude,
        imageUrls: urls.isEmpty ? null : urls,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.t(context, 'requestSentToOurTeam')),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _tapCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.darkGrey),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: label == AppStrings.t(context, 'addDetails') ||
                            label == AppStrings.t(context, 'addAddress') ||
                            label.startsWith('Add ')
                        ? Colors.grey[600]
                        : AppTheme.darkGrey,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.darkGrey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightLavender,
      appBar: AppBar(
        title: Text(
          AppStrings.t(context, 'newRequest'),
          style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: AppTheme.customerPrimary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.t(context, 'requestANewService'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      AppStrings.t(context, 'requestNewServiceDescription'),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.t(context, 'serviceNameToAdd'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _serviceName,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: AppStrings.t(context, 'serviceNameExample'),
                filled: true,
                fillColor: AppTheme.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.t(context, 'addressOptional'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            _tapCard(
              icon: Icons.location_on_outlined,
              label: _address ?? AppStrings.t(context, 'addAddress'),
              onTap: _pickAddress,
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.t(context, 'moreDetailsOptional'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            _tapCard(
              icon: Icons.description_outlined,
              label: _details.isEmpty
                  ? AppStrings.t(context, 'addDetails')
                  : (_details.length > 40
                      ? '${_details.substring(0, 40)}...'
                      : _details),
              onTap: _addDetails,
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.t(context, 'photosOptional'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            _tapCard(
              icon: Icons.photo_library_outlined,
              label: _photoPaths.isEmpty
                  ? AppStrings.t(context, 'addPhotos')
                  : '${_photoPaths.length} ${AppStrings.t(context, 'photosAdded')}',
              onTap: _addPhotos,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.darkGrey,
                  foregroundColor: AppTheme.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: AppShimmerLoader(
                          strokeWidth: 2,
                          color: AppTheme.white,
                        ),
                      )
                    : Text(AppStrings.t(context, 'sendRequestToAdmin')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
