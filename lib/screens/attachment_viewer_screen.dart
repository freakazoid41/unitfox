import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../utils/download_bytes.dart';

class AttachmentViewerScreen extends StatelessWidget {
  final Uint8List bytes;
  final String name;

  const AttachmentViewerScreen({
    super.key,
    required this.bytes,
    required this.name,
  });

  bool _isImage() {
    if (bytes.length < 4) return _byExt();
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
    // GIF: 47 49 46
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    // BMP: 42 4D
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return true;
    // WebP: RIFF....WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return true;
    }
    return _byExt();
  }

  bool _byExt() {
    final n = name.toLowerCase();
    return n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.gif') ||
        n.endsWith('.webp') ||
        n.endsWith('.bmp') ||
        n.endsWith('.heic') ||
        n.endsWith('.heif');
  }

  bool _isPdf() => name.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    final isImage = _isImage();
    return Scaffold(
      appBar: AppBar(title: Text(name.isEmpty ? 'Attachment' : name)),
      body: isImage
          ? Center(child: InteractiveViewer(child: Image.memory(bytes)))
          : _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    final isPdf = _isPdf();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPdf ? Icons.picture_as_pdf : Icons.attach_file,
              size: 80,
              color: isPdf ? Colors.redAccent : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(name, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => downloadBytes(
                bytes,
                name,
                mime: isPdf ? 'application/pdf' : 'application/octet-stream',
              ),
              icon: const Icon(Icons.download),
              label: Text(isPdf ? 'Download PDF' : 'Download'),
            ),
          ],
        ),
      ),
    );
  }
}
