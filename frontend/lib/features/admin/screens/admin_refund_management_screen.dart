import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Admin Refund Management Screen
/// Displays pending refunds and allows admin to approve/reject refunds
class AdminRefundManagementScreen extends StatefulWidget {
  const AdminRefundManagementScreen({super.key});

  @override
  State<AdminRefundManagementScreen> createState() =>
      _AdminRefundManagementScreenState();
}

class _AdminRefundManagementScreenState
    extends State<AdminRefundManagementScreen> {
  List<Map<String, dynamic>> _refunds = [];
  String _statusFilter = 'all';
  bool _isLoading = true;
  String? _error;

  static const _statusFilters = [
    'all',
    'refund_pending',
    'refund_provider_approved',
    'refund_under_review',
    'refunded',
    'refund_rejected'
  ];

  @override
  void initState() {
    super.initState();
    _loadRefunds();
  }

  Future<void> _loadRefunds() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final refunds = await ApiService.getRefunds();
      setState(() {
        _refunds = List<Map<String, dynamic>>.from(refunds);
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load refunds: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredRefunds {
    if (_statusFilter == 'all') return _refunds;

    return _refunds.where((r) {
      final status = r['status']?.toString().toLowerCase() ?? '';
      return status == _statusFilter;
    }).toList();
  }

  String _getStatusLabel(String? status) {
    final s = status?.toLowerCase() ?? '';
    if (s == 'refund_pending') return 'Pending Provider Review';
    if (s == 'refund_provider_approved') return 'Under Admin Review';
    if (s == 'refund_under_review') return 'Under Admin Review';
    if (s == 'refund_provider_rejected') return 'Rejected by Provider';
    if (s == 'refunded') return 'Refunded';
    if (s == 'refund_rejected') return 'Rejected by Admin';
    return status ?? 'Unknown';
  }

  Color _getStatusColor(String? status) {
    final s = status?.toLowerCase() ?? '';
    if (s == 'refund_pending') return Colors.orange;
    if (s == 'refund_provider_approved' || s == 'refund_under_review') {
      return Colors.blue;
    }
    if (s == 'refund_provider_rejected' || s == 'refund_rejected') {
      return Colors.red;
    }
    if (s == 'refunded') return Colors.green;
    return Colors.grey;
  }

  Future<void> _showRefundDetail(Map<String, dynamic> refund) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _RefundDetailModal(
        refund: refund,
        onApprove: () => _handleApproveRefund(refund),
        onReject: () => _handleRejectRefund(refund),
      ),
    );
  }

  Future<void> _handleApproveRefund(Map<String, dynamic> refund) async {
    final refundId = refund['id'];
    final referenceController = TextEditingController();

    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Refund'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Amount: Rs ${refund['amount']}'),
            const SizedBox(height: 16),
            TextField(
              controller: referenceController,
              decoration: InputDecoration(
                labelText: 'eSewa Reference *',
                hintText: 'e.g., ESW-12345678',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (referenceController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('eSewa reference is required')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (approved == true) {
      try {
        await ApiService.reviewRefund(
          refundId: refund['id'] as int,
          action: 'approve',
          refundReference: referenceController.text,
        );
        _loadRefunds();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Refund approved successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleRejectRefund(Map<String, dynamic> refund) async {
    final refundId = refund['id'];
    final reasonController = TextEditingController();

    final rejected = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Refund'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Amount: Rs ${refund['amount']}'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Reason *',
                hintText: 'Why are you rejecting this refund?',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rejection reason is required')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (rejected == true) {
      try {
        await ApiService.reviewRefund(
          refundId: refund['id'] as int,
          action: 'reject',
          adminNote: reasonController.text,
        );
        _loadRefunds();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Refund rejected')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightLavender,
      appBar: AppBar(
        title: const Text('Refund Management'),
        centerTitle: true,
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRefunds,
          ),
        ],
      ),
      body: _isLoading
          ? const AppPageShimmer()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRefunds,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Status Filter
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: _statusFilters.map((filter) {
                            final isActive = _statusFilter == filter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(
                                  filter == 'all'
                                      ? 'All'
                                      : filter
                                          .replaceAll('_', ' ')
                                          .toUpperCase(),
                                ),
                                selected: isActive,
                                onSelected: (selected) {
                                  setState(() => _statusFilter = filter);
                                },
                                backgroundColor: AppTheme.lightLavender,
                                selectedColor:
                                    AppTheme.customerPrimary.withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: isActive
                                      ? AppTheme.customerPrimary
                                      : Colors.grey,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // Refund List
                      if (_filteredRefunds.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.inbox_outlined,
                                  size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text(
                                'No refunds found',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredRefunds.length,
                          itemBuilder: (ctx, idx) {
                            final refund = _filteredRefunds[idx];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(refund['status'])
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.currency_exchange,
                                    color: _getStatusColor(refund['status']),
                                  ),
                                ),
                                title: Text('Booking #${refund['booking_id']}'),
                                subtitle: Text(
                                  'Rs ${refund['amount']} • ${_getStatusLabel(refund['status'])}',
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(refund['status'])
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _getStatusLabel(refund['status']),
                                    style: TextStyle(
                                      color: _getStatusColor(refund['status']),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                onTap: () => _showRefundDetail(refund),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _RefundDetailModal extends StatelessWidget {
  final Map<String, dynamic> refund;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RefundDetailModal({
    required this.refund,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      builder: (ctx, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Refund Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _DetailRow('Refund ID', '${refund['id']}'),
              _DetailRow('Booking ID', '${refund['booking_id']}'),
              _DetailRow('Amount', 'Rs ${refund['amount']}'),
              _DetailRow('Status', refund['status'] ?? 'Unknown'),
              _DetailRow(
                'Requested',
                _formatDate(refund['created_at']),
              ),
              if (refund['cancellation_reason'] != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Cancellation Reason',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(refund['cancellation_reason'] ?? ''),
              ],
              if (refund['provider_note'] != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Provider Note',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(refund['provider_note'] ?? ''),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onReject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade400,
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return date.toString();
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
