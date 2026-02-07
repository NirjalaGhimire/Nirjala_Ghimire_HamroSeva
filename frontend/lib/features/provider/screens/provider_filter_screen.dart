import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/provider/widgets/provider_app_bar.dart';

/// Provider Filter By: Handyman, Booking Status, Payment Type (and Date Range, Customer).
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
  static const List<String> _bookingStatuses = [
    'Pending', 'Accepted', 'On Going', 'In Progress', 'Hold',
    'Cancelled', 'Rejected', 'Failed', 'Completed', 'Pending Approval', 'Waiting',
  ];
  static const List<String> _paymentTypes = [
    'Wallet', 'Cash on Delivery', 'Stripe Payment', 'Razor Pay', 'FlutterWave',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Filter By', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        elevation: 0,
        shape: providerAppBarShape,
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _selectedBookingStatus = null;
              _selectedPaymentType = null;
            }),
            child: const Text('Reset', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.w600)),
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
                    selectedColor: AppTheme.customerPrimary.withOpacity(0.3),
                    checkmarkColor: AppTheme.customerPrimary,
                    side: BorderSide(color: selected ? AppTheme.customerPrimary : Colors.grey[300]!, width: selected ? 2 : 1),
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
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.customerPrimary,
                foregroundColor: AppTheme.white,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Filter by handyman', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildRadioList(List<String> options, String? selected, ValueChanged<String> onSelect) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final opt = options[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[300]!),
          ),
          child: RadioListTile<String>(
            value: opt,
            groupValue: selected,
            onChanged: (v) => onSelect(v ?? opt),
            title: Text(opt),
            activeColor: AppTheme.customerPrimary,
          ),
        );
      },
    );
  }
}
