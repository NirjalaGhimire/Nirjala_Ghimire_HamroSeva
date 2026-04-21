import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:flutter/services.dart';
import 'package:hamro_sewa_frontend/core/referral_share_content.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final text = ReferralShareContent.buildMessage(code);
    try {
      // Prefer WhatsApp handoff for stable invite flow.
      final waUri = Uri.parse(
        'https://wa.me/?text=${Uri.encodeComponent(text)}',
      );

      final launched = await launchUrl(
        waUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not open WhatsApp share target');
      }
    } catch (e) {
      if (!mounted) return;
      try {
        await Clipboard.setData(ClipboardData(text: text));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppStrings.t(context, 'referralMessageCopiedToClipboard'))),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${AppStrings.t(context, 'couldNotShare')}: ${e.toString().replaceFirst('Exception: ', '')}'),
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
        title: Text(AppStrings.t(context, 'referralLoyalty'),
            style: const TextStyle(
                color: AppTheme.white, fontWeight: FontWeight.bold)),
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
          ? const Center(
              child: AppShimmerLoader(color: AppTheme.customerPrimary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[700])),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            onPressed: _load,
                            child: Text(AppStrings.t(context, 'retry'))),
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
                            side: BorderSide(
                                color:
                                    AppTheme.customerPrimary.withOpacity(0.5)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Text(AppStrings.t(context, 'yourReferralCode'),
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.grey)),
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
                                    label: Text(AppStrings.t(
                                        context, 'shareWithFriends')),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.customerPrimary,
                                      foregroundColor: AppTheme.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(AppStrings.t(context, 'howItWorks'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _stepTile(1,
                            AppStrings.t(context, 'shareCodeWithFriendsStep')),
                        _stepTile(
                            2, AppStrings.t(context, 'friendsSignUpStep')),
                        _stepTile(
                            3, AppStrings.t(context, 'bothEarnPointsStep')),
                        const SizedBox(height: 24),
                        Text(AppStrings.t(context, 'loyaltyPointsBalance'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          color: AppTheme.customerPrimary.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(AppStrings.t(context, 'totalPoints'),
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.grey)),
                                Text(
                                  '${_profile?['loyalty_points'] ?? 0}',
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.customerPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(AppStrings.t(context, 'referralHistory'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
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
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(AppStrings.t(context, 'noReferralsYetHint'),
                style: const TextStyle(color: Colors.grey)),
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
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.grey[300]),
        itemBuilder: (context, i) {
          final r = list[i] as Map<String, dynamic>? ?? {};
          final statusLabel =
              r['status_label'] as String? ?? (r['status'] as String? ?? '—');
          final points = r['points_earned'] as int? ?? 0;
          final createdAt = r['created_at'] as String?;
          return ListTile(
            title: Text(statusLabel,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: createdAt != null
                ? Text(createdAt,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]))
                : null,
            trailing: points > 0
                ? Text('+$points ${AppStrings.t(context, 'pointsAbbrev')}',
                    style: const TextStyle(
                        color: AppTheme.customerPrimary,
                        fontWeight: FontWeight.w600))
                : null,
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
            child: Text('$n',
                style: const TextStyle(
                    color: AppTheme.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text, style: TextStyle(color: Colors.grey[700]))),
        ],
      ),
    );
  }
}
