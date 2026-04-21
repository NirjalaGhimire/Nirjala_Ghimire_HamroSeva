import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

class ProviderTimeSlotsScreen extends StatefulWidget {
  const ProviderTimeSlotsScreen({super.key});

  @override
  State<ProviderTimeSlotsScreen> createState() => _ProviderTimeSlotsScreenState();
}

class _ProviderTimeSlotsScreenState extends State<ProviderTimeSlotsScreen> {
  List<dynamic> _slots = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final slots = await ApiService.getProviderTimeSlots(activeOnly: false);
      if (!mounted) return;
      setState(() {
        _slots = slots;
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

  Future<void> _showEditor({Map<String, dynamic>? existing}) async {
    final noteCtrl = TextEditingController(text: (existing?['note'] ?? '').toString());
    DateTime? selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    bool isActive = (existing?['is_active'] ?? true) == true;

    final slotDateText = (existing?['slot_date'] ?? '').toString().trim();
    if (slotDateText.isNotEmpty) {
      selectedDate = DateTime.tryParse(slotDateText);
    }
    startTime = _timeFromText((existing?['start_time'] ?? '').toString());
    endTime = _timeFromText((existing?['end_time'] ?? '').toString());

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            Future<void> pickDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: ctx,
                initialDate: selectedDate ?? now,
                firstDate: now.subtract(const Duration(days: 365)),
                lastDate: now.add(const Duration(days: 365 * 2)),
              );
              if (picked != null) {
                setLocalState(() => selectedDate = picked);
              }
            }

            Future<void> pickStart() async {
              final picked = await showTimePicker(
                context: ctx,
                initialTime: startTime ?? const TimeOfDay(hour: 9, minute: 0),
              );
              if (picked != null) {
                setLocalState(() => startTime = picked);
              }
            }

            Future<void> pickEnd() async {
              final picked = await showTimePicker(
                context: ctx,
                initialTime: endTime ?? const TimeOfDay(hour: 10, minute: 0),
              );
              if (picked != null) {
                setLocalState(() => endTime = picked);
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Text(existing == null ? 'Add Time Slot' : 'Edit Time Slot'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _pickerField(
                      label: 'Date',
                      value: selectedDate == null ? 'Select date' : _formatDate(selectedDate!),
                      icon: Icons.event_outlined,
                      onTap: pickDate,
                    ),
                    const SizedBox(height: 12),
                    _pickerField(
                      label: 'Start Time',
                      value: startTime == null ? 'Select start time' : _formatTime(startTime!),
                      icon: Icons.schedule_outlined,
                      onTap: pickStart,
                    ),
                    const SizedBox(height: 12),
                    _pickerField(
                      label: 'End Time',
                      value: endTime == null ? 'Select end time' : _formatTime(endTime!),
                      icon: Icons.schedule_send_outlined,
                      onTap: pickEnd,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Note',
                        hintText: 'Optional note shown to customers',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isActive,
                      onChanged: (v) => setLocalState(() => isActive = v),
                      title: const Text('Active'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedDate == null || startTime == null || endTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please choose a date and time range.')),
                      );
                      return;
                    }
                    if (_minutes(endTime!) <= _minutes(startTime!)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('End time must be later than start time.')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, {
                      'slot_date': _formatIsoDate(selectedDate!),
                      'start_time': _formatIsoTime(startTime!),
                      'end_time': _formatIsoTime(endTime!),
                      'note': noteCtrl.text.trim(),
                      'is_active': isActive,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.customerPrimary,
                    foregroundColor: AppTheme.white,
                  ),
                  child: Text(existing == null ? 'Save' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;
    setState(() => _saving = true);
    try {
      if (existing == null) {
        await ApiService.createProviderTimeSlot(
          slotDate: result['slot_date'] as String,
          startTime: result['start_time'] as String,
          endTime: result['end_time'] as String,
          note: result['note'] as String?,
          isActive: result['is_active'] == true,
        );
      } else {
        final slotId = existing['id'];
        final parsedId = slotId is int ? slotId : int.parse(slotId.toString());
        await ApiService.updateProviderTimeSlot(
          slotId: parsedId,
          slotDate: result['slot_date'] as String,
          startTime: result['start_time'] as String,
          endTime: result['end_time'] as String,
          note: result['note'] as String?,
          isActive: result['is_active'] == true,
        );
      }
      await _loadSlots();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null ? 'Time slot added.' : 'Time slot updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteSlot(Map<String, dynamic> slot) async {
    final slotId = slot['id'];
    final parsedId = slotId is int ? slotId : int.tryParse(slotId.toString());
    if (parsedId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Time Slot'),
        content: const Text('This slot will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: AppTheme.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.deleteProviderTimeSlot(parsedId);
      await _loadSlots();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time slot deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text(
          'Time Slots',
          style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadSlots,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _showEditor(),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Slot'),
      ),
      body: _loading
          ? const AppPageShimmer()
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 56, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _loadSlots,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.customerPrimary,
                  onRefresh: _loadSlots,
                  child: _slots.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: [
                            const SizedBox(height: 72),
                            Icon(Icons.schedule_outlined, size: 72, color: Colors.grey[400]),
                            const SizedBox(height: 18),
                            const Text(
                              'No time slots yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add your available working hours so customers can book around them.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                          itemCount: _slots.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final slot = Map<String, dynamic>.from(_slots[index] as Map);
                            final active = (slot['is_active'] ?? true) == true;
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: AppTheme.customerPrimary.withOpacity(0.12),
                                          child: Icon(
                                            Icons.schedule,
                                            color: active ? AppTheme.customerPrimary : Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${_formatDateLabel(slot['slot_date'])} · ${(slot['day_name'] ?? '').toString()}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${_formatTimeLabel(slot['start_time'])} - ${_formatTimeLabel(slot['end_time'])}',
                                                style: TextStyle(color: Colors.grey[700]),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: active ? Colors.green.withOpacity(0.12) : Colors.grey.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            active ? 'Active' : 'Inactive',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: active ? Colors.green[700] : Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if ((slot['note'] ?? '').toString().trim().isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        slot['note'].toString().trim(),
                                        style: TextStyle(color: Colors.grey[800]),
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: _saving ? null : () => _showEditor(existing: slot),
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          label: const Text('Edit'),
                                        ),
                                        const SizedBox(width: 10),
                                        TextButton.icon(
                                          onPressed: _saving ? null : () => _deleteSlot(slot),
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          label: const Text('Delete', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }

  Widget _pickerField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.customerPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  TimeOfDay? _timeFromText(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateLabel(dynamic value) {
    final text = value?.toString() ?? '';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    return _formatDate(parsed);
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimeLabel(dynamic value) {
    final time = _timeFromText(value?.toString() ?? '');
    return time == null ? (value?.toString() ?? '—') : _formatTime(time);
  }

  String _formatIsoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatIsoTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;
}
