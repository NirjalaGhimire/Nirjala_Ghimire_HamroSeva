import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class ESewaService {
  static const String _merchantCode = 'EPAYTEST';
  static const String _apiUrl = 'https://uat.esewa.com.np/epay/main';
  
  /// Generate eSewa payment URL
  static String generatePaymentUrl({
    required double amount,
    required String productId,
    required String productName,
    String? transactionId,
  }) {
    final txId = transactionId ?? const Uuid().v4();
    
    final params = {
      'amt': amount.toString(),
      'pdc': productId,
      'psc': 'NR',
      'pcc': 'NP',
      'txAmt': '0',
      'tAmt': amount.toString(),
      'pid': txId,
      'scd': _merchantCode,
    };
    
    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    
    return '$_apiUrl?$queryString';
  }
  
  /// Launch eSewa payment
  static Future<bool> launchPayment({
    required double amount,
    required String productId,
    required String productName,
    String? transactionId,
  }) async {
    try {
      final url = generatePaymentUrl(
        amount: amount,
        productId: productId,
        productName: productName,
        transactionId: transactionId,
      );
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        debugPrint('Could not launch eSewa URL: $url');
        return false;
      }
    } catch (e) {
      debugPrint('Error launching eSewa payment: $e');
      return false;
    }
  }
  
  /// Verify eSewa payment (simplified - in real app, this would call your backend)
  static bool verifyPayment({
    required String transactionId,
    required double amount,
    Map<String, String>? responseData,
  }) {
    // In a real implementation, you would:
    // 1. Send the response data to your backend
    // 2. Backend verifies with eSewa API
    // 3. Backend returns verification result
    
    // For demo purposes, we'll assume payment is successful
    // if we receive response data
    return responseData != null && responseData.isNotEmpty;
  }
  
  /// Format amount for display
  static String formatAmount(double amount) {
    return 'Rs. ${amount.toStringAsFixed(2)}';
  }
}

/// eSewa Payment Result
class ESewaPaymentResult {
  final bool success;
  final String? transactionId;
  final String? message;
  final double? amount;
  
  ESewaPaymentResult({
    required this.success,
    this.transactionId,
    this.message,
    this.amount,
  });
}
