import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:omninest/core/utils/platform_helper.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// 桌面窗口默认尺寸：三端统一，与原生 runner 兜底值保持一致。
const Size kDefaultWindowSize = Size(1280, 800);

/// 桌面窗口最小尺寸：低于该尺寸的管理列表与表单不可用。
const Size kMinimumWindowSize = Size(1024, 640);

/// 首启默认尺寸相对工作区的占比；小于全屏留出呼吸空间。
const double _defaultWorkAreaRatio = 0.85;

const String _geometryPrefsKey = 'window.geometry.v1';

/// 已持久化的窗口边界快照。
@immutable
class WindowBoundsSnapshot {
  const WindowBoundsSnapshot({required this.bounds, this.maximized = false});

  final Rect bounds;
  final bool maximized;

  /// 解码失败或字段非法时返回 null，不视为错误。
  static WindowBoundsSnapshot? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      final bounds = Rect.fromLTWH(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
        (json['w'] as num).toDouble(),
        (json['h'] as num).toDouble(),
      );
      if (bounds.width <= 0 || bounds.height <= 0) {
        return null;
      }
      return WindowBoundsSnapshot(
        bounds: bounds,
        maximized: json['max'] == true,
      );
    } on Object {
      return null;
    }
  }

  String encode() => jsonEncode(<String, dynamic>{
    'x': bounds.left,
    'y': bounds.top,
    'w': bounds.width,
    'h': bounds.height,
    'max': maximized,
  });
}

/// 启动窗口几何决策结果。
@immutable
class WindowStartupPlan {
  const WindowStartupPlan({
    required this.size,
    this.position,
    this.maximize = false,
  });

  final Size size;

  /// 期望左上角位置；null 表示交给系统摆放。
  final Offset? position;
  final bool maximize;
}

/// 纯计算：根据记忆边界与可见区域推导启动几何。
///
/// - 有记忆：沿用记忆尺寸（不低于最小尺寸），位置仍在任一可见区域内
///   则沿用，否则回主屏居中；记忆为最大化时直接最大化。
/// - 无记忆：默认尺寸按主工作区 [_defaultWorkAreaRatio] 收窄后居中；
///   收窄后仍低于最小尺寸说明屏幕过小，直接最大化。
WindowStartupPlan computeStartupGeometry({
  Size defaultSize = kDefaultWindowSize,
  Size minimumSize = kMinimumWindowSize,
  WindowBoundsSnapshot? saved,
  List<Rect> visibleAreas = const <Rect>[],
}) {
  if (saved != null) {
    final width = math.max(minimumSize.width, saved.bounds.width);
    final height = math.max(minimumSize.height, saved.bounds.height);
    final size = Size(width, height);
    final anchored = visibleAreas.any(
      (area) => area.contains(saved.bounds.topLeft),
    );
    final position =
        anchored
            ? saved.bounds.topLeft
            : visibleAreas.isNotEmpty
            ? _centerIn(visibleAreas.first, size)
            : null;
    return WindowStartupPlan(
      size: size,
      position: position,
      maximize: saved.maximized,
    );
  }
  if (visibleAreas.isEmpty) {
    return WindowStartupPlan(size: defaultSize);
  }
  final workArea = visibleAreas.first;
  final width = math.min(
    defaultSize.width,
    workArea.width * _defaultWorkAreaRatio,
  );
  final height = math.min(
    defaultSize.height,
    workArea.height * _defaultWorkAreaRatio,
  );
  final size = Size(width, height);
  if (size.width < minimumSize.width || size.height < minimumSize.height) {
    return WindowStartupPlan(size: minimumSize, maximize: true);
  }
  return WindowStartupPlan(size: size, position: _centerIn(workArea, size));
}

Offset _centerIn(Rect area, Size size) => Offset(
  area.left + math.max(0, (area.width - size.width) / 2),
  area.top + math.max(0, (area.height - size.height) / 2),
);

/// 桌面窗口几何服务：启动时按记忆与工作区摆放窗口，并在移动、缩放、
/// 最大化状态变化与关闭时持久化最新边界。
class WindowGeometryService with WindowListener {
  static const _persistDebounce = Duration(milliseconds: 700);

  Timer? _debounce;
  Rect? _lastNormalBounds;

  /// 应用启动几何；插件或屏幕信息不可用时静默降级为原生默认。
  Future<void> applyStartupGeometry() async {
    if (!isDesktopPlatform) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = WindowBoundsSnapshot.tryDecode(
        prefs.getString(_geometryPrefsKey),
      );
      final visibleAreas = await _loadVisibleAreas();
      final plan = computeStartupGeometry(
        saved: saved,
        visibleAreas: visibleAreas,
      );
      final planPosition = plan.position;
      _lastNormalBounds = Rect.fromLTWH(
        0,
        0,
        plan.size.width,
        plan.size.height,
      );
      if (planPosition != null) {
        _lastNormalBounds = _lastNormalBounds!.shift(planPosition);
      }
      await windowManager.waitUntilReadyToShow(
        WindowOptions(size: plan.size, minimumSize: kMinimumWindowSize),
        () async {
          windowManager.addListener(this);
          if (planPosition != null) {
            await windowManager.setBounds(null, position: planPosition);
          }
          if (plan.maximize) {
            await windowManager.maximize();
          }
        },
      );
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Window geometry startup failed: $error');
      }
      try {
        await windowManager.show();
      } on Object catch (showError) {
        if (kDebugMode) {
          debugPrint('Window show fallback failed: $showError');
        }
      }
    }
  }

  /// 收集全部显示器的工作区；屏幕信息不可用时返回空列表。
  Future<List<Rect>> _loadVisibleAreas() async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      final areas = <Rect>[];
      for (final display in displays) {
        final visibleSize = display.visibleSize;
        if (visibleSize == null || visibleSize.isEmpty) {
          continue;
        }
        final visiblePosition = display.visiblePosition ?? Offset.zero;
        areas.add(visiblePosition & visibleSize);
      }
      if (areas.isEmpty) {
        final primary = await screenRetriever.getPrimaryDisplay();
        final visibleSize = primary.visibleSize;
        if (visibleSize != null && !visibleSize.isEmpty) {
          areas.add((primary.visiblePosition ?? Offset.zero) & visibleSize);
        }
      }
      return areas;
    } on Object {
      return const <Rect>[];
    }
  }

  void _schedulePersist() {
    _debounce?.cancel();
    _debounce = Timer(_persistDebounce, () {
      unawaited(_persistNow());
    });
  }

  Future<void> _persistNow() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (await windowManager.isFullScreen()) {
        return;
      }
      final bounds = await windowManager.getBounds();
      if (!maximized) {
        _lastNormalBounds = bounds;
      }
      final effective = maximized ? (_lastNormalBounds ?? bounds) : bounds;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _geometryPrefsKey,
        WindowBoundsSnapshot(bounds: effective, maximized: maximized).encode(),
      );
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Window geometry persist failed: $error');
      }
    }
  }

  @override
  void onWindowResize() {
    _schedulePersist();
  }

  @override
  void onWindowMove() {
    _schedulePersist();
  }

  @override
  void onWindowMaximize() {
    unawaited(_persistNow());
  }

  @override
  void onWindowUnmaximize() {
    _schedulePersist();
  }

  @override
  void onWindowLeaveFullScreen() {
    _schedulePersist();
  }

  @override
  void onWindowClose() {
    _debounce?.cancel();
    unawaited(_persistNow());
  }

  void dispose() {
    _debounce?.cancel();
    windowManager.removeListener(this);
  }
}

/// 顶层单例：bootstrap 阶段 ProviderScope 尚未挂载，直接持有实例。
final WindowGeometryService windowGeometryService = WindowGeometryService();
