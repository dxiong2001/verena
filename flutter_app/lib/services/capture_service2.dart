import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';

typedef RegisterPort = Void Function(Int64);
typedef StartCapture = Void Function();
typedef StopCapture = Void Function();
typedef SetDirNative = Void Function(Pointer<Utf8>);

class CaptureService {
  late final DynamicLibrary _lib;

  late final void Function(int) _registerPort;
  late final void Function() _start;
  late final void Function() _stop;
  late final void Function(Pointer<Utf8>) _setDir;

  final ReceivePort _receivePort = ReceivePort();

  CaptureService() {
    _lib = DynamicLibrary.open("verena_capture.dll");

    _registerPort = _lib.lookupFunction<RegisterPort, void Function(int)>(
      "register_send_port",
    );

    _start = _lib.lookupFunction<StartCapture, void Function()>(
      "start_capture",
    );

    _stop = _lib.lookupFunction<StopCapture, void Function()>("stop_capture");

    _setDir = _lib.lookupFunction<SetDirNative, void Function(Pointer<Utf8>)>(
      "set_save_directory",
    );
  }

  bool _initialized = false;

  void init(void Function(String, int, int) onFrame) {
    if (_initialized) return;
    _initialized = true;

    _receivePort.listen((msg) {
      final data = msg as List;

      final int id = data[0];
      final int timestamp = data[1];
      final String path = data[2];

      onFrame(path, timestamp, id);
    });

    _registerPort(_receivePort.sendPort.nativePort);
  }

  void setDirectory(String dir) {
    final ptr = dir.toNativeUtf8();
    _setDir(ptr);
    malloc.free(ptr);
  }

  void start() => _start();
  void stop() => _stop();

  void dispose() {
    _receivePort.close();
  }
}
