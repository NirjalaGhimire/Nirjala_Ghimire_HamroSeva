import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PaymentReceiptScreen extends StatelessWidget {
  const PaymentReceiptScreen({
    super.key,
    required this.receipt,
  });

  final Map<String, dynamic> receipt;

  String _fmtMoney(dynamic value) {
    final n = (value is num)
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return 'Rs ${n.toStringAsFixed(2)}';
  }

  String _fmtDate(dynamic value) {
    final s = (value ?? '').toString();
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
  }

  String _paymentStatusLabel(dynamic value) {
    final status = (value ?? '').toString().trim().toLowerCase();
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'refunded':
        return 'Refunded';
      case 'refund_rejected':
        return 'Refund Rejected';
      case 'pending':
        return 'Pending';
      default:
        return status.isEmpty ? '-' : status.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _refundStatusLabel(dynamic value) {
    final status = (value ?? 'not_applicable').toString().trim().toLowerCase();
    switch (status) {
      case 'not_applicable':
        return 'Not Applicable';
      case 'refund_pending':
        return 'Refund Pending';
      case 'refund_provider_approved':
      case 'refund_under_review':
      case 'refund_processing':
        return 'Refund Under Review';
      case 'refund_rejected':
        return 'Refund Rejected';
      case 'refund_successful':
      case 'refunded':
        return 'Refund Successful';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  Future<Uint8List> _buildPdf() async {
    final doc = pw.Document();
    final receiptId = (receipt['receipt_id'] ?? 'N/A').toString();
    final bookingId = (receipt['booking_id'] ?? 'N/A').toString();
    final customer = (receipt['customer_name'] ?? '').toString();
    final provider = (receipt['provider_name'] ?? '').toString();
    final service = (receipt['service_name'] ?? '').toString();
    final issued = _fmtDate(receipt['issued_at']);

    pw.Widget row(String k, String v, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(k, style: const pw.TextStyle(fontSize: 10)),
              pw.Text(v,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ],
          ),
        );

    doc.addPage(
      pw.Page(
        build: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Hamro Sewa',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Payment Receipt',
                  style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 16),
              row('Receipt ID', receiptId),
              row('Booking ID', bookingId),
              row('Date/Time', issued),
              row('Customer', customer.isEmpty ? '-' : customer),
              row('Provider', provider.isEmpty ? '-' : provider),
              row('Service', service.isEmpty ? '-' : service),
              row('Payment Method',
                  (receipt['payment_method'] ?? 'esewa').toString()),
              pw.Divider(),
              row('Paid Amount', _fmtMoney(receipt['paid_amount'])),
              row('Discount', _fmtMoney(receipt['discount_amount'])),
              row('Tax', _fmtMoney(receipt['tax_amount'])),
              row('Service Charge', _fmtMoney(receipt['service_charge'])),
              pw.Divider(),
              row('Final Total', _fmtMoney(receipt['final_total']), bold: true),
              row('Payment Status',
                  _paymentStatusLabel(receipt['payment_status']),
                  bold: true),
              row('Refund Status',
                  _refundStatusLabel(receipt['refund_status'])),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    final receiptId = (receipt['receipt_id'] ?? 'N/A').toString();
    final bookingId = (receipt['booking_id'] ?? 'N/A').toString();
    final customer = (receipt['customer_name'] ?? '').toString();
    final provider = (receipt['provider_name'] ?? '').toString();
    final service = (receipt['service_name'] ?? '').toString();
    final issued = _fmtDate(receipt['issued_at']);
    final fileName = 'receipt_booking_$bookingId.pdf';

    Widget dataRow(String label, String value, {bool emphasized = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(color: Colors.grey[700], fontSize: 14)),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
                color: emphasized ? AppTheme.customerPrimary : Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Receipt',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hamro Sewa',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Official Payment Receipt'),
                const Divider(height: 24),
                dataRow('Receipt ID', receiptId),
                dataRow('Booking ID', bookingId),
                dataRow('Customer', customer.isEmpty ? '-' : customer),
                dataRow('Provider', provider.isEmpty ? '-' : provider),
                dataRow('Service', service.isEmpty ? '-' : service),
                dataRow('Date & Time', issued),
                dataRow('Payment Method',
                    (receipt['payment_method'] ?? 'esewa').toString()),
                const Divider(height: 24),
                dataRow('Paid Amount', _fmtMoney(receipt['paid_amount'])),
                dataRow('Discount', _fmtMoney(receipt['discount_amount'])),
                dataRow('Tax', _fmtMoney(receipt['tax_amount'])),
                dataRow('Service Charge', _fmtMoney(receipt['service_charge'])),
                const Divider(height: 24),
                dataRow('Final Total', _fmtMoney(receipt['final_total']),
                    emphasized: true),
                dataRow('Payment Status',
                    _paymentStatusLabel(receipt['payment_status']),
                    emphasized: true),
                dataRow('Refund Status',
                    _refundStatusLabel(receipt['refund_status'])),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final pdf = await _buildPdf();
                        await Printing.layoutPdf(
                            onLayout: (_) async => pdf, name: fileName);
                      },
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Download Receipt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.customerPrimary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final pdf = await _buildPdf();
                        await Printing.sharePdf(bytes: pdf, filename: fileName);
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share Receipt'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
