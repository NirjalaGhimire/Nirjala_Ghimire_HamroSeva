import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:share_plus/share_plus.dart';

/// Referral & Loyalty – invite code, share link, history (backend-connected).
class ReferralLoyaltyScreen extends StatefulWidget {
  const ReferralLoyaltyScreen({super.key});

  @override
  State<ReferralLoyaltyScreen> createState() => _ReferralLoyaltyScreenState();
}

class _ReferralLoyaltyScreenState extends State<ReferralLoyaltyScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getReferralProfile();
      if (!mounted) return;
      setState(() {
        _profile = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _shareCode() async {
    final code = _profile?['referral_code'] as String?;
    if (code == null || code.isEmpty) return;
    try {
      // Use text only; 'subject' can cause crashes on some Android devices
      await Share.share(
        'My Hamro Sewa referral code: $code\n\nSign up and book a service – we both earn loyalty points!',
      );
    } catch (e) {
      if (!mounted) return;
      final text = 'My Hamro Sewa referral code: $code\n\nSign up and book a service – we both earn loyalty points!';
      try {
        await Clipboard.setData(ClipboardData(text: text));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Referral message copied to clipboard. You can paste it to share.')),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Referral & Loyalty', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.customerPrimary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700])),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: AppTheme.customerPrimary.withOpacity(0.5)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Text('Your referral code', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                const SizedBox(height: 8),
                                SelectableText(
                                  _profile?['referral_code'] as String? ?? '—',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    color: AppTheme.customerPrimary,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _shareCode,
                                    icon: const Icon(Icons.share),
                                    label: const Text('Share with friends'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.customerPrimary,
                                      foregroundColor: AppTheme.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('How it works', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _stepTile(1, 'Share your code or link with friends'),
                        _stepTile(2, 'They sign up and book a service'),
                        _stepTile(3, 'You both earn loyalty points'),
                        const SizedBox(height: 24),
                        const Text('Loyalty points balance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          color: AppTheme.customerPrimary.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total points', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                Text(
                                  '${_profile?['loyalty_points'] ?? 0}',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.customerPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Referral history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildReferralHistory(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildReferralHistory() {
    final list = _profile?['referral_history'] as List<dynamic>?;
    if (list == null || list.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[300]!),
        ),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text('No referrals yet. Share your code to get started.', style: TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[300]),
        itemBuilder: (context, i) {
          final r = list[i] as Map<String, dynamic>? ?? {};
          final statusLabel = r['status_label'] as String? ?? (r['status'] as String? ?? '—');
          final points = r['points_earned'] as int? ?? 0;
          final createdAt = r['created_at'] as String?;
          return ListTile(
            title: Text(statusLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: createdAt != null ? Text(createdAt, style: TextStyle(fontSize: 12, color: Colors.grey[600])) : null,
            trailing: points > 0 ? Text('+$points pts', style: const TextStyle(color: AppTheme.customerPrimary, fontWeight: FontWeight.w600)) : null,
          );
        },
      ),
    );
  }

  Widget _stepTile(int n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.customerPrimary,
            child: Text('$n', style: const TextStyle(color: AppTheme.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: Colors.grey[700]))),
        ],
      ),
    );
  }
}
