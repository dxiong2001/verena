import '../ffi/bindings.dart';
import '../ffi/native_api.dart';
import '../models/capture_result.dart';

class CaptureService {
  late final NativeApi _api;

  CaptureService() {
    final bindings = NativeBindings();
    _api = NativeApi(bindings);
  }

  CaptureResult capture(String path) {
    return _api.captureActiveWindow(path);
  }
}
