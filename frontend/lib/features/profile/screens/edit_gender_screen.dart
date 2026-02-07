import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';

/// Edit Gender: Male, Female, Other radio. Save -> success dialog "Gender updated successfully", OK.
class EditGenderScreen extends StatefulWidget {
  const EditGenderScreen({super.key, this.initialGender = 'female'});

  final String initialGender;

  @override
  State<EditGenderScreen> createState() => _EditGenderScreenState();
}

class _EditGenderScreenState extends State<EditGenderScreen> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialGender;
  }

  void _save() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: Color(0xFFE3F2FD),
              child: Icon(Icons.person_outline, color: Colors.blue, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Gender updated successfully',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.darkGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.darkGrey, foregroundColor: AppTheme.white),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Edit Gender', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioListTile<String>(
              title: const Text('Male', style: TextStyle(color: AppTheme.darkGrey)),
              value: 'male',
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
              activeColor: AppTheme.darkGrey,
            ),
            RadioListTile<String>(
              title: const Text('Female', style: TextStyle(color: AppTheme.darkGrey)),
              value: 'female',
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
              activeColor: AppTheme.darkGrey,
            ),
            RadioListTile<String>(
              title: const Text('Other', style: TextStyle(color: AppTheme.darkGrey)),
              value: 'other',
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
              activeColor: AppTheme.darkGrey,
            ),
          ],
        ),
      ),
    );
  }
}
