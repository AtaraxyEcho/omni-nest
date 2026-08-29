import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/features/reader/domain/comic_reader_display_settings.dart';
import 'package:omninest/features/reader/presentation/widgets/comic_reader_layout.dart';

void main() {
  group('ComicReaderLayout', () {
    test('移动端连续阅读使用全部可用宽度', () {
      final layout = ComicReaderLayout.resolve(
        viewport: const Size(390, 844),
        preferredContentWidth: 960,
        fullWidth: false,
      );

      expect(layout.horizontalPadding, 0);
      expect(layout.contentWidth, 390);
      expect(layout.pagedPadding, const EdgeInsets.all(8));
    });

    test('桌面端默认限制页面宽度', () {
      final layout = ComicReaderLayout.resolve(
        viewport: const Size(3840, 2160),
        preferredContentWidth: 960,
        fullWidth: false,
      );

      expect(layout.horizontalPadding, 40);
      expect(layout.contentWidth, 960);
      expect(layout.pagedPadding, const EdgeInsets.all(32));
    });

    test('桌面端全宽模式使用扣除边距后的宽度', () {
      final layout = ComicReaderLayout.resolve(
        viewport: const Size(1920, 1080),
        preferredContentWidth: 960,
        fullWidth: true,
      );

      expect(layout.contentWidth, 1840);
    });
  });

  test('漫画偏好会校验持久化数值范围', () {
    final settings = ComicReaderDisplaySettings.fromPreferences(const {
      'comicReadingMode': 'invalid',
      'comicContentWidth': 5000,
      'comicPageGap': -5,
    }, defaultReadingMode: 'scroll');

    expect(settings.readingMode, 'scroll');
    expect(settings.contentWidth, 1440);
    expect(settings.pageGap, 0);
  });
}
