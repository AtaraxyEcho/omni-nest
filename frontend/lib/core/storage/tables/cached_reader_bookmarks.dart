import 'package:drift/drift.dart';

/// 本地缓存的阅读书签表
class CachedReaderBookmarks extends Table {
  TextColumn get id => text()();

  TextColumn get readerItemId => text()();

  IntColumn get charOffset => integer().withDefault(const Constant(0))();

  RealColumn get progressPercent => real().withDefault(const Constant(0))();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
