import 'dart:ffi';

final class CaptureResultNative extends Struct {
  @Int32()
  external int status;
}
