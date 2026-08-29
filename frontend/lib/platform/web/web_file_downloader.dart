import 'package:web/web.dart' as web;

/// Web 端文件下载，通过创建隐藏的 <a download> 元素触发浏览器原生下载。
class WebFileDownloader {
  const WebFileDownloader();

  /// 触发浏览器下载。[url] 为预签名下载地址，[fileName] 为保存的文件名。
  static Future<void> download({
    required String url,
    required String fileName,
  }) async {
    final anchor =
        web.HTMLAnchorElement()
          ..href = url
          ..download = fileName
          ..style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }
}
