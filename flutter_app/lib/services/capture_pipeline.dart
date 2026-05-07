import 'dart:async';
import 'dart:collection';
import 'capture_service2.dart';

class Frame {
  final String path;
  final int timestamp;
  final int id;

  Frame({required this.path, required this.timestamp, required this.id});
}

class CapturePipeline {
  final CaptureService _service = CaptureService();

  final Queue<Frame> _queue = Queue();

  bool _processing = false;
  bool _running = false;

  // Optional: UI throttle
  int _lastUiUpdate = 0;

  void start(String path) {
    if (_running) return;
    _running = true;
    _service.setDirectory(path);
    _service.init(_onFrame);
    _service.start();
  }

  void stop() {
    _running = false;
    _service.stop(); // stop Rust side
    _service.dispose(); // close Dart side port
  }

  // 🔥 RECEIVES FROM RUST (DO NOT DO WORK HERE)
  void _onFrame(String path, int timestamp, int id) {
    if (!_running) return;

    _queue.add(Frame(path: path, timestamp: timestamp, id: id));

    _drainQueue();
  }

  // 🔥 BACKGROUND PROCESSOR (THIS FIXES LAG)
  Future<void> _drainQueue() async {
    if (_processing) return;
    _processing = true;

    while (_queue.isNotEmpty) {
      final frame = _queue.removeFirst();

      // ---- STORAGE / PROCESSING ----
      await _storeFrame(frame);

      // ---- UI THROTTLE (IMPORTANT) ----
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastUiUpdate > 200) {
        _lastUiUpdate = now;
        _notifyUi(frame);
      }

      // tiny yield to avoid blocking event loop
      await Future.delayed(Duration(milliseconds: 1));
    }

    _processing = false;
  }

  // 🔥 YOU CAN EXPAND THIS LATER (DB, filtering, etc.)
  Future<void> _storeFrame(Frame frame) async {
    // Right now do nothing (file already saved by Rust)
    // Later:
    // - insert into SQLite
    // - filter frames
    // - group sessions
  }

  // 🔥 UI UPDATE (KEEP LIGHT)
  void _notifyUi(Frame frame) {
    // example:
    print("Frame ${frame.id}: ${frame.path}");
  }
}
