import 'package:drift/drift.dart';

/// 本地缓存的书籍详情表。
///
/// 缓存 API 返回的 ReaderItemDetail JSON，
/// 避免每次打开阅读页都请求网络。
class CachedReaderBookDetails extends Table {
  /// 书籍条目 ID（主键）
  TextColumn get itemId => text()();

  /// 完整的 ReaderItemDetail JSON
  TextColumn get detailJson => text()();

  /// 缓存创建时间
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {itemId};
}
