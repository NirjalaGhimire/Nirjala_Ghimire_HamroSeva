import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/payments_screen.dart';

/// Order Detail: status pill, address, service type icons, order date, details (show more), attachments, Workers/Helpers, Booked services, Payments.
/// States: Pending, Accepted, Confirmed, Assigned, In Progress, Cancelled, Completed.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({
    super.key,
    this.orderId,
    this.status = 'pending',
    this.address = 'N-35 Itahari Dulari, Sundar Haraicha',
    this.orderDate = '20 March 12:00 PM',
    this.detailsText = 'There are no limits in the world of HamroSeva. You can be both a customer and a helper. For more you can press show more.',
    this.showWorkers = false,
    this.showBookedServices = true,
    this.showPayments = false,
  });

  final String? orderId;
  final String status;
  final String address;
  final String orderDate;
  final String detailsText;
  final bool showWorkers;
  final bool showBookedServices;
  final bool showPayments;

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.pink;
      case 'confirmed':
        return Colors.green;
      case 'assigned':
        return Colors.blue;
      case 'in progress':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _statusMessage(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return 'We have received your order and will get back to you as soon as the order is reviewed.';
      case 'accepted':
        return 'We have reviewed your order. Our team will contact you soon for quotation.';
      case 'confirmed':
        return 'You have confirmed your order. We are going to assign workers for your order.';
      case 'assigned':
        return 'Workers have been assigned to your order. They will soon start working on your order.';
      case 'in progress':
        return 'Your order is in progress. Our workers will make sure to do quality work for you.';
      case 'cancelled':
        return 'We have cancelled this order because customer was not responding.';
      case 'completed':
        return 'Your order has successfully been completed. We hope that you have liked our services 👋🎉.';
      default:
        return 'Order status: $s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightLavender,
      appBar: AppBar(
        title: const Text('Order Detail', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
        actions: [
          if (status.toLowerCase() == 'completed')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 4),
                  Text('Completed', style: TextStyle(color: Colors.green[200], fontSize: 12)),
                ],
              ),
            ),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Order Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(status, style: TextStyle(fontWeight: FontWeight.w600, color: _statusColor(status))),
                  ),
                  const SizedBox(height: 8),
                  Text(_statusMessage(status), style: TextStyle(fontSize: 13, color: AppTheme.darkGrey.withOpacity(0.8))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Address:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
                  const SizedBox(height: 4),
                  Text(address, style: const TextStyle(color: AppTheme.darkGrey)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Service Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _serviceChip(Icons.cleaning_services, 'Cleaning'),
                      _serviceChip(Icons.build, 'Repairing'),
                      _serviceChip(Icons.electrical_services, 'Electrician'),
                      _serviceChip(Icons.carpenter, 'Carpenter'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Order Date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
                  const SizedBox(height: 4),
                  Text(orderDate, style: const TextStyle(color: AppTheme.darkGrey)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
                  const SizedBox(height: 4),
                  Text(detailsText, style: TextStyle(fontSize: 13, color: AppTheme.darkGrey.withOpacity(0.8)), maxLines: 3, overflow: TextOverflow.ellipsis),
                  GestureDetector(onTap: () {}, child: const Text('Show more', style: TextStyle(color: Colors.blue, fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Attachments', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 5,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.image_outlined, color: Colors.grey[600]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showWorkers) ...[
              const SizedBox(height: 12),
              _card(
                onTap: () => _showWorkersModal(context),
                child: const Row(
                  children: [
                    Text('Workers/Helpers', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
                    Spacer(),
                    Icon(Icons.chevron_right, color: AppTheme.darkGrey),
                  ],
                ),
              ),
            ],
            if (showBookedServices) ...[
              const SizedBox(height: 12),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Booked Services', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
                    const SizedBox(height: 8),
                    _bookedRow('Maid Services', 'Rs. 455'),
                    _bookedRow('Carpet Cleaning', 'Rs. 455'),
                    _bookedRow('Sofa Cleaning', 'Rs. 455'),
                    const SizedBox(height: 12),
                    _bookedRow('Tax', 'Rs. 455'),
                    _bookedRow('Discount (10%)', '-10.00'),
                    const Divider(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
                        Text('Rs. 1250', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (showPayments) ...[
              const SizedBox(height: 12),
              _card(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaymentsScreen())),
                child: const Row(
                  children: [
                    Text('Payments', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
                    Spacer(),
                    Icon(Icons.chevron_right, color: AppTheme.darkGrey),
                  ],
                ),
              ),
            ],
            if (status.toLowerCase() == 'pending') ...[
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  onPressed: () => _showHelpDialog(context),
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Do you need any Help?'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child, VoidCallback? onTap}) {
    final c = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
      ),
      child: child,
    );
    if (onTap != null) return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: c);
    return c;
  }

  Widget _serviceChip(IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(radius: 24, backgroundColor: Colors.grey[200], child: Icon(icon, size: 22, color: AppTheme.darkGrey)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.darkGrey)),
      ],
    );
  }

  Widget _bookedRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: AppTheme.darkGrey)), Text(value, style: const TextStyle(color: AppTheme.darkGrey))]),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(radius: 32, backgroundColor: AppTheme.darkGrey, child: Icon(Icons.phone_in_talk, color: AppTheme.white, size: 32)),
            const SizedBox(height: 16),
            const Text('Do you need any Help?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
            const SizedBox(height: 8),
            const Text('After confirmation, we are going to assign workers for your order.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.darkGrey)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact — coming soon')));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.darkGrey, foregroundColor: AppTheme.white),
                child: const Text('Contact'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWorkersModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Workers / Helpers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
            const SizedBox(height: 16),
            _workerTile('Shahid Iqbal', 'Plumber'),
            _workerTile('Ehsan Ullah', 'Helper'),
            _workerTile('Saddam Shadab', 'Helper'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _workerTile(String name, String role) {
    return ListTile(
      leading: const CircleAvatar(backgroundColor: AppTheme.lightLavender, child: Icon(Icons.person, color: AppTheme.darkGrey)),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.darkGrey)),
      trailing: Text(role, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
    );
  }
}
