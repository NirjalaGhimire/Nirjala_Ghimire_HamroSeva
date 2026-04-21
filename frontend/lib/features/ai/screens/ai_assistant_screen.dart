import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/ai/screens/ai_history_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';

/// Simple chat-style UI for Hamro Sewa AI (backend RAG + OpenRouter).
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _Msg {
  _Msg({required this.isUser, required this.text});
  final bool isUser;
  final String text;
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [
    _Msg(
      isUser: false,
      text:
          'Ask in plain English — for example: "Best rated electrician near Kathmandu" or "Affordable plumbers in Lalitpur". '
          'I only use providers from Hamro Sewa\'s database.',
    ),
  ];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final q = _controller.text.trim();
    if (q.isEmpty || _loading) return;
    setState(() {
      _messages.add(_Msg(isUser: true, text: q));
      _loading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final data = await ApiService.aiQuery(q);
      final answer = data['answer'] as String?;
      final err = data['error'] as String?;
      final retrieved = data['retrieved'];
      var text = answer ?? err ?? 'No response.';
      if (retrieved is List && retrieved.isNotEmpty && answer != null) {
        text +=
            '\n\n—\nFound ${retrieved.length} matching record(s) in the database.';
      }
      if (mounted) {
        setState(() => _messages.add(_Msg(isUser: false, text: text)));
      }
    } catch (e) {
      final s = e.toString().replaceFirst('Exception: ', '');
      if (s.contains('SESSION_EXPIRED') || s.contains('token')) {
        await TokenStorage.clearTokens();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPrototypeScreen()),
            (_) => false,
          );
        }
        return;
      }
      if (mounted) {
        setState(() => _messages.add(_Msg(isUser: false, text: 'Error: $s')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('AI Assistant',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (context, i) {
                if (_loading && i == _messages.length) {
                  return const AiMessageShimmer();
                }
                final m = _messages[i];
                return Align(
                  alignment:
                      m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.88),
                    decoration: BoxDecoration(
                      color: m.isUser
                          ? AppTheme.customerPrimary.withOpacity(0.15)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      m.text,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Ask about services or providers…',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppTheme.customerPrimary,
                    borderRadius: BorderRadius.circular(12),
                    child: IconButton(
                      onPressed: _loading ? null : _send,
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
