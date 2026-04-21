import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/widgets/app_shimmer_loader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';
import 'package:hamro_sewa_frontend/core/l10n/app_strings.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';

class ChatThreadScreen extends StatefulWidget {
  final int bookingId;
  final String title;

  const ChatThreadScreen({
    super.key,
    required this.bookingId,
    required this.title,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  static const int _maxChatAttachmentBytes =
      900 * 1024; // keep under 1MB bucket limit

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isSending = false;
  List<Map<String, dynamic>> _messages = [];
  Timer? _pollTimer;
  int? _currentUserId;
  final Set<String> _currentIdentityKeys = <String>{};
  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, Uint8List> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _initCurrentUser();
    _startPolling();
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _normalizeIdentity(dynamic value) {
    final s = value?.toString() ?? '';
    return s.trim().toLowerCase();
  }

  void _rememberIdentityFromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return;

    final username = _normalizeIdentity(
        map['username'] ?? map['user_name'] ?? map['name'] ?? map['full_name']);
    if (username.isNotEmpty) {
      _currentIdentityKeys.add(username);
    }

    final email = _normalizeIdentity(map['email']);
    if (email.isNotEmpty) {
      _currentIdentityKeys.add(email);
      final at = email.indexOf('@');
      if (at > 0) {
        _currentIdentityKeys.add(email.substring(0, at));
      }
    }
  }

  Map<String, dynamic> _normalizeChatMessage(dynamic raw) {
    final out = Map<String, dynamic>.from(raw as Map);

    final id = _asInt(out['id']);
    if (id != null) {
      out['id'] = id;
    }

    final senderId =
        _asInt(out['sender_id'] ?? out['senderId'] ?? out['sender']);
    if (senderId != null) {
      out['sender_id'] = senderId;
      out['senderId'] = senderId;
    }

    return out;
  }

  Future<int?> _currentUserIdFromAccessToken() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      return _asInt(map['user_id'] ?? map['id'] ?? map['sub']);
    } catch (_) {
      return null;
    }
  }

  bool _isOwnMessage(Map<String, dynamic> msg) {
    if (msg['_local_is_me'] == true) {
      return true;
    }

    final senderId =
        _asInt(msg['sender_id'] ?? msg['senderId'] ?? msg['sender']);
    final me = _currentUserId;
    if (senderId != null && me != null && senderId == me) {
      return true;
    }

    final senderName = _normalizeIdentity(msg['sender_name']);
    if (senderName.isNotEmpty && _currentIdentityKeys.contains(senderName)) {
      return true;
    }

    return false;
  }

  Future<void> _initCurrentUser() async {
    int? resolvedId;

    final user = await TokenStorage.getSavedUser();
    _rememberIdentityFromMap(user);

    // Prefer auth token identity; saved profile can contain provider/customer profile IDs.
    resolvedId = await _currentUserIdFromAccessToken();

    if (user != null) {
      resolvedId ??= _asInt(user['id'] ?? user['user_id'] ?? user['userId']);
    }

    if (resolvedId == null) {
      try {
        final profile = await ApiService.getUserProfile();
        _rememberIdentityFromMap(profile);
        resolvedId =
            _asInt(profile['id'] ?? profile['user_id'] ?? profile['userId']);
        if (profile.isNotEmpty) {
          final merged = <String, dynamic>{
            if (user != null) ...user,
            ...profile,
          };
          await TokenStorage.saveUser(merged);
        }
      } catch (_) {
        // Keep null; alignment will default to left until user id is known.
      }
    }

    if (!mounted) return;
    setState(() {
      _currentUserId = resolvedId;
    });

    if (_messages.isNotEmpty) {
      // Trigger rebuild after user id resolves to correct left/right alignment.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _isSending) return;
      _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final fetched =
          await ApiService.getChatMessages(bookingId: widget.bookingId);
      final messages = fetched
          .map<Map<String, dynamic>>((m) => _normalizeChatMessage(m))
          .toList();
      if (!mounted) return;

      if (_messages.isEmpty) {
        setState(() => _messages = messages);
        if (!silent && messages.isNotEmpty) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
        }
        return;
      }

      // Only append new messages, so existing image widgets (and signed URLs)
      // don't get replaced on every poll.
      final existingIds = _messages.map((m) => m['id']).toSet();
      final newOnes = messages.where((m) {
        final id = m['id'];
        return id != null && !existingIds.contains(id);
      }).toList();

      if (newOnes.isEmpty) return;

      setState(() => _messages = [..._messages, ...newOnes]);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${AppStrings.t(context, 'failedLoadMessages')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _sendChatPayload(String payload) async {
    final text = payload.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final message = _normalizeChatMessage(await ApiService.sendChatMessage(
        bookingId: widget.bookingId,
        message: text,
      ));
      message['_local_is_me'] = true;
      setState(() {
        _messages.add(message);
        if (_controller.text.isNotEmpty) _controller.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${AppStrings.t(context, 'failedSendMessage')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await _sendChatPayload(text);
  }

  Future<void> _sendAttachment({
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
  }) async {
    setState(() => _isSending = true);
    try {
      final sent = _normalizeChatMessage(await ApiService.sendChatAttachment(
        bookingId: widget.bookingId,
        fileBytes: fileBytes.toList(),
        fileName: fileName,
        mimeType: mimeType,
        message: '',
      ));
      sent['_local_is_me'] = true;
      setState(() {
        _messages.add(sent);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${AppStrings.t(context, 'failedSendMessage')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _callBookingContact() async {
    try {
      final user = await TokenStorage.getSavedUser();
      final role = (user?['role'] ?? '').toString().toLowerCase();
      if (role.isEmpty) return;

      final booking =
          await ApiService.getBookingById(widget.bookingId.toString());
      final phone = role == 'provider'
          ? (booking['customer_phone'] ?? booking['customerPhone'] ?? '')
              .toString()
          : (booking['provider_phone'] ?? booking['providerPhone'] ?? '')
              .toString();

      final cleaned = phone.replaceAll(RegExp(r'\\s+'), '');
      if (cleaned.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number not available for call')),
        );
        return;
      }

      final tel = cleaned.startsWith('+') ? cleaned : '+977$cleaned';
      await launchUrl(
        Uri.parse('tel:$tel'),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Call failed: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  Future<void> _openAttachmentSheet() async {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Photo / Gallery'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickAndSendPhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file_outlined),
                title: const Text('File'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickAndSendFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndSendPhoto() async {
    final xfile = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;

    final bytes = await xfile.readAsBytes();
    final compressed = await _compressImageToJpegUnderLimit(
      bytes: bytes,
      fileName: xfile.name,
    );
    if (compressed.bytes.length > _maxChatAttachmentBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo is too large. Please choose a smaller photo.'),
        ),
      );
      return;
    }
    await _sendAttachment(
      fileBytes: compressed.bytes,
      fileName: compressed.fileName,
      mimeType: compressed.mimeType,
    );
  }

  Future<void> _pickAndSendFile() async {
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'gif'],
    );
    if (picked == null || picked.files.isEmpty) return;

    final f = picked.files.single;
    final bytes = f.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read selected file.')),
      );
      return;
    }

    const maxBytes = _maxChatAttachmentBytes;
    if (bytes.length > maxBytes && !(f.extension?.toLowerCase() == 'pdf')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compressing image to fit…')),
      );
      // We'll try compressing image; for non-image we still block below.
    }

    final ext = (f.extension ?? '').toLowerCase();
    final mime = _mimeFromFileExtension(ext);
    final fileName = f.name;

    final isAllowedImage = mime.startsWith('image/');
    final isAllowedPdf = mime == 'application/pdf';
    if (!isAllowedImage && !isAllowedPdf) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Only images and PDF are supported in chat.')),
      );
      return;
    }

    if (isAllowedImage) {
      final compressed = await _compressImageToJpegUnderLimit(
        bytes: bytes,
        fileName: fileName,
      );
      if (compressed.bytes.length > maxBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Image is too large. Please choose a smaller image.')),
        );
        return;
      }
      await _sendAttachment(
        fileBytes: compressed.bytes,
        fileName: compressed.fileName,
        mimeType: compressed.mimeType,
      );
      return;
    }

    if (isAllowedPdf && bytes.length > maxBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('PDF is too large. Pick a smaller PDF (<= 1MB).')),
      );
      return;
    }

    await _sendAttachment(
      fileBytes: bytes,
      fileName: fileName,
      mimeType: mime,
    );
  }

  Future<({Uint8List bytes, String mimeType, String fileName})>
      _compressImageToJpegUnderLimit({
    required Uint8List bytes,
    required String fileName,
  }) async {
    // Decode image; if it fails, just send original bytes (backend will reject if unsupported).
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return (
        bytes: bytes,
        mimeType: 'image/jpeg',
        fileName: _forceJpegExtension(fileName)
      );
    }

    // Resize if needed to reduce payload.
    img.Image working = decoded;
    const int maxWidth = 1280;
    if (working.width > maxWidth) {
      working = img.copyResize(working, width: maxWidth);
    }

    const candidates = [90, 80, 70, 60, 50, 40, 35, 30, 25];
    final List<int> best = img.encodeJpg(working, quality: candidates.last);
    for (final q in candidates) {
      final encoded = img.encodeJpg(working, quality: q);
      if (encoded.isEmpty) continue;
      if (encoded.length <= _maxChatAttachmentBytes) {
        return (
          bytes: Uint8List.fromList(encoded),
          mimeType: 'image/jpeg',
          fileName: _forceJpegExtension(fileName),
        );
      }
      // Keep the last encoded data; we will return it if it still doesn't fit.
    }

    // If we couldn't fit into the limit even at lowest quality, return best we got.
    return (
      bytes: Uint8List.fromList(best),
      mimeType: 'image/jpeg',
      fileName: _forceJpegExtension(fileName),
    );
  }

  String _forceJpegExtension(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1) return '$fileName.jpg';
    final base = fileName.substring(0, lastDot);
    return '$base.jpg';
  }

  String _mimeFromImageExtension(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  String _mimeFromFileExtension(String ext) {
    // Minimal mapping for chat rendering needs.
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  String _formatMessageTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.tryParse(raw);
      if (dt == null) return raw;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(dt.year, dt.month, dt.day);
      final diff = today.difference(msgDay).inDays;
      final timeStr =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (diff == 0) return timeStr;
      if (diff == 1) return 'Yesterday $timeStr';
      if (diff < 7) return '$diff d ago $timeStr';
      return '${dt.day}/${dt.month} $timeStr';
    } catch (_) {
      return raw;
    }
  }

  Widget _buildMessageContent(String rawMessage, {required bool isMe}) {
    if (rawMessage.startsWith('data:image/') &&
        rawMessage.contains(';base64,')) {
      try {
        const marker = ';base64,';
        final markerIdx = rawMessage.indexOf(marker);
        final base64 = rawMessage.substring(markerIdx + marker.length);
        final cacheKey = rawMessage.hashCode.toString();

        Uint8List? bytes = _imageCache[cacheKey];
        bytes ??= base64Decode(base64);
        if (!_imageCache.containsKey(cacheKey)) _imageCache[cacheKey] = bytes;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Text(rawMessage, maxLines: 2),
          ),
        );
      } catch (_) {
        // If decode fails, show the raw text.
        return Text(rawMessage, maxLines: 2, overflow: TextOverflow.ellipsis);
      }
    }

    if (rawMessage.startsWith('ATTACHMENT:')) {
      final rest = rawMessage.substring('ATTACHMENT:'.length);
      final parts = rest.split(':');
      final fileName = parts.isNotEmpty ? parts[0] : 'Attachment';
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.attachment_outlined,
            size: 18,
            color: isMe ? Colors.white : Colors.black87,
          ),
          const SizedBox(height: 6),
          Text(
            fileName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isMe ? Colors.white : Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return Text(
      rawMessage,
      style: const TextStyle(fontSize: 15),
      maxLines: 10,
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isMe = _isOwnMessage(msg);
    final senderName = isMe ? 'You' : ((msg['sender_name'] as String?) ?? '');
    final rawMessage = (msg['message'] as String?) ?? '';
    final attachmentUrl = (msg['attachment_url'] as String?) ?? '';
    final attachmentMime = (msg['attachment_mime'] as String?) ?? '';
    final attachmentName = (msg['attachment_name'] as String?) ?? '';
    final time = _formatMessageTime(msg['created_at'] as String?);
    final hasAttachment = attachmentUrl.isNotEmpty;
    final messageId = msg['id'] as int?;
    final isDeleted = rawMessage == 'This message was deleted';

    final messageBubble = Padding(
      padding: EdgeInsets.fromLTRB(
        isMe ? 56 : 12,
        4,
        isMe ? 12 : 56,
        4,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe && senderName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    senderName,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: isDeleted
                      ? (isMe
                          ? AppTheme.customerPrimary.withValues(alpha: 0.15)
                          : Colors.grey[200])
                      : (isMe
                          ? AppTheme.customerPrimary
                          : AppTheme.customerPrimary.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: hasAttachment
                    ? Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (rawMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                rawMessage,
                                textAlign:
                                    isMe ? TextAlign.right : TextAlign.left,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          if (attachmentMime.startsWith('image/'))
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                attachmentUrl,
                                width: 220,
                                height: 220,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 220,
                                  height: 220,
                                  color: Colors.black12,
                                  alignment: Alignment.center,
                                  child:
                                      const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: isMe
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.attachment_outlined,
                                  size: 18,
                                  color: isMe ? Colors.white : Colors.black87,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    attachmentName.isNotEmpty
                                        ? attachmentName
                                        : 'Attachment',
                                    textAlign:
                                        isMe ? TextAlign.right : TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          isMe ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      )
                    : (rawMessage.startsWith('data:image/') ||
                            rawMessage.startsWith('ATTACHMENT:'))
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: _buildMessageContent(
                              rawMessage,
                              isMe: isMe,
                            ),
                          )
                        : Text(
                            rawMessage,
                            textAlign: isMe ? TextAlign.right : TextAlign.left,
                            style: TextStyle(
                              color: isDeleted
                                  ? Colors.grey[600]
                                  : (isMe ? Colors.white : Colors.black87),
                              fontSize: 15,
                              fontStyle: isDeleted
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                textAlign: isMe ? TextAlign.right : TextAlign.left,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );

    // Wrap with GestureDetector to allow long-press for deletion if it's user's own message
    if (isMe && messageId != null && !isDeleted) {
      return GestureDetector(
        onLongPress: () => _showDeleteMessageDialog(messageId),
        child: messageBubble,
      );
    }

    return messageBubble;
  }

  Future<void> _showDeleteMessageDialog(int messageId) async {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.t(context, 'deleteMessage')),
        content: Text(AppStrings.t(context, 'deleteMessageConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppStrings.t(context, 'cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteMessage(messageId);
            },
            child: Text(
              AppStrings.t(context, 'deleteMessage'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(int messageId) async {
    try {
      await ApiService.deleteChatMessage(
        bookingId: widget.bookingId,
        messageId: messageId,
      );

      // Remove the deleted message from the list and reload to show "This message was deleted"
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == messageId);
        });
        // Reload messages to get the updated version with deleted marker
        await _loadMessages(silent: true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.t(context, 'failedDeleteMessage')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppTheme.customerPrimary,
        actions: [
          IconButton(
            tooltip: 'Call',
            icon: const Icon(Icons.phone_in_talk_outlined),
            onPressed: _callBookingContact,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const AppPageShimmer()
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            AppStrings.t(context, 'noMessagesYet'),
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 12, bottom: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return _buildMessageBubble(msg);
                        },
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: AppStrings.t(context, 'typeAMessage'),
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Attach',
                    onPressed: _openAttachmentSheet,
                    icon: const Icon(Icons.attach_file_outlined),
                    color: AppTheme.customerPrimary,
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.customerPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onPressed: _isSending ? null : _sendMessage,
                    child: _isSending
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: AppShimmerLoader(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send, color: Colors.white),
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
