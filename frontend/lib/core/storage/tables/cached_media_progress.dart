import 'package:drift/drift.dart';

/// 本地缓存的媒体播放进度表
class CachedMediaProgress extends Table {
  TextColumn get mediaId => text()();

  TextColumn get mediaType => text()();

  RealColumn get progressPercent => real()();

  IntColumn get positionSeconds => integer()();

  IntColumn get durationSeconds => integer()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {mediaId};
}
