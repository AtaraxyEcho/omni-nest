import 'package:flutter/material.dart';

/// Music 沉浸播放器使用的视觉配色。
class MusicImmersivePalette {
  const MusicImmersivePalette({
    required this.background,
    required this.surface,
    required this.surfaceStrong,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accentAlt,
    required this.glow,
  });

  static const digital = MusicImmersivePalette(
    background: Color(0xFF071016),
    surface: Color(0xA6121D25),
    surfaceStrong: Color(0xD9142029),
    text: Color(0xFFF4F7F5),
    muted: Color(0xB8DDE8E7),
    accent: Color(0xFF9FDBE3),
    accentAlt: Color(0xFFD5C27A),
    glow: Color(0x663D8EA0),
  );

  final Color background;
  final Color surface;
  final Color surfaceStrong;
  final Color text;
  final Color muted;
  final Color accent;
  final Color accentAlt;
  final Color glow;
}

/// Music 沉浸播放器的减少动态效果适配。
class MusicImmersiveMotion {
  const MusicImmersiveMotion._();

  /// 根据系统辅助功能设置解析动画时长。
  static Duration duration(BuildContext context, Duration value) {
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return disabled ? Duration.zero : value;
  }
}
