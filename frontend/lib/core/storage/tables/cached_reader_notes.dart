import 'package:drift/drift.dart';

/// 本地缓存的阅读笔记表（离线优先存储）。
class CachedReaderNotes extends Table {
  TextColumn get id => text()();

  TextColumn get readerItemId => text()();

  IntColumn get charOffset => integer().nullable()();

  TextColumn get title => text().nullable()();

  TextColumn get content => text()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
