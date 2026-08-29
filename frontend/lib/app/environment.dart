import 'package:omninest/app/platform_origin_stub.dart'
    if (dart.library.js_interop) 'package:omninest/app/platform_origin_web.dart'
    as platform;

class AppEnvironment {
  const AppEnvironment({
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    this.webBaseUrl,
  });

  factory AppEnvironment.fromDefines() {
    const apiBaseUrl = String.fromEnvironment(
      'OMNINEST_API_BASE_URL',
      defaultValue: 'http://localhost:8080/api/v1',
    );
    const wsBaseUrl = String.fromEnvironment(
      'OMNINEST_WS_BASE_URL',
      defaultValue: 'ws://localhost:8080/ws',
    );
    const webBaseUrl = String.fromEnvironment(
      'OMNINEST_WEB_BASE_URL',
      defaultValue: '',
    );
    return AppEnvironment(
      apiBaseUrl: apiBaseUrl,
      wsBaseUrl: wsBaseUrl,
      webBaseUrl: webBaseUrl.isNotEmpty ? webBaseUrl : null,
    );
  }

  final String apiBaseUrl;
  final String wsBaseUrl;

  /// 分享链接基地址。
  /// 未配置时使用浏览器当前 origin（Web 平台）或 apiBaseUrl（其他平台）。
  final String? webBaseUrl;

  String get effectiveWebBaseUrl {
    if (webBaseUrl != null) return webBaseUrl!;
    return platform.getBrowserOrigin() ?? apiBaseUrl;
  }
}
