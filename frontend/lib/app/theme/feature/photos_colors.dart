import 'package:flutter/material.dart';
import 'package:omninest/app/theme/global_theme_colors.dart';

@immutable
class PhotosColors extends ThemeExtension<PhotosColors> {
  const PhotosColors({
    required this.surface,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.outlineVariant,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.tertiary,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.success,
    required this.danger,
    required this.timelineDivider,
    required this.albumCardShadow,
    required this.overlay,
    required this.overlayLight,
    required this.badgeBg,
    required this.badgeText,
    required this.mediaOverlayText,
    required this.slideshowBg,
    required this.slideshowText,
    required this.slideshowMuted,
    required this.galaxyCanvas,
    required this.galaxyCanvasRaised,
    required this.galaxyOnCanvas,
    required this.galaxyMuted,
    required this.galaxyLine,
    required this.galaxyGlow,
    required this.galaxyPlaceholder,
  });

  final Color surface;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color outlineVariant;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color tertiary;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color success;
  final Color danger;
  final Color timelineDivider;
  final Color albumCardShadow;
  final Color overlay;
  final Color overlayLight;
  final Color badgeBg;
  final Color badgeText;
  final Color mediaOverlayText;
  final Color slideshowBg;
  final Color slideshowText;
  final Color slideshowMuted;
  final Color galaxyCanvas;
  final Color galaxyCanvasRaised;
  final Color galaxyOnCanvas;
  final Color galaxyMuted;
  final Color galaxyLine;
  final Color galaxyGlow;
  final Color galaxyPlaceholder;

  /// 从全局主题色派生 Photos 模块专属色
  factory PhotosColors.fromGlobal(GlobalThemeColors base) {
    final isDark =
        ThemeData.estimateBrightnessForColor(base.surface) == Brightness.dark;
    return PhotosColors(
      surface: base.surface,
      surfaceContainerLow: base.surfaceContainerLow,
      surfaceContainer: base.surfaceContainer,
      surfaceContainerHigh: base.surfaceContainerHigh,
      surfaceContainerHighest: base.surfaceContainerHighest,
      outlineVariant: base.outlineVariant,
      primaryContainer: base.accentCool,
      onPrimaryContainer:
          ThemeData.estimateBrightnessForColor(base.accentCool) ==
                  Brightness.dark
              ? Colors.white
              : Colors.black,
      tertiary: base.accentWarm,
      onSurface: base.onSurface,
      onSurfaceVariant: base.onSurfaceVariant,
      success: base.success,
      danger: base.error,
      timelineDivider: Color.lerp(Colors.transparent, base.onSurface, 0.06)!,
      albumCardShadow: base.shadow,
      overlay: base.overlay,
      overlayLight: base.overlayLight,
      badgeBg: base.badgeBg,
      badgeText: base.badgeText,
      mediaOverlayText: const Color(0xFFF6FAF7),
      slideshowBg: const Color(0xFF000000),
      slideshowText: const Color(0xFFFFFFFF),
      slideshowMuted: const Color(0xB3FFFFFF),
      galaxyCanvas:
          isDark ? base.surfaceContainerLowest : base.surfaceContainerLow,
      galaxyCanvasRaised:
          isDark ? base.surfaceContainer : base.surfaceContainerLowest,
      galaxyOnCanvas: base.onSurface,
      galaxyMuted: base.onSurfaceVariant,
      galaxyLine: Color.alphaBlend(
        base.accentCool.withValues(alpha: isDark ? 0.34 : 0.22),
        isDark ? base.surfaceContainerLowest : base.surfaceContainerLow,
      ),
      galaxyGlow: base.accentCool.withValues(alpha: isDark ? 0.52 : 0.34),
      galaxyPlaceholder: Color.alphaBlend(
        base.accentCool.withValues(alpha: isDark ? 0.14 : 0.10),
        isDark ? base.surfaceContainer : base.surfaceContainerHighest,
      ),
    );
  }

  static const List<PhotosColors> values = [];

  @override
  PhotosColors copyWith({
    Color? surface,
    Color? surfaceContainerLow,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? surfaceContainerHighest,
    Color? outlineVariant,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? tertiary,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? success,
    Color? danger,
    Color? timelineDivider,
    Color? albumCardShadow,
    Color? overlay,
    Color? overlayLight,
    Color? badgeBg,
    Color? badgeText,
    Color? mediaOverlayText,
    Color? slideshowBg,
    Color? slideshowText,
    Color? slideshowMuted,
    Color? galaxyCanvas,
    Color? galaxyCanvasRaised,
    Color? galaxyOnCanvas,
    Color? galaxyMuted,
    Color? galaxyLine,
    Color? galaxyGlow,
    Color? galaxyPlaceholder,
  }) {
    return PhotosColors(
      surface: surface ?? this.surface,
      surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceContainerHighest:
          surfaceContainerHighest ?? this.surfaceContainerHighest,
      outlineVariant: outlineVariant ?? this.outlineVariant,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      tertiary: tertiary ?? this.tertiary,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      timelineDivider: timelineDivider ?? this.timelineDivider,
      albumCardShadow: albumCardShadow ?? this.albumCardShadow,
      overlay: overlay ?? this.overlay,
      overlayLight: overlayLight ?? this.overlayLight,
      badgeBg: badgeBg ?? this.badgeBg,
      badgeText: badgeText ?? this.badgeText,
      mediaOverlayText: mediaOverlayText ?? this.mediaOverlayText,
      slideshowBg: slideshowBg ?? this.slideshowBg,
      slideshowText: slideshowText ?? this.slideshowText,
      slideshowMuted: slideshowMuted ?? this.slideshowMuted,
      galaxyCanvas: galaxyCanvas ?? this.galaxyCanvas,
      galaxyCanvasRaised: galaxyCanvasRaised ?? this.galaxyCanvasRaised,
      galaxyOnCanvas: galaxyOnCanvas ?? this.galaxyOnCanvas,
      galaxyMuted: galaxyMuted ?? this.galaxyMuted,
      galaxyLine: galaxyLine ?? this.galaxyLine,
      galaxyGlow: galaxyGlow ?? this.galaxyGlow,
      galaxyPlaceholder: galaxyPlaceholder ?? this.galaxyPlaceholder,
    );
  }

  @override
  PhotosColors lerp(PhotosColors? other, double t) {
    if (other is! PhotosColors) return this;
    return PhotosColors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceContainerLow:
          Color.lerp(surfaceContainerLow, other.surfaceContainerLow, t)!,
      surfaceContainer:
          Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      surfaceContainerHigh:
          Color.lerp(surfaceContainerHigh, other.surfaceContainerHigh, t)!,
      surfaceContainerHighest:
          Color.lerp(
            surfaceContainerHighest,
            other.surfaceContainerHighest,
            t,
          )!,
      outlineVariant: Color.lerp(outlineVariant, other.outlineVariant, t)!,
      primaryContainer:
          Color.lerp(primaryContainer, other.primaryContainer, t)!,
      onPrimaryContainer:
          Color.lerp(onPrimaryContainer, other.onPrimaryContainer, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant:
          Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      timelineDivider: Color.lerp(timelineDivider, other.timelineDivider, t)!,
      albumCardShadow: Color.lerp(albumCardShadow, other.albumCardShadow, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      overlayLight: Color.lerp(overlayLight, other.overlayLight, t)!,
      badgeBg: Color.lerp(badgeBg, other.badgeBg, t)!,
      badgeText: Color.lerp(badgeText, other.badgeText, t)!,
      mediaOverlayText:
          Color.lerp(mediaOverlayText, other.mediaOverlayText, t)!,
      slideshowBg: Color.lerp(slideshowBg, other.slideshowBg, t)!,
      slideshowText: Color.lerp(slideshowText, other.slideshowText, t)!,
      slideshowMuted: Color.lerp(slideshowMuted, other.slideshowMuted, t)!,
      galaxyCanvas: Color.lerp(galaxyCanvas, other.galaxyCanvas, t)!,
      galaxyCanvasRaised:
          Color.lerp(galaxyCanvasRaised, other.galaxyCanvasRaised, t)!,
      galaxyOnCanvas: Color.lerp(galaxyOnCanvas, other.galaxyOnCanvas, t)!,
      galaxyMuted: Color.lerp(galaxyMuted, other.galaxyMuted, t)!,
      galaxyLine: Color.lerp(galaxyLine, other.galaxyLine, t)!,
      galaxyGlow: Color.lerp(galaxyGlow, other.galaxyGlow, t)!,
      galaxyPlaceholder:
          Color.lerp(galaxyPlaceholder, other.galaxyPlaceholder, t)!,
    );
  }
}

extension PhotosColorsX on BuildContext {
  PhotosColors get photosColors => Theme.of(this).extension<PhotosColors>()!;
}
