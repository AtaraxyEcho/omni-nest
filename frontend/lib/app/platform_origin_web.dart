import 'package:web/web.dart' as web;

/// 获取浏览器当前页面的 origin（scheme + host + port）。
String? getBrowserOrigin() => web.window.location.origin;
