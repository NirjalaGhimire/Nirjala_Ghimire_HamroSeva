import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Filter By: tabs Shop, Service, Date Range, Provider. Uses real data from API.
class FilterByScreen extends StatefulWidget {
  const FilterByScreen({
    super.key,
    this.initialCategory = 0,
    this.onApply,
  });

  final int initialCategory;
  final void Function(Map<String, dynamic>? filters)? onApply;

  @override
  State<FilterByScreen> createState() => _FilterByScreenState();
}

class _FilterByScreenState extends State<FilterByScreen> {
  late int _categoryIndex;
  String? _selectedShopId;
  String? _selectedServiceId;
  DateTimeRange? _dateRange;
  String? _selectedProviderId;

  static const List<String> _categories = ['Shop', 'Service', 'Date Range', 'Provider'];

  List<Map<String, String>> _shops = [];
  List<Map<String, String>> _services = [];
  List<Map<String, String>> _providers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _categoryIndex = widget.initialCategory.clamp(0, _categories.length - 1);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final prov = await ApiService.getProviders();
      final cats = await ApiService.getCategories();
      if (!mounted) return;
      _shops = prov
          .where((p) => p['id'] != null)
          .map((p) => {
                'id': p['id'].toString(),
                'name': ((p['username'] ?? '') as String).isNotEmpty
                    ? '${p['username']}${(p['profession'] ?? '').toString().trim().isNotEmpty ? ' (${p['profession']})' : ''}'
                    : 'Provider ${p['id']}',
              })
          .toList();
      _providers = List.from(_shops);
      _services = (cats)
          .where((c) => c['id'] != null && c['name'] != null)
          .map((c) => {'id': c['id'].toString(), 'name': c['name'].toString()})
          .toList();
    } catch (_) {
      _shops = [];
      _providers = [];
      _services = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  void _reset() {
    setState(() {
      _selectedShopId = null;
      _selectedServiceId = null;
      _dateRange = null;
      _selectedProviderId = null;
    });
  }

  void _apply() {
    final filters = <String, dynamic>{
      'shop': _selectedShopId,
      'service': _selectedServiceId,
      'dateRange': _dateRange != null
          ? {'start': _dateRange!.start.toIso8601String(), 'end': _dateRange!.end.toIso8601String()}
          : null,
      'provider': _selectedProviderId,
    };
    widget.onApply?.call(filters);
    Navigator.of(context).pop(filters);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Filter By',
          style: TextStyle(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        actions: [
          TextButton(
            onPressed: _reset,
            child: const Text('Reset', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: List.generate(_categories.length, (i) {
                final selected = _categoryIndex == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_categories[i]),
                    selected: selected,
                    onSelected: (_) => setState(() => _categoryIndex = i),
                    selectedColor: AppTheme.customerPrimary.withOpacity(0.3),
                    checkmarkColor: AppTheme.customerPrimary,
                    side: BorderSide(
                      color: selected ? AppTheme.customerPrimary : Colors.grey[300]!,
                      width: selected ? 2 : 1,
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading && _categoryIndex != 2
                ? const Center(child: CircularProgressIndicator(color: AppTheme.customerPrimary))
                : _buildCategoryContent(),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _apply,
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

  Widget _buildCategoryContent() {
    switch (_categoryIndex) {
      case 0:
        return _buildList(_shops, _selectedShopId, (id) => setState(() => _selectedShopId = id), leading: Icons.store);
      case 1:
        return _buildList(_services, _selectedServiceId, (id) => setState(() => _selectedServiceId = id), leading: Icons.build_circle_outlined);
      case 2:
        return _buildDateRangePicker();
      case 3:
        return _buildList(_providers, _selectedProviderId, (id) => setState(() => _selectedProviderId = id), leading: Icons.person_outline);
      default:
        return const SizedBox();
    }
  }

  Widget _buildList(
    List<Map<String, String>> items,
    String? selectedId,
    void Function(String id) onSelect, {
    required IconData leading,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No options available. Add providers or categories in the app.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final id = item['id']!;
        final name = item['name']!;
        final selected = selectedId == id;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[300]!),
          ),
          child: RadioListTile<String>(
            value: id,
            groupValue: selectedId,
            onChanged: (v) => onSelect(v ?? id),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
            secondary: CircleAvatar(
              backgroundColor: AppTheme.customerPrimary.withOpacity(0.15),
              child: Icon(leading, color: AppTheme.customerPrimary, size: 22),
            ),
            activeColor: AppTheme.customerPrimary,
          ),
        );
      },
    );
  }

  Widget _buildDateRangePicker() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select date range',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppTheme.customerPrimary,
                        onPrimary: AppTheme.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (range != null && mounted) setState(() => _dateRange = range);
            },
            icon: const Icon(Icons.calendar_today),
            label: Text(
              _dateRange == null
                  ? 'Pick start and end date'
                  : '${_dateRange!.start.toString().split(' ')[0]} – ${_dateRange!.end.toString().split(' ')[0]}',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.customerPrimary,
              side: const BorderSide(color: AppTheme.customerPrimary),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }
}
