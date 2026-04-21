import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/esewa_service.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:esewa_flutter_sdk/esewa_config.dart';
import 'package:esewa_flutter_sdk/esewa_flutter_sdk.dart';
import 'package:esewa_flutter_sdk/esewa_payment.dart';
import 'package:esewa_flutter_sdk/esewa_payment_success_result.dart';
import 'package:hamro_sewa_frontend/features/payment/screens/payment_receipt_screen.dart';

class ESewaPaymentScreen extends StatefulWidget {
  final double amount;
  final String serviceName;
  final String bookingId;
  final String? serviceId;

  const ESewaPaymentScreen({
    super.key,
    required this.amount,
    required this.serviceName,
    required this.bookingId,
    this.serviceId,
  });

  @override
  State<ESewaPaymentScreen> createState() => _ESewaPaymentScreenState();
}

class _ESewaPaymentScreenState extends State<ESewaPaymentScreen> {
  bool _isProcessing = false;
  bool _paymentCompleted = false;
  bool _paymentFailed = false;
  String? _errorMessage;
  Map<String, dynamic>? _receipt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'eSewaPayment')),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPaymentCard(),
            const SizedBox(height: 24),
            if (!_paymentCompleted && !_paymentFailed) ...[
              _buildPaymentButton(),
              const SizedBox(height: 12),
              _buildCancelButton(),
            ] else if (_paymentCompleted) ...[
              _buildSuccessCard(),
              const SizedBox(height: 16),
              _buildReceiptButtons(),
              const SizedBox(height: 12),
              _buildContinueButton(),
            ] else ...[
              _buildFailureCard(),
              const SizedBox(height: 16),
              _buildRetryButton(),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Colors.green[700],
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t(context, 'eSewaPayment'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        AppStrings.t(context, 'secureFastPayment'),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow('Service', widget.serviceName),
            const SizedBox(height: 12),
            _buildDetailRow('Booking ID', widget.bookingId),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            _buildDetailRow(
              'Total Amount',
              ESewaService.formatAmount(widget.amount),
              isAmount: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAmount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isAmount ? FontWeight.bold : FontWeight.w500,
            color: isAmount ? Colors.green[700] : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isProcessing
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: AppShimmerLoader(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(AppStrings.t(context, 'processing')),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance_wallet),
                  const SizedBox(width: 8),
                  Text(AppStrings.t(context, 'payWithEsewa')),
                ],
              ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(AppStrings.t(context, 'cancel')),
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green[300]!),
      ),
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.green[700],
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.t(context, 'paymentSuccessful'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.t(context, 'paymentSuccessMessage').replaceFirst(
                '{amount}',
                ESewaService.formatAmount(widget.amount),
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailureCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange[300]!),
      ),
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.orange[700],
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.t(context, 'paymentFailedOrCancelled'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.t(context, 'paymentTryAgainHint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetryButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _paymentFailed = false;
            _errorMessage = null;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(AppStrings.t(context, 'tryAgain')),
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(AppStrings.t(context, 'continue')),
      ),
    );
  }

  Widget _buildReceiptButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _receipt == null
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PaymentReceiptScreen(receipt: _receipt!),
                    ),
                  ),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('View Receipt'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.customerPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Future<void> _loadReceipt() async {
    try {
      final data = await ApiService.getReceiptByBooking(widget.bookingId);
      if (!mounted) return;
      setState(() => _receipt = data);
    } catch (_) {
      // Receipt creation may lag a bit; keep success state unaffected.
    }
  }

  Widget _buildErrorCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red[300]!),
      ),
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Create pending payment and get transaction_id (productId)
      final data = await ApiService.initiatePayment(
        bookingId: widget.bookingId,
        amount: widget.amount,
      );
      final transactionId = data['transaction_id'] as String?;
      if (transactionId == null || transactionId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Invalid response from server.';
          _isProcessing = false;
        });
        return;
      }

      // Launch official eSewa SDK (native payment flow)
      EsewaFlutterSdk.initPayment(
        esewaConfig: EsewaConfig(
          environment: Environment.test,
          clientId: ESewaService.clientId,
          secretId: ESewaService.secretKey,
        ),
        esewaPayment: EsewaPayment(
          productId: transactionId,
          productName: widget.serviceName,
          productPrice: widget.amount.toString(),
        ),
        onPaymentSuccess: (EsewaPaymentSuccessResult result) async {
          if (!mounted) return;
          try {
            await ApiService.verifyAndCompletePayment(
              refId: result.refId,
              productId: result.productId,
              bookingId: widget.bookingId,
              totalAmount: result.totalAmount,
            );
            if (!mounted) return;
            setState(() {
              _paymentCompleted = true;
              _isProcessing = false;
            });
            await _loadReceipt();
          } catch (e) {
            if (!mounted) return;
            setState(() {
              _errorMessage = 'Verification failed: ${e.toString()}';
              _isProcessing = false;
            });
          }
        },
        onPaymentFailure: (data) {
          if (!mounted) return;
          setState(() {
            _paymentFailed = true;
            _errorMessage = data?.toString() ?? 'Payment failed.';
            _isProcessing = false;
          });
        },
        onPaymentCancellation: (data) {
          if (!mounted) return;
          setState(() {
            _paymentFailed = true;
            _errorMessage = 'Payment was cancelled.';
            _isProcessing = false;
          });
        },
      );
      // Stop spinner after a short delay so user isn't stuck if SDK doesn't open
      // (e.g. emulator without eSewa app). Callbacks still run when SDK returns.
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _isProcessing = false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Payment failed: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }
}


