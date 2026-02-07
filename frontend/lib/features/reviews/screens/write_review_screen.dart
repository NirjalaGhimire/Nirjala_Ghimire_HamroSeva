import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';

/// Write a review: Score (stars), Title, Review text, + add media, Option tags, *Username, *Email. Cancel / Post.
class WriteReviewScreen extends StatefulWidget {
  const WriteReviewScreen({super.key});

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  int _stars = 0;
  final _titleController = TextEditingController();
  final _reviewController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final List<String> _optionTags = ['light', 'Fair', 'Medium', 'Dark', 'Dry', 'Oily', 'Combination'];
  String? _selectedOption;

  @override
  void dispose() {
    _titleController.dispose();
    _reviewController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightLavender,
      appBar: AppBar(
        title: const Text('Write a review', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.white)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review posted (frontend only)')));
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.darkGrey, borderRadius: BorderRadius.circular(8)),
              child: const Text('Post', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Score:', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.darkGrey)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                return IconButton(
                  onPressed: () => setState(() => _stars = i + 1),
                  icon: Icon(i < _stars ? Icons.star : Icons.star_border, color: Colors.amber, size: 36),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                filled: true,
                fillColor: AppTheme.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Review:', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.darkGrey)),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              maxLines: 4,
              decoration: const InputDecoration(
                filled: true,
                fillColor: AppTheme.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                contentPadding: EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Add photo/video'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: AppTheme.darkGrey),
                foregroundColor: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Option 1:', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.darkGrey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _optionTags.map((tag) {
                final selected = _selectedOption == tag;
                return FilterChip(
                  label: Text(tag),
                  selected: selected,
                  onSelected: (v) => setState(() => _selectedOption = v ? tag : null),
                  selectedColor: AppTheme.darkGrey.withOpacity(0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '*Username:',
                filled: true,
                fillColor: AppTheme.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '*Email:',
                filled: true,
                fillColor: AppTheme.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
