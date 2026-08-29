/// 漫画阅读器独立显示设置。
class ComicReaderDisplaySettings {
  const ComicReaderDisplaySettings({
    required this.readingMode,
    this.fullWidth = false,
    this.contentWidth = 960,
    this.pageGap = 8,
  });

  factory ComicReaderDisplaySettings.fromPreferences(
    Map<String, dynamic> preferences, {
    required String defaultReadingMode,
  }) {
    final rawMode = preferences['comicReadingMode']?.toString();
    final rawWidth =
        (preferences['comicContentWidth'] as num?)?.toDouble() ?? 960;
    final rawGap = (preferences['comicPageGap'] as num?)?.toDouble() ?? 8;
    return ComicReaderDisplaySettings(
      readingMode:
          rawMode == 'page' || rawMode == 'scroll'
              ? rawMode!
              : defaultReadingMode,
      fullWidth: preferences['comicFullWidth'] as bool? ?? false,
      contentWidth: rawWidth.clamp(480, 1440),
      pageGap: rawGap.clamp(0, 24),
    );
  }

  final String readingMode;
  final bool fullWidth;
  final double contentWidth;
  final double pageGap;

  ComicReaderDisplaySettings copyWith({
    String? readingMode,
    bool? fullWidth,
    double? contentWidth,
    double? pageGap,
  }) {
    return ComicReaderDisplaySettings(
      readingMode: readingMode ?? this.readingMode,
      fullWidth: fullWidth ?? this.fullWidth,
      contentWidth: contentWidth ?? this.contentWidth,
      pageGap: pageGap ?? this.pageGap,
    );
  }

  Map<String, dynamic> toPreferences() => {
    'comicReadingMode': readingMode,
    'comicFullWidth': fullWidth,
    'comicContentWidth': contentWidth,
    'comicPageGap': pageGap,
  };
}
