import 'dart:typed_data';

import 'download_bytes_io.dart' if (dart.library.html) 'download_bytes_web.dart';

/// Saves [bytes] as [filename]. On web this triggers a browser download; on
/// desktop/mobile it writes to the local temp directory. Returns true on success.
bool downloadBytes(Uint8List bytes, String filename, {String mime = 'application/octet-stream'}) {
  return downloadBytesImpl(bytes, filename, mime: mime);
}