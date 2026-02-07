import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/order_detail_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Orders tab: Pending / History tabs, empty state or list with status tags (Pending, Confirmed, Assigned, Accepted, Cancelled, Completed).
class OrdersTabScreen extends StatefulWidget {
  const OrdersTabScreen({super.key});

  @override
  State<OrdersTabScreen> createState() => _OrdersTabScreenState();
}

class _OrdersTabScreenState extends State<OrdersTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _pending = [];
  List<dynamic> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getUserBookings();
      if (!mounted) return;
      final pending = <dynamic>[];
      final history = <dynamic>[];
      for (final b in list) {
        final status = (b['status'] as String?)?.toLowerCase() ?? '';
        if (status == 'cancelled' || status == 'completed') {
          history.add(b);
        } else {
          pending.add(b);
        }
      }
      setState(() {
        _pending = pending;
        _history = history;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _pending = [];
          _history = [];
          _loading = false;
        });
      }
    }
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'assigned':
        return Colors.blue;
      case 'accepted':
        return Colors.pink;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppTheme.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.darkGrey,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.darkGrey,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'History'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOrderList(_pending, isPending: true),
              _buildOrderList(_history, isPending: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderList(List<dynamic> items, {required bool isPending}) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return _buildEmptyState(
        title: 'No Orders Yet',
        subtitle: isPending
            ? 'You have no active order right now.'
            : 'No past orders.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: AppTheme.darkGrey,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final order = items[index];
          final title = order['service_title'] ?? order['title'] ?? 'Order';
          final desc = order['description'] ?? 'No description.';
          final status = order['status'] ?? 'Pending';
          final time = order['booking_date'] ?? order['created_at'] ?? '—';
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            color: AppTheme.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              title: Text(
                title is String ? title : 'Order',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGrey,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    desc is String ? desc : 'No description.',
                    style: TextStyle(
                      color: AppTheme.darkGrey.withOpacity(0.8),
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        time is String ? time : '—',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status is String ? status : 'Pending',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              onTap: () {
                final status = (order['status'] as String?) ?? 'pending';
                final st = status;
                final showWorkers = ['assigned', 'in progress', 'completed'].contains(st.toLowerCase());
                final showBooked = ['accepted', 'confirmed', 'assigned', 'in progress', 'completed'].contains(st.toLowerCase());
                final showPayments = ['in progress', 'completed'].contains(st.toLowerCase());
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(
                      orderId: order['id']?.toString(),
                      status: st,
                      address: order['address'] ?? 'N-35 Itahari Dulari, Sundar Haraicha',
                      orderDate: order['booking_date'] ?? order['created_at'] ?? '20 March 12:00 PM',
                      detailsText: order['description'] ?? 'There are no limits in the world of HamroSeva. You can be both a customer and a helper. For more you can press show more.',
                      showWorkers: showWorkers,
                      showBookedServices: showBooked,
                      showPayments: showPayments,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
