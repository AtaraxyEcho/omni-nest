import 'package:drift/drift.dart';

/// 已摄取同步事件的限时去重记录表。
class SyncProcessedEvents extends Table {
  TextColumn get serverKey => text()();

  TextColumn get userId => text()();

  TextColumn get eventId => text()();

  IntColumn get sequenceNo => integer()();

  DateTimeColumn get processedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {serverKey, userId, eventId};
}
