import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';

/// Details screen: "Add Details" multi-line text field, Save button.
class AddDetailsScreen extends StatefulWidget {
  const AddDetailsScreen({super.key, this.initialDetails = ''});

  final String initialDetails;

  @override
  State<AddDetailsScreen> createState() => _AddDetailsScreenState();
}

class _AddDetailsScreenState extends State<AddDetailsScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialDetails);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightLavender,
      appBar: AppBar(
        title: const Text('Details', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: const Text('Save', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Details',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Lorem ipsum dolor sit amet consectetur. Dui dignissim massa magna urna augue cursus tempor vitae. Nulla mus urna.',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: AppTheme.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
