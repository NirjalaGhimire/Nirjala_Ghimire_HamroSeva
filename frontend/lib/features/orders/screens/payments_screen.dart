import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';

/// Payments: Active payment (PAY NOW), Remaining payments (collapsible), Cleared payments (collapsible), Payments summary.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  bool _remainingExpanded = false;
  bool _clearedExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightLavender,
      appBar: AppBar(
        title: const Text('Payments', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Active payment'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Material payment', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Amount', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const Text('Rs. 1500', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.darkGrey)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('Due Date', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const Text('10/10/2023', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.darkGrey)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pay now — coming soon'))),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.darkGrey, foregroundColor: AppTheme.white),
                      child: const Text('PAY NOW'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Remaining payments'),
            const SizedBox(height: 8),
            _collapsibleCard(
              expanded: _remainingExpanded,
              title: 'Payment Amount Rs. 4933',
              onTap: () => setState(() => _remainingExpanded = !_remainingExpanded),
              expandedChild: const Padding(
                padding: EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: null,
                    style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(AppTheme.darkGrey)),
                    child: Text('PAY NOW'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _sectionTitle('Cleared payments'),
            const SizedBox(height: 8),
            _collapsibleCard(
              expanded: _clearedExpanded,
              title: 'Amount paid Rs. 4933',
              leading: Icon(Icons.check_circle, color: Colors.green[700], size: 20),
              onTap: () => setState(() => _clearedExpanded = !_clearedExpanded),
              expandedChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Clearance Date', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const Text('10/10/2023', style: TextStyle(color: AppTheme.darkGrey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Payments summary'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
              ),
              child: Column(
                children: [
                  _summaryRow('Total Amount', 'Rs.3000'),
                  _summaryRow('Amount paid', 'Rs.1500'),
                  _summaryRow('Remaining Amount', 'Rs.1500'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
    );
  }

  Widget _collapsibleCard({
    required bool expanded,
    required String title,
    Widget? leading,
    required VoidCallback onTap,
    Widget? expandedChild,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            child: Row(
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 8)],
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.darkGrey))),
                Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppTheme.darkGrey),
              ],
            ),
          ),
          if (expanded && expandedChild != null) expandedChild,
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.darkGrey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.darkGrey)),
        ],
      ),
    );
  }
}
