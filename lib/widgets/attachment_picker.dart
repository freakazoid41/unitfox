import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Optional image/PDF upload for income and expense entries. Returns the file
/// bytes + name so it can be stored offline alongside the transaction.
class AttachmentPicker extends StatefulWidget {
  final Uint8List? bytes;
  final String name;
  final void Function(String name, Uint8List bytes) onPicked;
  final VoidCallback onClear;

  const AttachmentPicker({
    super.key,
    required this.bytes,
    required this.name,
    required this.onPicked,
    required this.onClear,
  });

  @override
  State<AttachmentPicker> createState() => _AttachmentPickerState();
}

class _AttachmentPickerState extends State<AttachmentPicker> {
  bool _isImage(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.gif') ||
        n.endsWith('.webp');
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
      // FileType.custom never hits file_picker's image compress path, but be
      // explicit so a future type change can't reintroduce full-res decodes.
      allowCompression: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    // Reject files larger than 10 MB to avoid OOM and DB bloat.
    if (file.size > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File too large (max 10 MB)')));
      }
      return;
    }
    final name = file.name.isNotEmpty ? file.name : 'attachment';
    widget.onPicked(name, file.bytes!);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = widget.bytes;
    if (bytes == null) {
      return OutlinedButton.icon(
        onPressed: _pick,
        icon: const Icon(Icons.attach_file),
        label: const Text('Attach image / PDF (optional)'),
      );
    }
    final preview = _isImage(widget.name)
        ? Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(bytes, fit: BoxFit.cover, cacheWidth: 600),
              ),
            ),
          )
        : Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                SizedBox(width: 6),
                Text('PDF'),
              ],
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        preview,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Replace',
              onPressed: _pick,
              icon: const Icon(Icons.swap_horiz),
            ),
            IconButton(
              tooltip: 'Remove',
              onPressed: widget.onClear,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ],
    );
  }
}