import 'dart:isolate';
import '../ffi/bindings.dart';
import '../ffi/native_api.dart';

void captureWorker(SendPort mainSendPort) {
  final port = ReceivePort();

  mainSendPort.send(port.sendPort);

  final bindings = NativeBindings();
  final api = NativeApi(bindings);

  port.listen((message) {
    try {
      final int id = message[0];
      final String path = message[1];
      final SendPort replyPort = message[2];
      final result = api.captureActiveWindow(path);
      replyPort.send([id, result]); // MUST match service expectation
    } catch (e, st) {
      print("Worker crash: $e");
      print(st);
    }
  });
}
