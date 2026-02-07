import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/services/esewa_service.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('eSewa Payment'),
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
              _buildDemoPaymentButton(),
              const SizedBox(height: 16),
              _buildCancelButton(),
            ] else if (_paymentCompleted) ...[
              _buildSuccessCard(),
              const SizedBox(height: 16),
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
                      const Text(
                        'eSewa Payment',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Secure & Fast Payment',
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
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Processing...'),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet),
                  SizedBox(width: 8),
                  Text('Pay with eSewa'),
                ],
              ),
      ),
    );
  }

  Widget _buildDemoPaymentButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isProcessing ? null : _processDemoPayment,
        icon: const Icon(Icons.science_outlined, size: 20),
        label: const Text('Demo payment (eSewa unreachable)'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey[700],
          side: BorderSide(color: Colors.grey[400]!),
          padding: const EdgeInsets.symmetric(vertical: 14),
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
        child: const Text('Cancel'),
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
            const Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your payment of ${ESewaService.formatAmount(widget.amount)} has been processed successfully.',
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
              'Payment Failed or Cancelled',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You can try again or cancel.',
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
        child: const Text('Try Again'),
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
        child: const Text('Continue'),
      ),
    );
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
      final data = await ApiService.initiatePayment(
        bookingId: widget.bookingId,
        amount: widget.amount,
      );
      final paymentUrl = data['payment_url'] as String?;
      if (paymentUrl == null || paymentUrl.isEmpty) {
        setState(() {
          _errorMessage = 'Invalid response from server.';
          _isProcessing = false;
        });
        return;
      }

      if (!mounted) return;
      final result = await Navigator.of(context).push<Map<String, String>>(
        MaterialPageRoute(
          builder: (context) => _ESewaWebViewScreen(
            paymentUrl: paymentUrl,
            bookingId: widget.bookingId,
          ),
        ),
      );

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        if (result != null && (result['success'] ?? '') == 'true') {
          _paymentCompleted = true;
        } else {
          _paymentFailed = true;
          _errorMessage = result?['message'] ?? 'Payment was not completed.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Payment failed: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  /// Complete payment without eSewa (for testing when the gateway page does not load).
  Future<void> _processDemoPayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    try {
      final data = await ApiService.initiatePayment(
        bookingId: widget.bookingId,
        amount: widget.amount,
      );
      final transactionId = data['transaction_id'] as String?;
      await ApiService.completeDemoPayment(
        bookingId: widget.bookingId,
        transactionId: transactionId,
      );
      if (!mounted) return;
      setState(() {
        _paymentCompleted = true;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Demo payment failed: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }
}

/// Full-screen WebView that loads the eSewa payment URL and intercepts
/// hamrosewa://payment/success and hamrosewa://payment/failure redirects.
class _ESewaWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String bookingId;

  const _ESewaWebViewScreen({
    required this.paymentUrl,
    required this.bookingId,
  });

  @override
  State<_ESewaWebViewScreen> createState() => _ESewaWebViewScreenState();
}

class _ESewaWebViewScreenState extends State<_ESewaWebViewScreen> {
  late final WebViewController _controller;
  String? _loadError;

  /// Chrome desktop User-Agent so eSewa serves the payment page (some gateways block or redirect in-app WebViews).
  static const String _chromeDesktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            if (url.startsWith('hamrosewa://payment/success')) {
              final uri = Uri.parse(url);
              Navigator.of(context).pop({
                'success': 'true',
                'booking_id': uri.queryParameters['booking_id'] ?? widget.bookingId,
                'transaction_id': uri.queryParameters['transaction_id'] ?? '',
              });
              return NavigationDecision.prevent;
            }
            if (url.startsWith('hamrosewa://payment/failure')) {
              final uri = Uri.parse(url);
              Navigator.of(context).pop({
                'success': 'false',
                'message': 'Payment failed or was cancelled.',
                'booking_id': uri.queryParameters['booking_id'] ?? widget.bookingId,
                'transaction_id': uri.queryParameters['transaction_id'] ?? '',
              });
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            if ((error.isForMainFrame ?? true) && mounted) {
              setState(() {
                _loadError = error.description ?? 'Could not load payment page.';
              });
            }
          },
        ),
      );
    _setUserAgentAndLoad();
  }

  Future<void> _setUserAgentAndLoad() async {
    if (Platform.isAndroid) {
      final platform = _controller.platform;
      if (platform is AndroidWebViewController) {
        await platform.setUserAgent(_chromeDesktopUserAgent);
      }
    }
    if (!mounted) return;
    _controller.loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _retryLoad() {
    setState(() => _loadError = null);
    _setUserAgentAndLoad();
  }

  Widget _buildFixDnsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dns, color: Colors.blue[700], size: 22),
              const SizedBox(width: 8),
              Text(
                'Fix DNS (payment site not loading)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your network may not resolve the payment gateway. Use Google or Cloudflare DNS:\n'
            '• Open Settings → Network & Internet → WiFi → your network.\n'
            '• Tap Advanced or IP settings → set DNS 1 to 8.8.8.8, DNS 2 to 8.8.4.4 (or use 1.1.1.1).\n'
            '• Save, then return here and tap Retry.',
            style: TextStyle(fontSize: 13, color: Colors.blue[900], height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eSewa Payment'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop({
            'success': 'false',
            'message': 'Payment cancelled.',
          }),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loadError != null)
            Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(24),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off, size: 64, color: Colors.orange[700]),
                      const SizedBox(height: 16),
                      Text(
                        'Payment page could not load',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$_loadError\n\n'
                        'Your phone needs internet (WiFi or mobile data) to load the payment page. '
                        'If you see "ERR_NAME_NOT_RESOLVED" or "DNS", try the Fix DNS step below.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      _buildFixDnsCard(),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          TextButton.icon(
                            onPressed: _retryLoad,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse(widget.paymentUrl);
                              try {
                                final launched = await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                                if (context.mounted) {
                                  if (launched) {
                                    Navigator.of(context).pop({
                                      'success': 'false',
                                      'message': 'Opened in browser. Return to the app after payment.',
                                    });
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Could not open browser. Try Retry or use another device.'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Could not open link: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.open_in_browser, size: 20),
                            label: const Text('Open in browser'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop({
                              'success': 'false',
                              'message': 'Payment page could not load.',
                            }),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                            child: const Text('Back'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
