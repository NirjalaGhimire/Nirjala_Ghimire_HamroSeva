import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/features/provider/widgets/provider_app_bar.dart';

/// Filter result returned to caller: selected booking status and payment type.
class ProviderFilterResult {
  const ProviderFilterResult({
    this.bookingStatus,
    this.paymentType,
  });
  final String? bookingStatus;
  final String? paymentType;
}

/// Provider Filter By: Handyman, Booking Status, Payment Type.
/// Booking status: Pending, Pay to Confirm, Confirmed, Completed.
/// Payment type: Cash on Delivery, eSewa Payment only.
class ProviderFilterScreen extends StatefulWidget {
  const ProviderFilterScreen({super.key});

  @override
  State<ProviderFilterScreen> createState() => _ProviderFilterScreenState();
}

class _ProviderFilterScreenState extends State<ProviderFilterScreen> {
  int _tabIndex = 0;
  String? _selectedBookingStatus;
  String? _selectedPaymentType;

  static const List<String> _tabs = ['Handyman', 'Booking Status', 'Payment Type'];
  /// Valid booking workflow statuses only (filters and UI).
  static const List<String> _bookingStatuses = [
    'Pending',
    'Quoted',
    'Pay to Confirm',
    'Confirmed',
    'Completed',
    'Cancelled',
  ];
  static const List<String> _paymentTypes = [
    'Cash on Delivery',
    'eSewa Payment',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.arrow_back, color: colorScheme.onPrimary), onPressed: () => Navigator.pop(context, ProviderFilterResult(bookingStatus: _selectedBookingStatus, paymentType: _selectedPaymentType))),
        title: const Text('Filter By', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        shape: providerAppBarShape,
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _selectedBookingStatus = null;
              _selectedPaymentType = null;
            }),
            child: Text('Reset', style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final selected = _tabIndex == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_tabs[i]),
                    selected: selected,
                    onSelected: (_) => setState(() => _tabIndex = i),
                    selectedColor: colorScheme.primary.withOpacity(0.3),
                    checkmarkColor: colorScheme.primary,
                    side: BorderSide(color: selected ? colorScheme.primary : colorScheme.outline, width: selected ? 2 : 1),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _tabIndex == 0
                ? _buildHandymanPlaceholder()
                : _tabIndex == 1
                    ? _buildRadioList(_bookingStatuses, _selectedBookingStatus, (v) => setState(() => _selectedBookingStatus = v))
                    : _buildRadioList(_paymentTypes, _selectedPaymentType, (v) => setState(() => _selectedPaymentType = v)),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, ProviderFilterResult(bookingStatus: _selectedBookingStatus, paymentType: _selectedPaymentType)),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Apply'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandymanPlaceholder() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('Filter by handyman', style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildRadioList(List<String> options, String? selected, ValueChanged<String> onSelect) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final opt = options[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outline),
          ),
          child: RadioListTile<String>(
            value: opt,
            groupValue: selected,
            onChanged: (v) => onSelect(v ?? opt),
            title: Text(opt, style: TextStyle(color: colorScheme.onSurface)),
            activeColor: colorScheme.primary,
          ),
        );
      },
    );
  }
}
