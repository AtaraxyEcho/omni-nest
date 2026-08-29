import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/mobile_shell/mobile_app_shell.dart';

void main() {
  group('shouldUseResponsiveMobileShell', () {
    test('Windows 和 Web 紧凑视口启用移动端壳层', () {
      expect(
        shouldUseResponsiveMobileShell(mobilePlatform: false, width: 360),
        isTrue,
      );
      expect(
        shouldUseResponsiveMobileShell(mobilePlatform: false, width: 899),
        isTrue,
      );
    });

    test('Windows 和 Web 桌面视口保留桌面布局', () {
      expect(
        shouldUseResponsiveMobileShell(mobilePlatform: false, width: 900),
        isFalse,
      );
      expect(
        shouldUseResponsiveMobileShell(mobilePlatform: false, width: 3840),
        isFalse,
      );
    });

    test('Android 和 iOS 在平板宽度继续使用移动端信息架构', () {
      expect(
        shouldUseResponsiveMobileShell(mobilePlatform: true, width: 1280),
        isTrue,
      );
    });
  });
}
