import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Customer screen to request a new service to be added to the platform.
class NewServiceRequestScreen extends StatefulWidget {
  const NewServiceRequestScreen({super.key});

  @override
  State<NewServiceRequestScreen> createState() =>
      _NewServiceRequestScreenState();
}

class _NewServiceRequestScreenState extends State<NewServiceRequestScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final name = _nameController.text.trim();

    // Validate
    if (name.isEmpty) {
      setState(
          () => _errorMessage = AppStrings.t(context, 'serviceNameRequired'));
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.submitServiceCategoryRequest(
        serviceTitle: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        address: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
      );

      if (!mounted) return;

      // Show success dialog
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(AppStrings.t(context, 'requestSubmitted')),
          content: Text(AppStrings.t(context, 'requestSubmittedMessage')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // Clear form and go back
                _nameController.clear();
                _descriptionController.clear();
                _locationController.clear();
                Navigator.of(context).pop();
              },
              child: Text(AppStrings.t(context, 'ok')),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage =
            '${AppStrings.t(context, 'failedSubmitRequest')}: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.t(context, 'requestService'),
          style: const TextStyle(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header text
            Text(
              AppStrings.t(context, 'cantFindService'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),

            // Service name field
            Text(
              AppStrings.t(context, 'serviceName'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: AppStrings.t(context, 'enterServiceName'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 20),

            // Description field
            Text(
              AppStrings.t(context, 'description'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: AppStrings.t(context, 'enterDescription'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: 4,
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 20),

            // Location field
            Text(
              AppStrings.t(context, 'serviceLocation'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: AppStrings.t(context, 'enterLocationDetails'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: 2,
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 14,
                  ),
                ),
              ),
            if (_errorMessage != null) const SizedBox(height: 20),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.customerPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: Colors.grey[400],
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: AppShimmerLoader(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        AppStrings.t(context, 'submitRequest'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Pay with eSewa button
            TextButton(
              onPressed: () {
                // Logic for real eSewa payment
              },
              child: Text(
                AppStrings.t(context, 'payWithEsewa'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Browse categories link
            Center(
              child: TextButton.icon(
                onPressed:
                    _isSubmitting ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.category),
                label: Text(AppStrings.t(context, 'browseCategories')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
