import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop 全局快捷键服务。
/// 注册系统级快捷键用于快速显示/隐藏窗口。
class DesktopHotkeyService {
  DesktopHotkeyService();

  final List<HotKey> _registered = [];

  /// 注册全局快捷键。
  Future<void> registerGlobalHotkeys() async {
    // Cmd/Ctrl + Shift + O: 显示/隐藏窗口
    final toggleHotKey = HotKey(
      key: PhysicalKeyboardKey.keyO,
      modifiers: [HotKeyModifier.shift, HotKeyModifier.meta],
      scope: HotKeyScope.system,
    );

    await hotKeyManager.register(
      toggleHotKey,
      keyDownHandler: (_) async {
        if (await windowManager.isVisible()) {
          await windowManager.hide();
        } else {
          await windowManager.show();
          await windowManager.focus();
        }
      },
    );
    _registered.add(toggleHotKey);
  }

  /// 注销所有快捷键。
  Future<void> dispose() async {
    for (final hotKey in _registered) {
      await hotKeyManager.unregister(hotKey);
    }
    _registered.clear();
  }
}
