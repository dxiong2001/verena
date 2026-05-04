import '../models/capture_result.dart';
import 'dart:isolate';
import 'dart:async';
import './capture_worker.dart';

class CaptureService {
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();

  final Map<int, Completer<CaptureResult>> _pending = {};
  int _nextId = 0;
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;

    final initPort = ReceivePort();

    await Isolate.spawn(captureWorker, initPort.sendPort);

    final sendPort = await initPort.first as SendPort;
    initPort.close(); // 🔥 IMPORTANT FIX
    _sendPort = sendPort;

    _receivePort.listen((message) {
      final int id = message[0];
      final CaptureResult result = message[1];

      final completer = _pending.remove(id);
      completer?.complete(result);
    });

    _initialized = true;
  }

  Future<CaptureResult> captureAsync(String path) async {
    await _init();

    if (_sendPort == null) {
      throw Exception("Capture isolate not initialized");
    }

    final id = _nextId++;
    final completer = Completer<CaptureResult>();

    _pending[id] = completer;

    _sendPort!.send([id, path, _receivePort.sendPort]);

    return completer.future;
  }
}
