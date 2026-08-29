import 'package:flutter/foundation.dart';

/// 当前是否运行在 Web 平台。
bool get isWebPlatform => kIsWeb;

/// 当前是否运行在移动平台（Android / iOS）。
bool get isMobilePlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// 当前是否运行在桌面平台（Windows / Linux / macOS）。
bool get isDesktopPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// 当前是否运行在 Android 平台。
bool get isAndroidPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// 当前是否运行在 iOS 平台。
bool get isIOSPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// 是否支持翻页模式（左右滑动）。
///
/// 懒加载分页（PageNavigator）按需计算单页，窗口大小变化时重新分页即可。
bool get supportsPageMode => !kIsWeb;
