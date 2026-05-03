import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'native_structs.dart';

typedef _CaptureNative = CaptureResultNative Function(Pointer<Utf8>);
typedef _CaptureDart = CaptureResultNative Function(Pointer<Utf8>);

typedef _FreeStringNative = Void Function(Pointer<Utf8>);
typedef _FreeStringDart = void Function(Pointer<Utf8>);

class NativeBindings {
  late final DynamicLibrary _lib;

  late final _CaptureDart capture;
  late final _FreeStringDart freeString;

  NativeBindings() {
    _lib = Platform.isWindows
        ? DynamicLibrary.open("verena_capture.dll")
        : throw UnsupportedError("Only Windows supported");

    capture = _lib
        .lookup<NativeFunction<_CaptureNative>>("capture_active_window_ffi")
        .asFunction();

    freeString = _lib
        .lookup<NativeFunction<_FreeStringNative>>("free_string")
        .asFunction();
  }
}
