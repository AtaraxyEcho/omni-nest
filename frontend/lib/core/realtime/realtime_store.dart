import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:omninest/core/realtime/realtime_models.dart';
import 'package:omninest/core/storage/local_database.dart';

/// 按服务端和用户隔离的实时同步本地事务存储。
class RealtimeStore {
  RealtimeStore({
    required LocalDatabase database,
    required this.serverKey,
    required this.userId,
  }) : _database = database;

  final LocalDatabase _database;
  final String serverKey;
  final String userId;

  /// 读取当前本地同步状态。
  Future<SyncClientState?> readState() {
    return (_database.select(_database.syncClientStates)..where(
      (table) =>
          table.serverKey.equals(serverKey) & table.userId.equals(userId),
    )).getSingleOrNull();
  }

  /// 首次登录时仅在状态不存在的情况下保存 bootstrap 游标。
  Future<void> initializeCursor({
    required int cursor,
    required int schemaVersion,
  }) {
    return _database
        .into(_database.syncClientStates)
        .insert(
          SyncClientStatesCompanion.insert(
            serverKey: serverKey,
            userId: userId,
            cursor: Value(cursor),
            schemaVersion: Value(schemaVersion),
            lastSyncAt: Value(DateTime.now().toUtc()),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// 原子摄取实时事件，但不推进 REST 游标。
  Future<bool> ingestLive(RealtimeSyncEvent event) {
    return _database.transaction(() async {
      final state = await readState();
      if (state != null && event.sequenceNo <= state.cursor) {
        return false;
      }
      return _ingestEvent(event);
    });
  }

  /// 原子摄取有序 REST 页面并在同一事务中推进游标。
  Future<Set<RealtimeScope>> ingestRestPage(
    List<RealtimeSyncEvent> events, {
    required int nextCursor,
    required int schemaVersion,
  }) {
    return _database.transaction(() async {
      final state = await readState();
      final previousCursor = state?.cursor ?? 0;
      final ordered = [...events]
        ..sort((left, right) => left.sequenceNo.compareTo(right.sequenceNo));
      final changedScopes = <RealtimeScope>{};
      for (final event in ordered) {
        if (event.sequenceNo <= previousCursor) {
          continue;
        }
        if (await _ingestEvent(event)) {
          changedScopes.add(event.scope);
        }
      }
      await _database
          .into(_database.syncClientStates)
          .insertOnConflictUpdate(
            SyncClientStatesCompanion.insert(
              serverKey: serverKey,
              userId: userId,
              cursor: Value(nextCursor),
              schemaVersion: Value(schemaVersion),
              lastSyncAt: Value(DateTime.now().toUtc()),
            ),
          );
      return changedScopes;
    });
  }

  /// 游标过期时原子标记所有作用域失效并移动到服务端最新游标。
  Future<void> resetToCursor({
    required int latestCursor,
    required int schemaVersion,
  }) {
    return _database.transaction(() async {
      for (final scope in RealtimeScope.values) {
        await _upsertInvalidation(
          scope: scope,
          resourceType: '*',
          resourceId: null,
        );
      }
      await _database
          .into(_database.syncClientStates)
          .insertOnConflictUpdate(
            SyncClientStatesCompanion.insert(
              serverKey: serverKey,
              userId: userId,
              cursor: Value(latestCursor),
              schemaVersion: Value(schemaVersion),
              lastSyncAt: Value(DateTime.now().toUtc()),
            ),
          );
    });
  }

  /// 查询当前尚未被业务模块确认的失效记录。
  Future<List<RealtimeInvalidation>> pendingInvalidations() async {
    final rows =
        await (_database.select(_database.syncPendingInvalidations)
              ..where(
                (table) =>
                    table.serverKey.equals(serverKey) &
                    table.userId.equals(userId),
              )
              ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
            .get();
    return rows
        .map(
          (row) => RealtimeInvalidation(
            key: row.invalidationKey,
            scope: RealtimeScope.parse(row.scope),
            resourceType: row.resourceType,
            resourceId: row.resourceId,
            revision: row.revision,
            createdAt: row.createdAt,
          ),
        )
        .toList(growable: false);
  }

  /// 仅确认不高于业务刷新开始时 revision 的失效记录。
  Future<int> acknowledge(RealtimeInvalidation invalidation) {
    return (_database.delete(_database.syncPendingInvalidations)..where(
      (table) =>
          table.serverKey.equals(serverKey) &
          table.userId.equals(userId) &
          table.invalidationKey.equals(invalidation.key) &
          table.revision.isSmallerOrEqualValue(invalidation.revision),
    )).go();
  }

  /// 清理已被当前游标覆盖且超过保留时间的事件去重记录。
  Future<int> cleanupProcessedEvents({
    Duration maxAge = const Duration(days: 7),
  }) async {
    final state = await readState();
    if (state == null) {
      return 0;
    }
    final cutoff = DateTime.now().toUtc().subtract(maxAge);
    return (_database.delete(_database.syncProcessedEvents)..where(
      (table) =>
          table.serverKey.equals(serverKey) &
          table.userId.equals(userId) &
          table.processedAt.isSmallerThanValue(cutoff) &
          table.sequenceNo.isSmallerOrEqualValue(state.cursor),
    )).go();
  }

  Future<bool> _ingestEvent(RealtimeSyncEvent event) async {
    final existing =
        await (_database.select(_database.syncProcessedEvents)..where(
          (table) =>
              table.serverKey.equals(serverKey) &
              table.userId.equals(userId) &
              table.eventId.equals(event.eventId),
        )).getSingleOrNull();
    if (existing != null) {
      return false;
    }
    await _database
        .into(_database.syncProcessedEvents)
        .insert(
          SyncProcessedEventsCompanion.insert(
            serverKey: serverKey,
            userId: userId,
            eventId: event.eventId,
            sequenceNo: event.sequenceNo,
            processedAt: DateTime.now().toUtc(),
          ),
        );
    await _upsertInvalidation(
      scope: event.scope,
      resourceType: event.resourceType,
      resourceId: event.resourceId,
    );
    return true;
  }

  Future<void> _upsertInvalidation({
    required RealtimeScope scope,
    required String resourceType,
    required String? resourceId,
  }) async {
    final key = jsonEncode([scope.name, resourceType, resourceId]);
    final existing =
        await (_database.select(_database.syncPendingInvalidations)..where(
          (table) =>
              table.serverKey.equals(serverKey) &
              table.userId.equals(userId) &
              table.invalidationKey.equals(key),
        )).getSingleOrNull();
    await _database
        .into(_database.syncPendingInvalidations)
        .insertOnConflictUpdate(
          SyncPendingInvalidationsCompanion.insert(
            serverKey: serverKey,
            userId: userId,
            invalidationKey: key,
            scope: scope.name,
            resourceType: resourceType,
            resourceId: Value(resourceId),
            revision: Value((existing?.revision ?? 0) + 1),
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }
}
