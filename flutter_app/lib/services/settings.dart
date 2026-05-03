import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _intervalKey = 'snapshot_interval';
  static const _captureKey = 'last_capture';

  Future<String> getCaptureInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_intervalKey) ?? "30 seconds";
  }

  Future<void> setCaptureInterval(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_intervalKey, value);
  }

  Future<int?> getLastCaptureId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_captureKey);
  }

  Future<void> setLastCaptureId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_captureKey, id);
  }
}
