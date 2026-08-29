import 'dart:ui';

/// 阅读器内容块的基础类型。
sealed class ContentBlock {}

/// 标题内容块。
class HeadingBlock extends ContentBlock {
  HeadingBlock({required this.text, required this.level, this.startOffset = 0});

  final String text;
  final int level;
  final int startOffset;
}

/// 段落内容块。
class ParagraphBlock extends ContentBlock {
  ParagraphBlock({required this.lines, this.hasTrailingSpacing = false});

  final List<LineData> lines;
  final bool hasTrailingSpacing;
}

/// 段落中的逻辑行。
class LineData {
  const LineData({required this.spans, this.isNewParagraph = false});

  final List<ReaderInlineSpan> spans;

  /// 标记此行是否为合并后新段落的起始行。
  final bool isNewParagraph;
}

/// 图片内容块。
class ImageBlock extends ContentBlock {
  ImageBlock({required this.src, this.caption, this.alt});

  final String src;
  final String? caption;
  final String? alt;
}

/// 分隔线内容块。
class DividerBlock extends ContentBlock {}

/// 引用内容块。
class BlockquoteBlock extends ContentBlock {
  BlockquoteBlock({required this.lines, this.startOffset = 0});

  final List<LineData> lines;
  final int startOffset;
}

/// 列表内容块。
class ListBlock extends ContentBlock {
  ListBlock({
    required this.items,
    required this.isOrdered,
    this.startOffset = 0,
  });

  final List<ListItemData> items;
  final bool isOrdered;
  final int startOffset;
}

/// 列表项数据。
class ListItemData {
  const ListItemData({required this.spans});

  final List<ReaderInlineSpan> spans;
}

/// 表格内容块。
class TableBlock extends ContentBlock {
  TableBlock({required this.rows, this.startOffset = 0});

  final List<TableRowData> rows;
  final int startOffset;
}

/// 表格行数据。
class TableRowData {
  const TableRowData({required this.cells, required this.isHeader});

  final List<List<ReaderInlineSpan>> cells;
  final bool isHeader;
}

/// 阅读器行内文本及样式信息。
class ReaderInlineSpan {
  const ReaderInlineSpan({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isHeading = false,
    this.href,
    this.isCode = false,
    this.startOffset = 0,
    this.backgroundColor,
    this.isSuperscript = false,
    this.isSubscript = false,
    this.isMarked = false,
    this.isDeleted = false,
    this.isUnderlined = false,
  });

  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isHeading;
  final String? href;
  final bool isCode;
  final int startOffset;
  final Color? backgroundColor;
  final bool isSuperscript;
  final bool isSubscript;
  final bool isMarked;
  final bool isDeleted;
  final bool isUnderlined;
}
