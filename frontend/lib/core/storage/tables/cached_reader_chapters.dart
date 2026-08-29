import 'package:drift/drift.dart';

/// 本地缓存的章节内容表。
///
/// 存储从 EPUB 提取并预处理后的 XHTML 内容，
/// 避免每次打开章节都重新从 ZIP 提取和 base64 编码图片。
class CachedReaderChapters extends Table {
  /// 书籍条目 ID
  TextColumn get itemId => text()();

  /// 章节内容路径（EPUB 内部路径，如 OEBPS/chapter1.xhtml）
  TextColumn get contentPath => text()();

  /// 章节标题
  TextColumn get title => text().withDefault(const Constant(''))();

  /// 章节序号
  IntColumn get chapterNumber => integer().withDefault(const Constant(0))();

  /// 原始 XHTML 字符数
  IntColumn get charCount => integer().withDefault(const Constant(0))();

  /// 预处理后的 HTML 内容（已提取 body、图片已转 base64）
  TextColumn get processedHtml => text()();

  /// 缓存创建时间
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {itemId, contentPath};
}
