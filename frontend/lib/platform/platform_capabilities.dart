import 'package:flutter/foundation.dart';

/// 平台能力查询，用于运行时判断当前平台支持哪些功能。
class PlatformCapabilities {
  const PlatformCapabilities({
    required this.supportsBackgroundSync,
    required this.supportsSystemTray,
    required this.supportsDirectoryImport,
    required this.supportsSecureStorage,
    required this.supportsNotifications,
  });

  /// 根据当前运行平台返回对应的能力集。
  factory PlatformCapabilities.current() {
    if (kIsWeb) return PlatformCapabilities.web();
    // dart:io 平台通过 defaultTargetPlatform 判断
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return PlatformCapabilities.android();
      case TargetPlatform.iOS:
        return PlatformCapabilities.ios();
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return PlatformCapabilities.desktop();
      default:
        return PlatformCapabilities.fallback();
    }
  }

  final bool supportsBackgroundSync;
  final bool supportsSystemTray;
  final bool supportsDirectoryImport;
  final bool supportsSecureStorage;
  final bool supportsNotifications;

  factory PlatformCapabilities.web() => const PlatformCapabilities(
    supportsBackgroundSync: false,
    supportsSystemTray: false,
    supportsDirectoryImport: false,
    supportsSecureStorage: false,
    supportsNotifications: false,
  );

  factory PlatformCapabilities.android() => const PlatformCapabilities(
    supportsBackgroundSync: true,
    supportsSystemTray: false,
    supportsDirectoryImport: true,
    supportsSecureStorage: true,
    supportsNotifications: true,
  );

  factory PlatformCapabilities.ios() => const PlatformCapabilities(
    supportsBackgroundSync: true,
    supportsSystemTray: false,
    supportsDirectoryImport: false,
    supportsSecureStorage: true,
    supportsNotifications: true,
  );

  factory PlatformCapabilities.desktop() => const PlatformCapabilities(
    supportsBackgroundSync: false,
    supportsSystemTray: true,
    supportsDirectoryImport: true,
    supportsSecureStorage: true,
    supportsNotifications: true,
  );

  factory PlatformCapabilities.fallback() => const PlatformCapabilities(
    supportsBackgroundSync: false,
    supportsSystemTray: false,
    supportsDirectoryImport: false,
    supportsSecureStorage: false,
    supportsNotifications: false,
  );
}
