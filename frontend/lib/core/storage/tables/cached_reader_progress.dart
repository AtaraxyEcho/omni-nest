import 'package:drift/drift.dart';

/// 本地缓存的阅读进度表（V3：按章节存储进度）。
///
/// 主键 (itemId, chapterId) 支持同时保存多个章节的进度，
/// 切换章节时不会覆盖之前章节的进度。
class CachedReaderProgress extends Table {
  TextColumn get itemId => text()();

  TextColumn get chapterId => text().withDefault(const Constant(''))();

  IntColumn get charOffset => integer().withDefault(const Constant(0))();

  RealColumn get chapterProgress => real().withDefault(const Constant(0))();

  TextColumn get mode => text().withDefault(const Constant('scroll'))();

  TextColumn get pageId => text().nullable()();

  IntColumn get pageIndex => integer().nullable()();

  TextColumn get pageFingerprint => text().nullable()();

  TextColumn get sourceId => text().nullable()();

  IntColumn get sourcePageIndex => integer().nullable()();

  TextColumn get catalogKey => text().nullable()();

  IntColumn get manifestVersion => integer().nullable()();

  RealColumn get intraPageOffset => real().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {itemId, chapterId};
}
