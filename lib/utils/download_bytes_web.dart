// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Web: trigger a browser download via an anchor with a blob URL.
/// Returns true (web downloads always succeed barring browser restrictions).
bool downloadBytesImpl(
    Uint8List bytes, String filename, {String mime = 'application/octet-stream'}) {
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  // Defer revocation so the browser has time to start the download.
  Future.delayed(const Duration(milliseconds: 100), () {
    html.Url.revokeObjectUrl(url);
  });
  return true;
}