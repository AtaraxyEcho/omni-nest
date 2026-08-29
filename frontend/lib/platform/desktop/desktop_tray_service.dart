import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop 系统托盘服务。
/// 提供托盘图标、右键菜单和窗口显示/隐藏控制。
class DesktopTrayService with TrayListener {
  DesktopTrayService();

  bool _initialized = false;

  /// 初始化系统托盘。
  Future<void> init() async {
    if (_initialized) return;
    trayManager.addListener(this);

    await trayManager.setIcon('assets/icons/tray_icon.png', isTemplate: true);

    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: '显示窗口'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: '退出'),
        ],
      ),
    );

    _initialized = true;
  }

  /// 移除托盘图标。
  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
    _initialized = false;
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        windowManager.show();
        windowManager.focus();
      case 'quit':
        windowManager.destroy();
      default:
        break;
    }
  }
}
