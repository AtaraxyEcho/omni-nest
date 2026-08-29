import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/core/security/offline_data_lifecycle.dart';
import 'package:omninest/core/security/offline_memory_cache.dart';
import 'package:omninest/core/storage/local_database.dart';

void main() {
  test('平台清理失败时仍清理内存和数据库中的用户数据', () async {
    final database = LocalDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database
        .into(database.syncOperations)
        .insert(
          SyncOperationsCompanion.insert(
            type: 'reader.progress',
            payload: '{"itemId":"book-1"}',
            createdAt: DateTime(2026, 7, 22),
          ),
        );
    OfflineMemoryCache.write(
      userId: 'user-1',
      cacheType: 'reader-book',
      businessId: 'book-1',
      bytes: Uint8List.fromList(const [1, 2, 3]),
    );
    final lifecycle = DatabaseOfflineDataLifecycle(
      delegate: _FailingOfflineDataLifecycle(),
      database: database,
    );

    await expectLater(
      lifecycle.clearUser('user-1'),
      throwsA(isA<FormatException>()),
    );

    expect(await database.select(database.syncOperations).get(), isEmpty);
    expect(
      OfflineMemoryCache.read(
        userId: 'user-1',
        cacheType: 'reader-book',
        businessId: 'book-1',
      ),
      isNull,
    );
  });
}

class _FailingOfflineDataLifecycle implements OfflineDataLifecycle {
  @override
  Future<void> clearUser(String userId) {
    throw const FormatException('测试平台清理失败');
  }
}
