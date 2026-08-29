import 'package:web/web.dart' as web;

/// Web 端视频播放适配，检测浏览器编解码能力。
class WebVideoAdapter {
  const WebVideoAdapter();

  /// 检测浏览器是否支持指定 MIME 类型（如 'video/mp4; codecs="avc1.42E01E"'）。
  static bool canPlayType(String mimeType) {
    final video = web.HTMLVideoElement();
    return video.canPlayType(mimeType).isNotEmpty;
  }

  /// 从可用格式中选择最优格式。优先 WebM (VP9) > MP4 (H.264)。
  static String getPreferredFormat(List<String> availableFormats) {
    for (final format in ['webm', 'mp4']) {
      if (availableFormats.contains(format)) return format;
    }
    return availableFormats.first;
  }

  /// 进入视频元素全屏。
  static Future<void> enterFullscreen(web.Element element) async {
    element.requestFullscreen();
  }

  /// 退出全屏。
  static Future<void> exitFullscreen() async {
    web.document.exitFullscreen();
  }
}
