import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/provider/screens/provider_notifications_screen.dart';
import 'package:hamro_sewa_frontend/features/provider/widgets/provider_app_bar.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

/// Provider Home: welcome, Total Cash in Hand, 4 metric cards, Monthly Revenue (real data from backend).
class ProviderHomeTabScreen extends StatefulWidget {
  const ProviderHomeTabScreen({super.key});

  @override
  State<ProviderHomeTabScreen> createState() => _ProviderHomeTabScreenState();
}

class _ProviderHomeTabScreenState extends State<ProviderHomeTabScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _stats;
  bool _statsLoading = true;
  String? _statsError;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadStats();
  }

  Future<void> _loadUser() async {
    final user = await TokenStorage.getSavedUser();
    if (mounted) setState(() => _user = user);
  }

  Future<void> _loadStats() async {
    setState(() {
      _statsLoading = true;
      _statsError = null;
    });
    try {
      final data = await ApiService.getDashboardStats();
      if (mounted) {
        setState(() {
        _stats = Map<String, dynamic>.from(data);
        _statsLoading = false;
      });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _stats = null;
        _statsLoading = false;
        _statsError = e.toString().replaceFirst('Exception: ', '');
      });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?['username'] ?? _user?['email'] ?? 'Provider';
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text(
          'Provider Home',
          style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        elevation: 0,
        shape: providerAppBarShape,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProviderNotificationsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUser();
          await _loadStats();
        },
        color: AppTheme.customerPrimary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $name',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Welcome back!',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              _buildCashCard(),
              const SizedBox(height: 16),
              _buildMetricGrid(),
              if (_statsError != null) ...[
                const SizedBox(height: 8),
                Text(_statsError!, style: TextStyle(fontSize: 12, color: Colors.red[700])),
              ],
              const SizedBox(height: 24),
              _buildChartSection(),
            ],
          ),
        ),
      ),
    );
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  String _money(double n) => 'Rs ${n.toStringAsFixed(2)}';

  Widget _buildCashCard() {
    final cash = _statsLoading ? 0.0 : _num(_stats?['cash_in_hand']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.customerPrimary.withOpacity(0.15),
            child: const Icon(Icons.account_balance_wallet, color: AppTheme.customerPrimary, size: 32),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Total Cash in Hand',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          if (_statsLoading)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Text(
              _money(cash),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.customerPrimary),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid() {
    final bookings = _statsLoading ? 0 : _int(_stats?['total_bookings']);
    final services = _statsLoading ? 0 : _int(_stats?['total_services']);
    final payout = _statsLoading ? 0.0 : _num(_stats?['remaining_payout']);
    final revenue = _statsLoading ? 0.0 : _num(_stats?['total_earnings']);
    final items = [
      (bookings.toString(), 'Total Bookings', Icons.list_alt),
      (services.toString(), 'Total Service', Icons.assignment),
      (_money(payout), 'Remaining Payout', Icons.payments),
      (_money(revenue), 'Total Revenue', Icons.monetization_on),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: items.map((e) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.customerPrimary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.$1,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.white,
                    ),
                  ),
                  Icon(e.$3, color: AppTheme.white.withOpacity(0.9), size: 28),
                ],
              ),
              Text(
                e.$2,
                style: TextStyle(fontSize: 12, color: AppTheme.white.withOpacity(0.9)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChartSection() {
    final revenue = _statsLoading ? 0.0 : _num(_stats?['total_earnings']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monthly Revenue (Rs)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkGrey,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Center(
            child: Text(
              _money(revenue),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.customerPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

