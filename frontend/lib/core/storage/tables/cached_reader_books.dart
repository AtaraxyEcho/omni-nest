import 'package:drift/drift.dart';

/// 本地缓存的书籍元数据表。
///
/// 存储 EPUB/TXT 解析后的元数据和章节目录，
/// 避免每次打开书籍都重新解析。
class CachedReaderBooks extends Table {
  /// 书籍条目 ID（主键）
  TextColumn get itemId => text()();

  /// 书籍标题
  TextColumn get title => text().nullable()();

  /// 作者
  TextColumn get author => text().nullable()();

  /// 简介
  TextColumn get description => text().nullable()();

  /// 出版社
  TextColumn get publisher => text().nullable()();

  /// 语言
  TextColumn get language => text().nullable()();

  /// 章节列表 JSON（List<Map>，含 number/title/charCount/contentPath）
  TextColumn get chaptersJson => text().withDefault(const Constant('[]'))();

  /// 总字符数
  IntColumn get totalChars => integer().withDefault(const Constant(0))();

  /// 文件类型（EPUB/TXT/PDF）
  TextColumn get itemType => text().withDefault(const Constant('EPUB'))();

  /// 缓存创建时间
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {itemId};
}
