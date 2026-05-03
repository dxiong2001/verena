import 'dart:typed_data';

class CaptureResult {
  final int status;
  final String path;
  final String windowTitle;
  final Uint8List frameHash;
  final Uint8List prevHash;

  CaptureResult({
    required this.status,
    required this.path,
    required this.windowTitle,
    required this.frameHash,
    required this.prevHash,
  });
}
