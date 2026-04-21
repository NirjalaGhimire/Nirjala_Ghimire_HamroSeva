import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:intl/intl.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';

/// View AI chat history, grouped by date (stored in Supabase `seva_ai_chat`).
class AiHistoryScreen extends StatefulWidget {
  const AiHistoryScreen({super.key});

  @override
  State<AiHistoryScreen> createState() => _AiHistoryScreenState();
}

class _AiHistoryScreenState extends State<AiHistoryScreen> {
  DateTimeRange? _range;
  bool _loading = true;
  String? _error;
  List<dynamic> _byDate = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: now.subtract(const Duration(days: 13)), end: now);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _pickRange() async {
    final initial = _range ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 13)),
          end: DateTime.now(),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: initial,
      helpText: 'Select date range',
    );
    if (picked == null) return;
    setState(() => _range = picked);
    await _load();
  }

  Future<void> _load() async {
    final r = _range;
    if (r == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.aiHistory(
        startDate: _fmtDate(r.start),
        endDate: _fmtDate(r.end),
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );
      final byDate = res['by_date'];
      setState(() {
        _byDate = (byDate is List) ? byDate : [];
        _loading = false;
      });
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
      setState(() {
        _error = s;
        _loading = false;
        _byDate = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _range;
    final rangeLabel = r == null ? 'Select range' : '${_fmtDate(r.start)} → ${_fmtDate(r.end)}';
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('AI History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _pickRange,
            tooltip: 'Pick dates',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    rangeLabel,
                    style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Filter'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _load(),
                    decoration: InputDecoration(
                      hintText: 'Search query or answer...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.trim().isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                _load();
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _load,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.customerPrimary,
                    foregroundColor: AppTheme.white,
                  ),
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const AppPageShimmer()
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),
                      )
                    : _byDate.isEmpty
                        ? Center(
                            child: Text(
                              'No AI chats in this date range.',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _byDate.length,
                            itemBuilder: (context, i) {
                              final day = _byDate[i] as Map<String, dynamic>;
                              final date = (day['date'] ?? '').toString();
                              final msgs = (day['messages'] is List)
                                  ? List<Map<String, dynamic>>.from(day['messages'] as List)
                                  : <Map<String, dynamic>>[];
                              return _DaySection(date: date, messages: msgs);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.date, required this.messages});
  final String date;
  final List<Map<String, dynamic>> messages;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          date,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800]),
        ),
        const SizedBox(height: 10),
        ...messages.map((m) {
          final q = (m['query'] ?? '').toString();
          final a = (m['answer'] ?? '').toString();
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(q, style: const TextStyle(fontSize: 14, height: 1.35)),
                  const SizedBox(height: 10),
                  Text('AI', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(a.isEmpty ? '—' : a, style: const TextStyle(fontSize: 14, height: 1.35)),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
      ],
    );
  }
}

