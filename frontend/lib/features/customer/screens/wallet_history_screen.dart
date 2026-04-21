import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/payment/screens/payment_receipt_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/esewa_service.dart';

/// Wallet History – shows real transactions from the backend (payments).
class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  late Future<Map<String, dynamic>> _walletFuture;

  @override
  void initState() {
    super.initState();
    _walletFuture = ApiService.getWallet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'walletHistory'),
            style:
                TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _walletFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppPageShimmer();
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${AppStrings.t(context, 'failedLoadWalletHistory')}\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
            );
          }

          final data = snapshot.data ?? {};
          final balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
          final transactions = (data['transactions'] as List<dynamic>?) ?? [];

          if (transactions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 72, color: Colors.grey[400]),
                    const SizedBox(height: 20),
                    Text(
                      AppStrings.t(context, 'noTransactionsYet'),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.t(context, 'paymentsAppearHere'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet,
                        color: AppTheme.customerPrimary),
                    const SizedBox(width: 12),
                    Text(AppStrings.t(context, 'walletBalance'),
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(ESewaService.formatAmount(balance),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final tx = transactions[index] as Map<String, dynamic>;
                    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                    final status = (tx['status'] as String?) ??
                        AppStrings.t(context, 'unknown');
                    final createdAt = tx['created_at'] as String?;
                    final bookingId = tx['booking_id']?.toString() ?? '';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 0),
                      title: Text(ESewaService.formatAmount(amount)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (createdAt != null) Text(createdAt),
                          Text(
                              '${AppStrings.t(context, 'status')}: ${status.toUpperCase()}'),
                        ],
                      ),
                      leading: Icon(
                        status.toLowerCase() == 'completed'
                            ? Icons.check_circle
                            : Icons.hourglass_bottom,
                        color: status.toLowerCase() == 'completed'
                            ? Colors.green
                            : Colors.orange,
                      ),
                      trailing:
                          const Icon(Icons.receipt_long_outlined, size: 20),
                      onTap: () async {
                        if (bookingId.isEmpty) return;
                        try {
                          final receipt =
                              await ApiService.getReceiptByBooking(bookingId);
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  PaymentReceiptScreen(receipt: receipt),
                            ),
                          );
                        } catch (_) {}
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
