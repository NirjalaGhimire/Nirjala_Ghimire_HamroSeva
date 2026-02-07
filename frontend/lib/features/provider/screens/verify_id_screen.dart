import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/provider/widgets/provider_app_bar.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';

/// Document type key (backend) -> display label.
const Map<String, String> _docTypeLabels = {
  'work_licence': 'Work Licence',
  'passport': 'Passport',
  'citizenship_card': 'Citizenship Card',
  'national_id': 'National Identification Card',
};

const List<String> _docTypeKeys = [
  'work_licence',
  'passport',
  'citizenship_card',
  'national_id',
];

/// Verify Your Id: document types (Work Licence, Passport, Citizenship Card, National ID) connected to backend.
class VerifyIdScreen extends StatefulWidget {
  const VerifyIdScreen({super.key});

  @override
  State<VerifyIdScreen> createState() => _VerifyIdScreenState();
}

class _VerifyIdScreenState extends State<VerifyIdScreen> {
  int _selectedDocIndex = 0;
  List<Map<String, dynamic>> _verifications = [];
  bool _loading = true;
  String? _error;
  bool _submitting = false;

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
      final list = await ApiService.getProviderVerifications();
      if (mounted) {
        setState(() {
        _verifications = (list as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _verifications = [];
        _loading = false;
      });
      }
    }
  }

  Future<void> _addDocument() async {
    final docType = _docTypeKeys[_selectedDocIndex];
    final label = _docTypeLabels[docType] ?? docType;
    final result = await showDialog<_AddDocResult>(
      context: context,
      builder: (ctx) => _AddDocumentDialog(
        label: label,
        docType: docType,
      ),
    );
    if (result == null) return;
    setState(() => _submitting = true);
    try {
      if (result.file != null) {
        final f = result.file!;
        final path = f.path;
        if (path != null && path.isNotEmpty) {
          await ApiService.createProviderVerificationWithFile(
            documentType: docType,
            filePath: path,
            documentNumber: result.documentNumber?.isEmpty == true ? null : result.documentNumber,
            fileName: f.name,
          );
        } else if (f.bytes != null) {
          await ApiService.createProviderVerificationWithFileBytes(
            documentType: docType,
            bytes: f.bytes!,
            fileName: f.name,
            documentNumber: result.documentNumber?.isEmpty == true ? null : result.documentNumber,
          );
        } else {
          throw Exception('File data not available');
        }
      } else {
        await ApiService.createProviderVerification(
          documentType: docType,
          documentNumber: result.documentNumber?.isEmpty == true ? null : result.documentNumber,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label submitted for verification')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteDocument(Map<String, dynamic> doc) async {
    final id = doc['id'];
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove document?'),
        content: const Text(
          'This document will be removed from your verification list. You can add it again later.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: TextStyle(color: Colors.red[700])),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.deleteProviderVerification(id is int ? id : int.parse(id.toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document removed')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Verify Your Id', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        elevation: 0,
        shape: providerAppBarShape,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Document',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _docTypeKeys.length,
                itemBuilder: (context, index) {
                  final selected = _selectedDocIndex == index;
                  final label = _docTypeLabels[_docTypeKeys[index]] ?? _docTypeKeys[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedDocIndex = index),
                      selectedColor: AppTheme.customerPrimary.withOpacity(0.2),
                      side: BorderSide(color: selected ? AppTheme.customerPrimary : Colors.grey[300]!),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_loading || _submitting) ? null : _addDocument,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add),
                label: Text(_submitting ? 'Submitting...' : 'Add this document'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.customerPrimary,
                  foregroundColor: AppTheme.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 13)),
            ],
            const SizedBox(height: 24),
            Text(
              'Your documents',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[800]),
            ),
            const SizedBox(height: 12),
            _loading
                ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppTheme.customerPrimary)))
                : _verifications.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No documents added yet. Select a type above and tap "Add this document".',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _verifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final doc = _verifications[index];
                          final type = (doc['document_type'] ?? '').toString();
                          final label = _docTypeLabels[type] ?? type;
                          final status = (doc['status'] ?? 'pending').toString().toLowerCase();
                          final verified = status == 'verified';
                          final color = verified ? Colors.green : AppTheme.customerPrimary;
                          return _docCard(
                            label: label,
                            verified: verified,
                            color: color,
                            onEdit: verified ? null : () {},
                            onDelete: verified ? null : () => _deleteDocument(doc),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }

  Widget _docCard({
    required String label,
    required bool verified,
    required Color color,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.4), color.withOpacity(0.2)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color.withOpacity(0.9)),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (verified)
                  Icon(Icons.verified, color: color, size: 32)
                else ...[
                  if (onEdit != null)
                    IconButton(
                      icon: Icon(Icons.edit, color: color),
                      onPressed: onEdit,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: onDelete,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddDocResult {
  final String? documentNumber;
  final PlatformFile? file;
  _AddDocResult({this.documentNumber, this.file});
}

class _AddDocumentDialog extends StatefulWidget {
  final String label;
  final String docType;

  const _AddDocumentDialog({required this.label, required this.docType});

  @override
  State<_AddDocumentDialog> createState() => _AddDocumentDialogState();
}

class _AddDocumentDialogState extends State<_AddDocumentDialog> {
  final _numberController = TextEditingController();
  PlatformFile? _pickedFile;
  bool _picking = false;

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'gif', 'webp'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() {
          _pickedFile = result.files.first;
          _picking = false;
        });
      } else if (mounted) {
        setState(() => _picking = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _picking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add ${widget.label}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _numberController,
              decoration: const InputDecoration(
                labelText: 'Document number (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),
            const Text(
              'Upload document (image or PDF)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _picking ? null : _pickFile,
              icon: _picking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.folder_open),
              label: Text(
                _pickedFile != null
                    ? _pickedFile!.name
                    : 'Choose file from device',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: AppTheme.customerPrimary),
                foregroundColor: AppTheme.customerPrimary,
              ),
            ),
            if (_pickedFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Selected: ${_pickedFile!.name}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            _AddDocResult(
              documentNumber: _numberController.text.trim(),
              file: _pickedFile,
            ),
          ),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.customerPrimary),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
