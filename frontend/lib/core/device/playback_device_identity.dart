import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 提供跨启动稳定的播放进度设备标识。
class PlaybackDeviceIdentity {
  PlaybackDeviceIdentity._();

  static const String _storageKey = 'playback_device_id';
  static Future<String>? _pending;

  /// 读取或创建当前安装的设备标识。
  static Future<String> getOrCreate() {
    return _pending ??= _loadOrCreate();
  }

  static Future<String> _loadOrCreate() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_storageKey)?.trim();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    final created = const Uuid().v4();
    await preferences.setString(_storageKey, created);
    return created;
  }
}
