part of 'music_controller.dart';

/// 管理外部音乐平台账号状态和登录命令。
extension MusicPlatformAccountCommands on MusicCenterController {
  Future<Map<String, PlatformUserInfo?>> _safePlatformInfo() async {
    final neteaseInfo = await _safe(() => _api.platformInfo('netease'), null);
    final qqInfo = await _safe(() => _api.platformInfo('qq'), null);
    return {'netease': neteaseInfo, 'qq': qqInfo};
  }

  /// 加载网易云和 QQ 音乐的登录状态。
  Future<void> loadPlatformInfo() async {
    final current = _currentState;
    if (current == null) {
      return;
    }
    final platformInfo = await _safePlatformInfo();
    final latest = _currentState;
    if (latest == null) {
      return;
    }
    _replaceState(
      latest.copyWith(
        neteaseUserInfo: platformInfo['netease'],
        qqUserInfo: platformInfo['qq'],
      ),
    );
  }

  /// 创建网易云 QR 登录会话。
  Future<QrLoginSession> neteaseQrLogin() => _api.createNeteaseQrLogin();

  /// 轮询网易云 QR 登录状态。
  Future<QrLoginStatus> checkNeteaseQrLogin(String key) =>
      _api.checkNeteaseQrLogin(key);

  /// 注入 QQ 音乐登录 Cookie。
  Future<void> applyQqCookie(String cookie) async {
    final userInfo = await _api.applyQqCookie(cookie);
    final current = _currentState;
    if (current == null) {
      return;
    }
    _replaceState(current.copyWith(qqUserInfo: userInfo));
  }

  /// 断开指定外部平台账号。
  Future<void> platformLogout(String platform) async {
    await _api.platformLogout(platform);
    final current = _currentState;
    if (current == null) {
      return;
    }
    if (platform == 'netease') {
      _replaceState(current.copyWith(clearNeteaseUserInfo: true));
    } else if (platform == 'qq') {
      _replaceState(current.copyWith(clearQqUserInfo: true));
    }
  }
}
