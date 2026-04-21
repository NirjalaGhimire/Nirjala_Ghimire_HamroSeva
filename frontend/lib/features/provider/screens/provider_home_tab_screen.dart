import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
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
  int _unseenNotifications = 0;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadStats();
    _checkNotifications();
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkNotifications();
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
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
        final s = e.toString();
        final isConnectionError = s.contains('Connection refused') ||
            s.contains('Connection timed out') ||
            s.contains('SocketException') ||
            s.contains('Failed host lookup');
        setState(() {
          _stats = null;
          _statsLoading = false;
          _statsError = isConnectionError
              ? 'Cannot reach server. Start the backend: python manage.py runserver 0.0.0.0:8000'
              : s.replaceFirst(RegExp(r'^Exception:\s*'), '');
        });
      }
    }
  }

  Future<void> _checkNotifications() async {
    try {
      final lastSeen = await TokenStorage.getLastSeenNotificationId();
      final notifications = await ApiService.getProviderNotifications();
      final unseenIds = notifications
          .map((e) => (e as Map<String, dynamic>)['id'])
          .map((v) => v is int ? v : int.tryParse(v?.toString() ?? '0'))
          .whereType<int>()
          .where((id) => lastSeen == null || id > lastSeen)
          .toList();
      if (!mounted) return;

      final unseenCount = unseenIds.length;
      final showSnack = unseenCount > 0 && unseenCount > _unseenNotifications;
      setState(() => _unseenNotifications = unseenCount);

      if (showSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.t(context, 'youHaveNewNotifications')
                  .replaceAll('{value}', unseenCount.toString()),
            ),
            action: SnackBarAction(
              label: AppStrings.t(context, 'viewDetails'),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ProviderNotificationsScreen()),
                );
                await _checkNotifications();
              },
            ),
          ),
        );
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?['username'] ?? _user?['email'] ?? AppStrings.t(context, 'serviceProvider');
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          AppStrings.t(context, 'providerHome'),
          style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        elevation: 0,
        shape: providerAppBarShape,
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (_unseenNotifications > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _unseenNotifications > 99
                            ? '99+'
                            : '$_unseenNotifications',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const ProviderNotificationsScreen()),
              );
              await _checkNotifications();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUser();
          await _loadStats();
          await _checkNotifications();
        },
        color: AppTheme.customerPrimary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppStrings.t(context, 'hello')}, $name',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.t(context, 'welcomeBack'),
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              _buildCashCard(),
              const SizedBox(height: 16),
              _buildMetricGrid(),
              if (_statsError != null) ...[
                const SizedBox(height: 8),
                Text(_statsError!,
                    style: TextStyle(fontSize: 12, color: Colors.red[700])),
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
            child: const Icon(Icons.account_balance_wallet,
                color: AppTheme.customerPrimary, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              AppStrings.t(context, 'totalCashInHand'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          if (_statsLoading)
            const SizedBox(
                width: 24,
                height: 24,
                child: AppShimmerLoader(strokeWidth: 2))
          else
            Text(
              _money(cash),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.customerPrimary),
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
      (bookings.toString(), AppStrings.t(context, 'totalBookings'), Icons.list_alt),
      (services.toString(), AppStrings.t(context, 'totalServices'), Icons.assignment),
      (_money(payout), AppStrings.t(context, 'remainingPayout'), Icons.payments),
      (_money(revenue), AppStrings.t(context, 'totalRevenue'), Icons.monetization_on),
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
                style: TextStyle(
                    fontSize: 12, color: AppTheme.white.withOpacity(0.9)),
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
        Text(
          AppStrings.t(context, 'monthlyRevenueRs'),
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
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.customerPrimary),
            ),
          ),
        ),
      ],
    );
  }
}
