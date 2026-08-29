import 'package:drift/drift.dart';

/// 本地缓存的文件元数据表
class CachedFiles extends Table {
  TextColumn get id => text()();

  TextColumn get fileName => text()();

  IntColumn get sizeBytes => integer()();

  TextColumn get mimeType => text().nullable()();

  TextColumn get localPath => text().nullable()();

  DateTimeColumn get cachedAt => dateTime()();

  DateTimeColumn get lastAccessedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
