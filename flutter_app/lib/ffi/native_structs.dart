import 'dart:ffi';
import 'package:ffi/ffi.dart';

final class CaptureResultNative extends Struct {
  @Int32()
  external int status;
  external Pointer<Utf8> path;
  external Pointer<Utf8> windowTitle;
  @Array(32)
  external Array<Uint8> frameHash;

  @Array(32)
  external Array<Uint8> prevHash;
}
