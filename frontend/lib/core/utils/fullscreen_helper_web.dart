import 'package:web/web.dart' as web;

class FullscreenHelperWeb {
  /// 进入全屏
  static void enterFullscreen(web.Element element) {
    element.requestFullscreen();
  }

  /// 退出全屏
  static void exitFullscreen() {
    web.document.exitFullscreen();
  }

  /// 切换全屏（如果当前全屏则退出，否则进入）
  static void toggleFullscreen(web.Element element) {
    if (isFullscreenEnabled) {
      exitFullscreen();
    } else {
      enterFullscreen(element);
    }
  }

  /// 当前是否处于全屏模式
  static bool get isFullscreenEnabled => web.document.fullscreenElement != null;

  /// 获取根元素（用于全屏）
  static web.Element get documentElement => web.document.documentElement!;
}
