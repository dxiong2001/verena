import 'package:ffi/ffi.dart';
import 'dart:ffi';
import '../models/capture_result.dart';
import 'bindings.dart';
import 'dart:typed_data';

class NativeApi {
  final NativeBindings _bindings;

  NativeApi(this._bindings);

  Uint8List array32ToList(Array<Uint8> arr) {
    final out = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      out[i] = arr[i];
    }
    return out;
  }

  CaptureResult captureActiveWindow(String path) {
    final ptr = path.toNativeUtf8();
    try {
      final native = _bindings.capture(ptr);
      print(native.status);
      final titleStr = "placeholder";
      print("testttttt");
      return CaptureResult(
        status: native.status,
        path: path,
        windowTitle: titleStr,
      );
    } catch (e) {
      print("native api error: $e");

      return CaptureResult(status: 2, path: path, windowTitle: "");
    } finally {
      malloc.free(ptr);
    }
  }
}
