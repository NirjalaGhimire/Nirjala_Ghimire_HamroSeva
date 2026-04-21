import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/chat/screens/chat_thread_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Customer Chat tab: list of conversations.
class CustomerChatTabScreen extends StatefulWidget {
  const CustomerChatTabScreen({super.key});

  @override
  State<CustomerChatTabScreen> createState() => _CustomerChatTabScreenState();
}

class _CustomerChatTabScreenState extends State<CustomerChatTabScreen> {
  bool _isLoading = true;
  List<dynamic> _threads = [];

  @override
  void initState() {
    super.initState();
    _loadThreads();
  }

  Future<void> _loadThreads() async {
    setState(() => _isLoading = true);
    try {
      final threads = await ApiService.getChatThreads();
      if (mounted) {
        setState(() {
          _threads = threads;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.t(context, 'unableLoadChats')}: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.orange[800],
          ),
        );
      }
    }
    if (mounted && _isLoading) setState(() => _isLoading = false);
  }

  static String _formatThreadTime(dynamic raw) {
    if (raw == null) return '';
    String s = raw.toString();
    if (s.isEmpty) return '';
    try {
      final dt = DateTime.tryParse(s);
      if (dt == null) return s;
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          AppStrings.t(context, 'chat'),
          style: const TextStyle(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
      ),
      body: _isLoading
          ? const AppPageShimmer()
          : _threads.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadThreads,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _threads.length,
                    itemBuilder: (context, index) {
                      final thread = _threads[index] as Map<String, dynamic>;
                      final name =
                          (thread['provider_name'] as String?) ?? 'Provider';
                      final service = (thread['service_title'] as String?) ?? '';
                      final lastMessage =
                          (thread['last_message'] as String?) ?? '';
                      final time = _formatThreadTime(thread['last_message_at']);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.customerPrimary.withOpacity(0.2),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: AppTheme.customerPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (service.isNotEmpty)
                              Text(
                                service,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            Text(
                              lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        trailing: Text(
                          time,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        onTap: () {
                          final bookingId = thread['booking_id'] as int?;
                          if (bookingId != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatThreadScreen(
                                  bookingId: bookingId,
                                  title: name,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.t(context, 'noChatsYet'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.t(context, 'chatEmptySubtitle'),
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
