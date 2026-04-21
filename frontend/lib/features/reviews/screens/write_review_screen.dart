import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
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
  final List<String> _optionTags = [
    'light',
    'Fair',
    'Medium',
    'Dark',
    'Dry',
    'Oily',
    'Combination'
  ];
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
        title: Text(AppStrings.t(context, 'writeReview'),
            style: const TextStyle(
                color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.t(context, 'cancel'),
              style: const TextStyle(color: AppTheme.white)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(AppStrings.t(context, 'reviewPosted'))));
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: AppTheme.darkGrey,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(AppStrings.t(context, 'post'),
                  style: const TextStyle(
                      color: AppTheme.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.t(context, 'score'),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.darkGrey)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                return IconButton(
                  onPressed: () => setState(() => _stars = i + 1),
                  icon: Icon(i < _stars ? Icons.star : Icons.star_border,
                      color: Colors.amber, size: 36),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: AppStrings.t(context, 'title'),
                filled: true,
                fillColor: AppTheme.white,
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 16),
            Text(AppStrings.t(context, 'review'),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.darkGrey)),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              maxLines: 4,
              decoration: const InputDecoration(
                filled: true,
                fillColor: AppTheme.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12))),
                contentPadding: EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: Text(AppStrings.t(context, 'addPhotoVideo')),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: AppTheme.darkGrey),
                foregroundColor: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 20),
            Text('${AppStrings.t(context, 'option')} 1:',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.darkGrey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _optionTags.map((tag) {
                final selected = _selectedOption == tag;
                return FilterChip(
                  label: Text(tag),
                  selected: selected,
                  onSelected: (v) =>
                      setState(() => _selectedOption = v ? tag : null),
                  selectedColor: AppTheme.darkGrey.withOpacity(0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: '*${AppStrings.t(context, 'username')}:',
                filled: true,
                fillColor: AppTheme.white,
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: '*${AppStrings.t(context, 'email')}:',
                filled: true,
                fillColor: AppTheme.white,
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
