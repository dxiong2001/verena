import 'dart:convert';
import 'dart:io';

class RustBridge {
  Process? _process;

  Future<void> init() async {
    try {
      _process = await Process.start(
        '../rust_engine/target/debug/rust_engine',
        [],
      );

      _process!.stdout.transform(utf8.decoder).listen((data) {
        print("Rust: $data");
      });

      _process!.stderr.transform(utf8.decoder).listen((data) {
        print("Rust Error: $data");
      });
    } catch (e) {
      print("Failed to start Rust engine: $e");
    }
  }

  void startCaptureSession(int interval, String directoryPath) {
    if (interval < 0) {
      return;
    }
    _send({
      "command": "start_session",
      'interval': interval.toString(),
      "directory_path": directoryPath,
    });
  }

  void stopCaptureSession() {
    _send({"command": "stop_session"});
  }

  void _send(Map<String, dynamic> msg) {
    _process?.stdin.writeln(jsonEncode(msg));
  }
}
