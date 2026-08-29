import 'package:flutter/material.dart';
import 'package:omninest/app/theme/global_theme_colors.dart';

/// 移动端工作台使用的尺寸与动效令牌。
abstract final class MobileLayoutTokens {
  static const double horizontalPadding = 16;
  static const double tabletHorizontalPadding = 24;
  static const double sectionGap = 24;
  static const double itemGap = 12;
  static const double radius = 8;
  static const double minimumTarget = 48;
  static const double listRowHeight = 64;

  static const Duration pressDuration = Duration(milliseconds: 120);
  static const Duration stateDuration = Duration(milliseconds: 190);
  static const Duration pageDuration = Duration(milliseconds: 240);
  static const Curve motionCurve = Curves.easeOutCubic;

  static EdgeInsets pagePadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal:
          MediaQuery.sizeOf(context).width >= 600
              ? tabletHorizontalPadding
              : horizontalPadding,
    );
  }
}

@immutable
class MobileSemanticColors {
  const MobileSemanticColors({
    required this.pageMask,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSelected,
    required this.textPrimary,
    required this.textSecondary,
    required this.outline,
    required this.musicAccent,
    required this.warmAccent,
    required this.danger,
    required this.success,
  });

  final Color pageMask;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSelected;
  final Color textPrimary;
  final Color textSecondary;
  final Color outline;
  final Color musicAccent;
  final Color warmAccent;
  final Color danger;
  final Color success;
}

extension MobileThemeContext on BuildContext {
  MobileSemanticColors get mobileColors {
    final scheme = Theme.of(this).colorScheme;
    final semantic = Theme.of(this).extension<GlobalThemeColors>();
    return MobileSemanticColors(
      pageMask: scheme.surface,
      surface: scheme.surfaceContainerLow,
      surfaceRaised: scheme.surfaceContainer,
      surfaceSelected: scheme.primaryContainer,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      outline: scheme.outlineVariant,
      musicAccent: scheme.primary,
      warmAccent: scheme.tertiary,
      danger: scheme.error,
      success: semantic?.success ?? scheme.primary,
    );
  }
}
