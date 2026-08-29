import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/features/reader/presentation/widgets/block_clipper.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_html_parser.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_pagination_engine.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_view_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final settings = ReaderViewSettings(
    fontFamily: 'sans',
    fontSize: 18,
    lineHeight: 1.6,
  );

  test('懒分页从上一页结束字符继续推进', () {
    final text = List<String>.filled(240, 'pagination content').join(' ');
    final blocks = parseBlocks('<p>$text</p>');

    final first = ReaderPaginationEngine.computePage(
      blocks,
      180,
      140,
      settings,
      0,
    );

    expect(first, isNotNull);
    expect(first!.endCharOffset, greaterThan(first.startCharOffset));
    expect(first.endCharOffset, lessThan(text.length));

    final second = ReaderPaginationEngine.computePage(
      blocks,
      180,
      140,
      settings,
      first.endCharOffset,
    );

    expect(second, isNotNull);
    expect(second!.startCharOffset, first.endCharOffset);
    expect(second.endCharOffset, greaterThan(second.startCharOffset));
  });

  test('视觉行字符范围保持单调且包含全局偏移', () {
    final blocks = parseBlocks(
      '<p>${List<String>.filled(40, 'visual line').join(' ')}</p>',
    );
    final paragraph = blocks.single;

    final lines = ReaderPaginationEngine.measureVisualLines(
      paragraph,
      160,
      settings,
      1,
      blockGlobalOffset: 32,
    );

    expect(lines.length, greaterThan(1));
    expect(lines.first.globalStart, greaterThanOrEqualTo(32));
    for (var index = 0; index < lines.length; index++) {
      expect(lines[index].globalEnd, greaterThan(lines[index].globalStart));
      if (index > 0) {
        expect(
          lines[index].globalStart,
          greaterThanOrEqualTo(lines[index - 1].globalStart),
        );
        expect(
          lines[index].globalEnd,
          greaterThanOrEqualTo(lines[index - 1].globalEnd),
        );
      }
    }
  });

  test('文本块高度与字符内偏移高度保持有效范围', () {
    final block =
        parseBlocks(
          '<p>${List<String>.filled(30, 'height sample').join(' ')}</p>',
        ).single;
    final totalHeight = ReaderPaginationEngine.measureBlockHeight(
      block,
      200,
      settings,
    );
    final partialHeight = ReaderPaginationEngine.measureHeightToCharOffset(
      block,
      200,
      settings,
      24,
    );

    expect(totalHeight, greaterThan(0));
    expect(partialHeight, greaterThanOrEqualTo(0));
    expect(partialHeight, lessThanOrEqualTo(totalHeight));
  });
  test('分页切片的实际排版高度不会超过可用视口', () {
    const pageWidth = 320.0;
    const pageHeight = 360.0;
    final text = List<String>.filled(260, '桌面窗口变化后分页内容仍需完整衔接').join();
    final blocks = parseBlocks('<p>$text</p>');
    var startOffset = 0;
    var pageCount = 0;

    while (startOffset < text.length && pageCount < 200) {
      final slice = ReaderPaginationEngine.computePage(
        blocks,
        pageWidth,
        pageHeight,
        settings,
        startOffset,
      );
      expect(slice, isNotNull);
      expect(slice!.endCharOffset, greaterThan(startOffset));

      final visibleBlocks = BlockClipper.clipBlocksByCharRange(
        blocks,
        slice.startCharOffset,
        slice.endCharOffset,
      );
      final renderedHeight = visibleBlocks.fold<double>(
        0,
        (height, block) =>
            height +
            ReaderPaginationEngine.measureBlockHeight(
              block,
              pageWidth,
              settings,
            ),
      );
      expect(renderedHeight, lessThanOrEqualTo(pageHeight));

      startOffset = slice.endCharOffset;
      pageCount++;
    }

    expect(startOffset, text.length);
    expect(pageCount, greaterThan(1));
  });

  test('窗口高度变化后分页末行始终完整落在底部安全区内', () {
    const pageWidth = 320.0;
    final text = List<String>.filled(180, '窗口缩放时最后一行不能只显示一半').join();
    final blocks = parseBlocks('<p>$text</p>');
    final lines = ReaderPaginationEngine.measureVisualLines(
      blocks.single,
      pageWidth,
      settings,
      1,
      blockGlobalOffset: 0,
    );

    for (final pageHeight in <double>[241.5, 317.25, 463.75]) {
      final slice = ReaderPaginationEngine.computePage(
        blocks,
        pageWidth,
        pageHeight,
        settings,
        0,
      );
      expect(slice, isNotNull);
      final fittedHeight = lines
          .where((line) => line.globalEnd <= slice!.endCharOffset)
          .fold<double>(0, (height, line) => height + line.height);
      final usableHeight = ReaderPaginationEngine.usablePageHeight(
        pageHeight,
        settings,
        1,
      );
      final renderedLineHeight = settings.fontSize * settings.lineHeight;

      expect(fittedHeight, lessThanOrEqualTo(usableHeight + 0.01));
      expect(pageHeight - usableHeight, greaterThan(renderedLineHeight));
    }
  });
}
