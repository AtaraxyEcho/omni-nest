import 'package:drift/drift.dart';

/// 本地缓存的阅读标注表（离线优先存储）。
class CachedReaderAnnotations extends Table {
  TextColumn get id => text()();

  TextColumn get readerItemId => text()();

  TextColumn get chapterId => text().nullable()();

  IntColumn get startOffset => integer()();

  IntColumn get endOffset => integer()();

  TextColumn get highlightText => text().nullable()();

  TextColumn get note => text().nullable()();

  TextColumn get color => text().withDefault(const Constant('#FFEB3B'))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
