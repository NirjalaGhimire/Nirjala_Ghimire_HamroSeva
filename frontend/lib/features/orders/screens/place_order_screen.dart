import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/core/utils/nepal_time.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/select_location_screen.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/add_details_screen.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/add_photo_screen.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/select_provider_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Place order: Category, Provider (if not chosen), Address, Details, Photos, Cost shown, Confirm Order.
class PlaceOrderScreen extends StatefulWidget {
  const PlaceOrderScreen({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
    required this.categoryIcon,
    this.serviceId,
    this.serviceTitle,
    this.providerName,
    this.providerId,
    this.price,
  });

  final String categoryId;
  final String categoryTitle;
  final IconData categoryIcon;
  final int? serviceId;
  final String? serviceTitle;
  final String? providerName;
  final int? providerId;
  final double? price;

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  String? _address;
  double? _latitude;
  double? _longitude;
  String _details = '';
  List<String> _photoPaths = [];
  DateTime _bookingDate = nepalNow();
  TimeOfDay _bookingTime = TimeOfDay.fromDateTime(nepalNow());
  List<dynamic> _availableSlots = [];
  bool _loadingSlots = false;
  String? _slotsError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableSlots();
  }

  Future<void> _loadAvailableSlots() async {
    if (widget.providerId == null) return;
    setState(() {
      _loadingSlots = true;
      _slotsError = null;
    });
    try {
      final slots = await ApiService.getProviderTimeSlots(
        providerId: widget.providerId,
        slotDate: _formatIsoDate(_bookingDate),
      );
      if (!mounted) return;
      setState(() {
        _availableSlots = slots;
        _loadingSlots = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _slotsError = e.toString().replaceFirst('Exception: ', '');
        _availableSlots = [];
        _loadingSlots = false;
      });
    }
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

  Future<void> _pickDate() async {
    final now = nepalNow();
    final picked = await showDatePicker(
      context: context,
      initialDate: _bookingDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        _bookingDate = picked;
      });
      await _loadAvailableSlots();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _bookingTime,
    );
    if (picked != null && mounted) setState(() => _bookingTime = picked);
  }

  Future<void> _confirmOrder() async {
    if (widget.serviceId == null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SelectProviderScreen(
            categoryId: widget.categoryId,
            categoryTitle: widget.categoryTitle,
            categoryIcon: widget.categoryIcon,
          ),
        ),
      );
      return;
    }
    if (_address == null || _address!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t(context, 'pleaseAddAddress'))),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: AppTheme.darkGrey,
              child: Icon(Icons.info_outline, color: AppTheme.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.t(context, 'confirmOrder'),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey),
            ),
            const SizedBox(height: 8),
            Text(
              '${AppStrings.t(context, 'provider')}: ${widget.providerName ?? "—"}',
              style: const TextStyle(fontSize: 14, color: AppTheme.darkGrey),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.t(context, 'providerWillSendQuote'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.customerPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.t(context, 'notifiedWhenPriceQuoted'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.darkGrey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting
                    ? null
                    : () async {
                        setState(() => _submitting = true);
                        Navigator.pop(ctx);
                        try {
                          String? requestImageUrl;
                          if (!kIsWeb &&
                              _photoPaths.isNotEmpty &&
                              File(_photoPaths.first).existsSync()) {
                            try {
                              requestImageUrl =
                                  await ApiService.uploadBookingRequestImage(
                                _photoPaths.first,
                              );
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
                          final dateStr =
                              '${_bookingDate.year}-${_bookingDate.month.toString().padLeft(2, '0')}-${_bookingDate.day.toString().padLeft(2, '0')}';
                          final timeStr =
                              '${_bookingTime.hour.toString().padLeft(2, '0')}:${_bookingTime.minute.toString().padLeft(2, '0')}:00';
                          await ApiService.createBooking(
                            serviceId: widget.serviceId!,
                            bookingDate: dateStr,
                            bookingTime: timeStr,
                            notes: _details.isEmpty ? null : _details,
                            // Request-based pricing: price is set only after provider quotes.
                            totalAmount: 0,
                            address: _address,
                            latitude: _latitude,
                            longitude: _longitude,
                            requestImageUrl: requestImageUrl,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(AppStrings.t(
                                    context, 'orderPlacedProviderNotified'))),
                          );
                          Navigator.pop(context);
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    '${AppStrings.t(context, 'failedToPlaceOrder')}: ${e.toString().replaceFirst('Exception: ', '')}')),
                          );
                        } finally {
                          if (mounted) setState(() => _submitting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkGrey,
                    foregroundColor: AppTheme.white),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: AppShimmerLoader(
                            strokeWidth: 2, color: AppTheme.white))
                    : Text(AppStrings.t(context, 'placeOrder')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightLavender,
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'placeOrder'),
            style:
                TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel(AppStrings.t(context, 'category')),
            const SizedBox(height: 8),
            Row(
              children: [
                _categoryChip(widget.categoryTitle, widget.categoryIcon,
                    onRemove: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                _addChip(() {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SelectProviderScreen(
                        categoryId: widget.categoryId,
                        categoryTitle: widget.categoryTitle,
                        categoryIcon: widget.categoryIcon,
                      ),
                    ),
                  );
                }),
              ],
            ),
            if (widget.serviceId != null) ...[
              const SizedBox(height: 16),
              _sectionLabel(AppStrings.t(context, 'provider')),
              const SizedBox(height: 8),
              _tapCard(
                icon: Icons.person_outline,
                label:
                    '${widget.providerName ?? AppStrings.t(context, 'provider')} - ${AppStrings.t(context, 'priceAfterProviderReview')}',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SelectProviderScreen(
                      categoryId: widget.categoryId,
                      categoryTitle: widget.categoryTitle,
                      categoryIcon: widget.categoryIcon,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _sectionLabel(AppStrings.t(context, 'dateTime')),
            const SizedBox(height: 8),
            _tapCard(
              icon: Icons.calendar_today_outlined,
              label:
                  '${_bookingDate.day}/${_bookingDate.month}/${_bookingDate.year} at ${_bookingTime.hour.toString().padLeft(2, '0')}:${_bookingTime.minute.toString().padLeft(2, '0')}',
              onTap: () async {
                await _pickDate();
                if (widget.providerId == null && mounted) {
                  await _pickTime();
                }
              },
            ),
            if (widget.providerId != null) ...[
              const SizedBox(height: 16),
              _sectionLabel('Available time slots'),
              const SizedBox(height: 8),
              if (_loadingSlots)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: AppShimmerLoader(color: AppTheme.customerPrimary),
                  ),
                )
              else if (_slotsError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _slotsError!,
                    style: TextStyle(color: Colors.red[700]),
                  ),
                )
              else if (_availableSlots.isEmpty)
                Text(
                  'No availability set for this date. You can still choose a manual time.',
                  style: TextStyle(color: Colors.grey[700]),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableSlots.map((slot) {
                    final slotMap = Map<String, dynamic>.from(slot as Map);
                    final start = _formatTimeFromApi(slotMap['start_time']);
                    final end = _formatTimeFromApi(slotMap['end_time']);
                    final isSelected = _formatTime(_bookingTime) == start;
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text('$start - $end'),
                      onSelected: (_) {
                        final parsed = _timeFromApi(slotMap['start_time']);
                        if (parsed == null) return;
                        setState(() {
                          _bookingTime = parsed;
                        });
                      },
                      selectedColor: AppTheme.customerPrimary.withOpacity(0.18),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time),
                  label: const Text('Choose custom time'),
                ),
            ],
            const SizedBox(height: 20),
            _sectionLabel(AppStrings.t(context, 'address')),
            const SizedBox(height: 8),
            _tapCard(
              icon: Icons.location_on_outlined,
              label: _address ?? AppStrings.t(context, 'addAddress'),
              onTap: _pickAddress,
            ),
            const SizedBox(height: 12),
            _tapCard(
              icon: Icons.description_outlined,
              label: _details.isEmpty
                  ? AppStrings.t(context, 'addDetails')
                  : _details.length > 40
                      ? '${_details.substring(0, 40)}...'
                      : _details,
              onTap: _addDetails,
            ),
            const SizedBox(height: 12),
            _tapCard(
              icon: Icons.photo_library_outlined,
              label: _photoPaths.isEmpty
                  ? AppStrings.t(context, 'addPhotos')
                  : '${_photoPaths.length} ${AppStrings.t(context, 'photosAdded')}',
              onTap: _addPhotos,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.darkGrey,
                  foregroundColor: AppTheme.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(AppStrings.t(context, 'confirmOrder')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
    );
  }

  Widget _categoryChip(String title, IconData icon, {VoidCallback? onRemove}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: AppTheme.darkGrey),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppTheme.darkGrey)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 20, color: AppTheme.darkGrey),
          ),
        ],
      ),
    );
  }

  Widget _addChip(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)
          ],
        ),
        child: const Icon(Icons.add, size: 28, color: AppTheme.darkGrey),
      ),
    );
  }

  Widget _tapCard(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
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
                  child: Text(label,
                      style: TextStyle(
                          color: _address == null && label == 'Add Address'
                              ? Colors.grey[600]
                              : AppTheme.darkGrey))),
              const Icon(Icons.chevron_right, color: AppTheme.darkGrey),
            ],
          ),
        ),
      ),
    );
  }

  TimeOfDay? _timeFromApi(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatTimeFromApi(dynamic value) {
    final time = _timeFromApi(value);
    if (time == null) return (value ?? '—').toString();
    return _formatTime(time);
  }

  String _formatIsoDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
