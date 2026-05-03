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

      final pathStr = native.path.toDartString();
      final titleStr = native.windowTitle.toDartString();
      final frameHash = array32ToList(native.frameHash);
      final prevHash = array32ToList(native.prevHash);
      // ⚠️ free Rust memory
      if (native.path != nullptr) {
        _bindings.freeString(native.path);
      }
      if (native.windowTitle != nullptr) {
        _bindings.freeString(native.windowTitle);
      }

      return CaptureResult(
        status: native.status,
        path: pathStr,
        windowTitle: titleStr,
        frameHash: frameHash,
        prevHash: prevHash,
      );
    } finally {
      malloc.free(ptr);
    }
  }
}
