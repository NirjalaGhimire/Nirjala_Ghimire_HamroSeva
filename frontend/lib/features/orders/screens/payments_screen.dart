import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
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
        title: Text(AppStrings.t(context, 'payments'),
            style: const TextStyle(
                color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(AppStrings.t(context, 'activePayment')),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06), blurRadius: 6)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.t(context, 'materialPayment'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkGrey)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppStrings.t(context, 'amount'),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600])),
                            const Text('Rs. 1500',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.darkGrey)),
                          ]),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(AppStrings.t(context, 'dueDate'),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600])),
                            const Text('10/10/2023',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.darkGrey)),
                          ]),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(
                              content: Text(
                                  AppStrings.t(context, 'payNowComingSoon')))),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.darkGrey,
                          foregroundColor: AppTheme.white),
                      child: Text(AppStrings.t(context, 'payNowUpper')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle(AppStrings.t(context, 'remainingPayments')),
            const SizedBox(height: 8),
            _collapsibleCard(
              expanded: _remainingExpanded,
              title: AppStrings.t(context, 'paymentAmountRs4933'),
              onTap: () =>
                  setState(() => _remainingExpanded = !_remainingExpanded),
              expandedChild: Padding(
                padding: EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: null,
                    style: const ButtonStyle(
                        backgroundColor:
                            WidgetStatePropertyAll(AppTheme.darkGrey)),
                    child: Text(AppStrings.t(context, 'payNowUpper')),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _sectionTitle(AppStrings.t(context, 'clearedPayments')),
            const SizedBox(height: 8),
            _collapsibleCard(
              expanded: _clearedExpanded,
              title: AppStrings.t(context, 'amountPaidRs4933'),
              leading:
                  Icon(Icons.check_circle, color: Colors.green[700], size: 20),
              onTap: () => setState(() => _clearedExpanded = !_clearedExpanded),
              expandedChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppStrings.t(context, 'clearanceDate'),
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const Text('10/10/2023',
                        style: TextStyle(color: AppTheme.darkGrey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle(AppStrings.t(context, 'paymentsSummary')),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06), blurRadius: 6)
                ],
              ),
              child: Column(
                children: [
                  _summaryRow(AppStrings.t(context, 'totalAmount'), 'Rs.3000'),
                  _summaryRow(AppStrings.t(context, 'amountPaid'), 'Rs.1500'),
                  _summaryRow(
                      AppStrings.t(context, 'remainingAmount'), 'Rs.1500'),
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
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
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
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            child: Row(
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 8)],
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppTheme.darkGrey))),
                Icon(expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.darkGrey),
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
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppTheme.darkGrey)),
        ],
      ),
    );
  }
}
