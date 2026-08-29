import 'package:flutter/material.dart';
import 'package:omninest/app/theme/app_theme_palette.dart';
import 'package:omninest/app/theme/app_typography.dart';
import 'package:omninest/app/theme/feature/admin_colors.dart';
import 'package:omninest/app/theme/feature/files_colors.dart';
import 'package:omninest/app/theme/feature/music_colors.dart';
import 'package:omninest/app/theme/feature/photos_colors.dart';
import 'package:omninest/app/theme/feature/reader_colors.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:omninest/app/theme/global_theme_colors.dart';

class OmniNestTheme {
  const OmniNestTheme._();

  static ThemeData light() => _build(AppThemePalette.light);

  static ThemeData dark() => _build(AppThemePalette.dark);

  static ThemeData from(
    GlobalThemeColors colors, {
    MusicColors? musicColors,
    VideoColors? videoColors,
    ReaderColors? readerColors,
    PhotosColors? photosColors,
    FilesColors? filesColors,
  }) {
    return _build(
      colors,
      musicColors: musicColors,
      videoColors: videoColors,
      readerColors: readerColors,
      photosColors: photosColors,
      filesColors: filesColors,
    );
  }

  static ThemeData _build(
    GlobalThemeColors colors, {
    MusicColors? musicColors,
    VideoColors? videoColors,
    ReaderColors? readerColors,
    PhotosColors? photosColors,
    FilesColors? filesColors,
  }) {
    final brightness = ThemeData.estimateBrightnessForColor(colors.surface);
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: colors.primaryContainer,
      onPrimaryContainer: colors.onPrimaryContainer,
      secondary: colors.secondary,
      onSecondary: colors.onPrimary,
      secondaryContainer: colors.secondaryContainer,
      onSecondaryContainer: colors.onPrimaryContainer,
      tertiary: colors.tertiary,
      onTertiary: colors.onPrimary,
      tertiaryContainer: colors.tertiaryContainer,
      onTertiaryContainer: colors.onPrimaryContainer,
      error: colors.error,
      onError: colors.onError,
      surface: colors.surface,
      onSurface: colors.onSurface,
      onSurfaceVariant: colors.onSurfaceVariant,
      outline: colors.outline,
      outlineVariant: colors.outlineVariant,
      surfaceContainerLowest: colors.surfaceContainerLowest,
      surfaceContainerLow: colors.surfaceContainerLow,
      surfaceContainer: colors.surfaceContainer,
      surfaceContainerHigh: colors.surfaceContainerHigh,
      surfaceContainerHighest: colors.surfaceContainerHighest,
    );
    final textTheme = const TextTheme(
      displayLarge: AppTypography.displayLarge,
      headlineLarge: AppTypography.headlineLarge,
      headlineMedium: AppTypography.headlineMedium,
      bodyLarge: AppTypography.bodyLarge,
      bodyMedium: AppTypography.bodyMedium,
      bodySmall: AppTypography.bodySmall,
      labelMedium: AppTypography.labelMedium,
    ).apply(bodyColor: colors.onSurface, displayColor: colors.onSurface);
    final roundedShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colors.outlineVariant),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.surface,
      canvasColor: colors.surface,
      dividerColor: colors.outlineVariant,
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: colors.onSurfaceVariant, size: 20),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: isDark ? 0.32 : 0.22),
        selectionHandleColor: colors.primary,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: roundedShape.copyWith(
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: roundedShape,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainerLow,
        modalBackgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.error),
        ),
        labelStyle: TextStyle(color: colors.onSurfaceVariant),
        hintStyle: TextStyle(color: colors.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: roundedShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onSurface,
          minimumSize: const Size(44, 44),
          side: BorderSide(color: colors.outline),
          shape: roundedShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(40, 40),
          shape: roundedShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.onSurfaceVariant,
          minimumSize: const Size(40, 40),
          shape: roundedShape,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceContainer,
        selectedColor: colors.primary.withValues(alpha: isDark ? 0.24 : 0.14),
        labelStyle: TextStyle(color: colors.onSurface),
        checkmarkColor: colors.primary,
        side: BorderSide(color: colors.outlineVariant),
        shape: roundedShape,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.onSurfaceVariant,
        textColor: colors.onSurface,
        selectedColor: colors.primary,
        selectedTileColor: colors.selectedOverlay,
        shape: roundedShape,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: colors.outline),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? colors.onPrimary
                  : colors.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? colors.primary
                  : colors.surfaceContainerHighest,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.surfaceContainerHighest,
        thumbColor: colors.primary,
        overlayColor: colors.primary.withValues(alpha: 0.14),
        trackHeight: 3,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: colors.surfaceContainerLow,
        indicatorColor: colors.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        backgroundColor: colors.surfaceContainerLow,
        indicatorColor: colors.primaryContainer,
        selectedIconTheme: IconThemeData(color: colors.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: colors.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(color: colors.onSurface),
        unselectedLabelTextStyle: TextStyle(color: colors.onSurfaceVariant),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: roundedShape,
        textStyle: textTheme.bodyMedium?.copyWith(color: colors.onSurface),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerLow),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(roundedShape),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? colors.surfaceContainerHighest : colors.onSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(
          color: isDark ? colors.onSurface : colors.surface,
          fontSize: 12,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? colors.surfaceContainerHighest : colors.onSurface,
        contentTextStyle: TextStyle(
          color: isDark ? colors.onSurface : colors.surface,
        ),
        shape: roundedShape,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStatePropertyAll(
          colors.onSurfaceVariant.withValues(alpha: 0.55),
        ),
        trackColor: WidgetStatePropertyAll(
          colors.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(colors.surfaceContainerLow),
        dataRowColor: WidgetStatePropertyAll(colors.surface),
        headingTextStyle: textTheme.labelLarge?.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: textTheme.bodyMedium?.copyWith(color: colors.onSurface),
        dividerThickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceContainerHighest,
        circularTrackColor: colors.surfaceContainerHighest,
      ),
      extensions: [
        colors,
        AdminColors.fromGlobal(colors),
        musicColors ?? MusicColors.fromGlobal(_musicAccent(colors, isDark)),
        videoColors ?? VideoColors.fromGlobal(_videoAccent(colors, isDark)),
        readerColors ?? ReaderColors.fromGlobal(_readerAccent(colors, isDark)),
        photosColors ?? PhotosColors.fromGlobal(_photosAccent(colors, isDark)),
        filesColors ?? FilesColors.fromGlobal(_filesAccent(colors, isDark)),
      ],
    );
  }

  static GlobalThemeColors _accent(
    GlobalThemeColors base, {
    required Color primary,
    required Color primaryContainer,
    required Color warm,
    required Color cool,
    required bool isDark,
  }) {
    return GlobalThemeColors(
      surface: base.surface,
      surfaceContainerLowest: base.surfaceContainerLowest,
      surfaceContainerLow: base.surfaceContainerLow,
      surfaceContainer: base.surfaceContainer,
      surfaceContainerHigh: base.surfaceContainerHigh,
      surfaceContainerHighest: base.surfaceContainerHighest,
      onSurface: base.onSurface,
      onSurfaceVariant: base.onSurfaceVariant,
      primary: primary,
      primaryContainer: primaryContainer,
      onPrimary: isDark ? const Color(0xFF061513) : Colors.white,
      onPrimaryContainer: base.onPrimaryContainer,
      secondary: base.secondary,
      secondaryContainer: base.secondaryContainer,
      tertiary: cool,
      tertiaryContainer: Color.lerp(base.surfaceContainerHighest, cool, 0.22)!,
      error: base.error,
      onError: base.onError,
      outline: base.outline,
      outlineVariant: base.outlineVariant,
      accentWarm: warm,
      accentCool: cool,
      success: base.success,
      warning: base.warning,
      info: base.info,
      hoverOverlay:
          Color.lerp(Colors.transparent, primary, isDark ? 0.12 : 0.07)!,
      selectedOverlay:
          Color.lerp(Colors.transparent, primary, isDark ? 0.20 : 0.12)!,
      focusRing: Color.lerp(Colors.transparent, primary, isDark ? 0.48 : 0.32)!,
      overlay: base.overlay,
      overlayLight: base.overlayLight,
      shadow: base.shadow,
      star: base.star,
      badgeBg: base.badgeBg,
      badgeText: base.badgeText,
    );
  }

  static GlobalThemeColors _readerAccent(GlobalThemeColors base, bool isDark) {
    return _accent(
      base,
      primary: isDark ? const Color(0xFFB8D9C5) : const Color(0xFF2F6B4F),
      primaryContainer:
          isDark ? const Color(0xFF254235) : const Color(0xFFDCEFE4),
      warm: isDark ? const Color(0xFFE4C98D) : const Color(0xFF8E6A28),
      cool: isDark ? const Color(0xFFA8C8D9) : const Color(0xFF3E7188),
      isDark: isDark,
    );
  }

  static GlobalThemeColors _videoAccent(GlobalThemeColors base, bool isDark) {
    return _accent(
      base,
      primary: isDark ? const Color(0xFFFFC2A6) : const Color(0xFF9A3412),
      primaryContainer:
          isDark ? const Color(0xFF4B2418) : const Color(0xFFFFE1D2),
      warm: isDark ? const Color(0xFFF5B97A) : const Color(0xFFB45309),
      cool: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
      isDark: isDark,
    );
  }

  static GlobalThemeColors _musicAccent(GlobalThemeColors base, bool isDark) {
    return _accent(
      base,
      primary: isDark ? const Color(0xFF8BD9D5) : const Color(0xFF176B72),
      primaryContainer:
          isDark ? const Color(0xFF194A4C) : const Color(0xFFD4ECEB),
      warm: isDark ? const Color(0xFFE7A6B4) : const Color(0xFFA33F58),
      cool: isDark ? const Color(0xFFA7CBE0) : const Color(0xFF356F8A),
      isDark: isDark,
    );
  }

  static GlobalThemeColors _photosAccent(GlobalThemeColors base, bool isDark) {
    return _accent(
      base,
      primary: isDark ? const Color(0xFFF2C6A4) : const Color(0xFFB25B24),
      primaryContainer:
          isDark ? const Color(0xFF48301F) : const Color(0xFFFFE7D4),
      warm: isDark ? const Color(0xFFF0C177) : const Color(0xFFB7791F),
      cool: isDark ? const Color(0xFF98D5C3) : const Color(0xFF237865),
      isDark: isDark,
    );
  }

  static GlobalThemeColors _filesAccent(GlobalThemeColors base, bool isDark) {
    return _accent(
      base,
      primary: isDark ? const Color(0xFFA7E4E1) : const Color(0xFF08756F),
      primaryContainer:
          isDark ? const Color(0xFF183D3B) : const Color(0xFFD7F1EF),
      warm: isDark ? const Color(0xFFE5C28B) : const Color(0xFF9A6A16),
      cool: isDark ? const Color(0xFF9EDCE6) : const Color(0xFF247B8A),
      isDark: isDark,
    );
  }
}
