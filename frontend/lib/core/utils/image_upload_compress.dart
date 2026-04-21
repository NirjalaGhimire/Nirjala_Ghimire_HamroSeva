import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Same Supabase Storage bucket as chat (`chat-attachments`); keep uploads under limit.
const int kStorageUploadImageMaxBytes = 900 * 1024;

String _forceJpegFileName(String fileName) {
  final lastDot = fileName.lastIndexOf('.');
  if (lastDot == -1) return '$fileName.jpg';
  final base = fileName.substring(0, lastDot);
  return '$base.jpg';
}

/// Resize and JPEG-encode so payload fits [maxBytes] (default ~900KB).
({Uint8List bytes, String fileName}) compressImageBytesToJpegUnderLimit(
  Uint8List bytes, {
  int maxBytes = kStorageUploadImageMaxBytes,
  String fileName = 'image.jpg',
}) {
  if (bytes.length <= maxBytes) {
    return (bytes: bytes, fileName: fileName);
  }

  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception(
      'Could not read this image. Try another photo or format (JPG/PNG).',
    );
  }

  img.Image working = decoded;
  const int maxSide = 1600;
  if (working.width > maxSide || working.height > maxSide) {
    if (working.width >= working.height) {
      working = img.copyResize(working, width: maxSide);
    } else {
      working = img.copyResize(working, height: maxSide);
    }
  }

  const candidates = <int>[88, 80, 72, 65, 55, 45, 38, 32, 28, 24];
  List<int> best = img.encodeJpg(working, quality: candidates.last);
  for (final q in candidates) {
    final encoded = img.encodeJpg(working, quality: q);
    if (encoded.isEmpty) continue;
    if (encoded.length <= maxBytes) {
      return (
        bytes: Uint8List.fromList(encoded),
        fileName: _forceJpegFileName(fileName),
      );
    }
    best = encoded;
  }

  if (best.length > maxBytes) {
    throw Exception(
      'Photo is still too large after compression. Try a simpler image or lower resolution.',
    );
  }
  return (
    bytes: Uint8List.fromList(best),
    fileName: _forceJpegFileName(fileName),
  );
}
