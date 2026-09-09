import 'dart:io';
import 'dart:typed_data';

/// VM / desktop / mobile fallback: write the bytes to the temp directory.
/// Returns true on success, false on failure (best-effort outside web).
bool downloadBytesImpl(
    Uint8List bytes, String filename, {String mime = 'application/octet-stream'}) {
  try {
    final safe = filename.replaceAll(RegExp(r'[\\/]'), '_');
    final path = '${Directory.systemTemp.path}/$safe';
    File(path).writeAsBytesSync(bytes);
    return true;
  } catch (_) {
    return false;
  }
}