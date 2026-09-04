import 'package:flutter/material.dart';

/// Frame 风格暖纸色调色板（依据 Figma "Photos Library Model UI"）。
class FramePalette {
  static const bg = Color(0xFFFAFAF8);
  static const ink = Color(0xFF1A1917);
  static const sub = Color(0xFF5A5754);
  static const muted = Color(0xFF8A8680);
  static const faint = Color(0xFF44445A);
  static const accent = Color(0xFFC07840);
  static const border = Color(0xFFE5E2DC);
  static const card = Color(0xFFEAE7E0);
  static const hover = Color(0xFFF0EDE6);
  static const hoverSoft = Color(0xFFF4F2EE);
  static const navBg = Color(0xFFFAFAF8);
  static const activeBg = Color(0xFFEDE9E1);
  static const chipActiveBg = Color(0xFFFDF4EC);
  static const dark = Color(0xFF1A1917);
  static const viewerBg = Color(0xFF0D0D0C);
  static const white = Colors.white;

  /// 设计稿标题字体 Instrument Serif；中文标题回退到内置 NotoSerifSC。
  static const serifFamily = 'InstrumentSerif';
  static const serifFallback = <String>['NotoSerifSC'];
}
