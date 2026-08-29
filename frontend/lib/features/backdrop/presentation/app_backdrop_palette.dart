import 'package:flutter/material.dart';

/// 应用背景设置面板使用的颜色。
class AppBackdropPalette {
  const AppBackdropPalette({
    required this.text,
    required this.muted,
    required this.accent,
    required this.accentAlt,
  });

  final Color text;
  final Color muted;
  final Color accent;
  final Color accentAlt;
}
