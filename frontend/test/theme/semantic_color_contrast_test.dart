import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/app/theme/app_theme_palette.dart';
import 'package:omninest/app/theme/feature/files_colors.dart';
import 'package:omninest/app/theme/feature/reader_colors.dart';
import 'package:omninest/app/theme/global_theme_colors.dart';

void main() {
  group('全局语义颜色对比度', () {
    for (final (name, colors) in <(String, GlobalThemeColors)>[
      ('浅色', AppThemePalette.light),
      ('深色', AppThemePalette.dark),
    ]) {
      test('$name主题的选中态和错误角标满足正文对比度', () {
        expect(
          _contrast(colors.onPrimaryContainer, colors.primaryContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(colors.onError, colors.error),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('$name主题的状态标签在淡色背景上保持可读', () {
        for (final semantic in <Color>[
          colors.success,
          colors.warning,
          colors.info,
          colors.error,
        ]) {
          final background = Color.alphaBlend(
            semantic.withValues(alpha: 0.12),
            colors.surface,
          );
          expect(_contrast(semantic, background), greaterThanOrEqualTo(3.0));
        }
      });
    }
  });

  group('Reader 语义颜色对比度', () {
    for (final (name, theme) in <(String, ThemeData)>[
      ('浅色', OmniNestTheme.light()),
      ('深色', OmniNestTheme.dark()),
    ]) {
      test('$name主题的侧边栏选中态保持清晰', () {
        final colors = theme.extension<ReaderColors>()!;
        final selectedBackground = Color.alphaBlend(
          colors.sidebarSelectedBg,
          colors.surfaceContainerLow,
        );

        expect(
          _contrast(colors.sidebarSelectedFg, selectedBackground),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(colors.sidebarSelectedBorder, colors.surfaceContainerLow),
          greaterThanOrEqualTo(3.0),
        );
        expect(
          _contrast(colors.primary, colors.surfaceContainerHigh),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });

  group('FileManager 侧边栏选中态对比度', () {
    for (final (name, palette) in <(String, GlobalThemeColors)>[
      ('浅色', AppThemePalette.light),
      ('深色', AppThemePalette.dark),
    ]) {
      test('$name主题下选中项文字保持清晰', () {
        final colors = FilesColors.fromGlobal(palette);
        final selectedBackground = Color.alphaBlend(
          colors.sidebarSelectedBg,
          colors.surfaceContainerLow,
        );

        expect(
          _contrast(colors.sidebarSelectedFg, selectedBackground),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });
}

double _contrast(Color foreground, Color background) {
  final lighter = math.max(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  final darker = math.min(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  return (lighter + 0.05) / (darker + 0.05);
}
