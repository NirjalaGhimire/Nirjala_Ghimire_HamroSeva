import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
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
    this.price,
  });

  final String categoryId;
  final String categoryTitle;
  final IconData categoryIcon;
  final int? serviceId;
  final String? serviceTitle;
  final String? providerName;
  final double? price;

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  String? _address;
  String _details = '';
  List<String> _photoPaths = [];
  DateTime _bookingDate = DateTime.now();
  TimeOfDay _bookingTime = const TimeOfDay(hour: 10, minute: 0);
  bool _submitting = false;

  Future<void> _pickAddress() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SelectLocationScreen()),
    );
    if (result != null && mounted) setState(() => _address = result);
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _bookingDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _bookingDate = picked);
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
        const SnackBar(content: Text('Please add an address')),
      );
      return;
    }
    final totalAmount = widget.price ?? 0.0;
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
            const Text(
              'Confirm Order',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
            ),
            const SizedBox(height: 8),
            Text(
              'Provider: ${widget.providerName ?? "—"}',
              style: const TextStyle(fontSize: 14, color: AppTheme.darkGrey),
            ),
            const SizedBox(height: 4),
            Text(
              'Total cost: Rs. ${totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.customerPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              "We will process your order and the provider will be notified.",
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
                          final dateStr = '${_bookingDate.year}-${_bookingDate.month.toString().padLeft(2, '0')}-${_bookingDate.day.toString().padLeft(2, '0')}';
                          final timeStr = '${_bookingTime.hour.toString().padLeft(2, '0')}:${_bookingTime.minute.toString().padLeft(2, '0')}:00';
                          await ApiService.createBooking(
                            serviceId: widget.serviceId!,
                            bookingDate: dateStr,
                            bookingTime: timeStr,
                            notes: _details.isEmpty ? null : _details,
                            totalAmount: totalAmount,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Order placed successfully. Provider has been notified.')),
                          );
                          Navigator.pop(context);
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to place order: ${e.toString().replaceFirst('Exception: ', '')}')),
                          );
                        } finally {
                          if (mounted) setState(() => _submitting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.darkGrey, foregroundColor: AppTheme.white),
                child: _submitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.white)) : const Text('Place Order'),
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
        title: const Text('Place order', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Category'),
            const SizedBox(height: 8),
            Row(
              children: [
                _categoryChip(widget.categoryTitle, widget.categoryIcon, onRemove: () => Navigator.pop(context)),
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
              _sectionLabel('Provider & Cost'),
              const SizedBox(height: 8),
              _tapCard(
                icon: Icons.person_outline,
                label: '${widget.providerName ?? "Provider"} — Rs. ${(widget.price ?? 0).toStringAsFixed(2)}',
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
            _sectionLabel('Date & Time'),
            const SizedBox(height: 8),
            _tapCard(
              icon: Icons.calendar_today_outlined,
              label: '${_bookingDate.day}/${_bookingDate.month}/${_bookingDate.year} at ${_bookingTime.hour.toString().padLeft(2, '0')}:${_bookingTime.minute.toString().padLeft(2, '0')}',
              onTap: () async {
                await _pickDate();
                if (mounted) await _pickTime();
              },
            ),
            const SizedBox(height: 20),
            _sectionLabel('Address'),
            const SizedBox(height: 8),
            _tapCard(
              icon: Icons.location_on_outlined,
              label: _address ?? 'Add Address',
              onTap: _pickAddress,
            ),
            const SizedBox(height: 12),
            _tapCard(
              icon: Icons.description_outlined,
              label: _details.isEmpty ? 'Add details' : _details.length > 40 ? '${_details.substring(0, 40)}...' : _details,
              onTap: _addDetails,
            ),
            const SizedBox(height: 12),
            _tapCard(
              icon: Icons.photo_library_outlined,
              label: _photoPaths.isEmpty ? 'Add photos' : '${_photoPaths.length} photo(s) added',
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
                child: const Text('Confirm Order'),
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
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
    );
  }

  Widget _categoryChip(String title, IconData icon, {VoidCallback? onRemove}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: AppTheme.darkGrey),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.darkGrey)),
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
        ),
        child: const Icon(Icons.add, size: 28, color: AppTheme.darkGrey),
      ),
    );
  }

  Widget _tapCard({required IconData icon, required String label, required VoidCallback onTap}) {
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
              Expanded(child: Text(label, style: TextStyle(color: _address == null && label == 'Add Address' ? Colors.grey[600] : AppTheme.darkGrey))),
              const Icon(Icons.chevron_right, color: AppTheme.darkGrey),
            ],
          ),
        ),
      ),
    );
  }
}
