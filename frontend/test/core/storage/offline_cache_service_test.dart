import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/core/storage/cache_policy.dart';
import 'package:omninest/core/storage/local_database.dart';
import 'package:omninest/core/storage/offline_cache_service.dart';

void main() {
  late LocalDatabase db;
  late OfflineCacheService service;

  setUp(() {
    db = LocalDatabase(NativeDatabase.memory());
    const policy = CachePolicy(maxBytes: 500);
    service = OfflineCacheService(db, policy);
  });

  tearDown(() async {
    await db.close();
  });

  group('OfflineCacheService', () {
    test('cacheFile stores and retrieves metadata', () async {
      await service.cacheFile(
        id: 'f1',
        fileName: 'test.pdf',
        sizeBytes: 100,
        mimeType: 'application/pdf',
      );
      final allFiles = await db.select(db.cachedFiles).get();
      expect(allFiles, hasLength(1));
      expect(allFiles.first.id, 'f1');
      expect(allFiles.first.fileName, 'test.pdf');
      expect(allFiles.first.sizeBytes, 100);
      expect(allFiles.first.mimeType, 'application/pdf');
    });

    test('getCachedFile returns null for missing file', () async {
      final cached = await service.getCachedFile('nonexistent');
      expect(cached, isNull);
    });

    test('removeCachedFile deletes the entry', () async {
      await service.cacheFile(id: 'f1', fileName: 'a.pdf', sizeBytes: 100);
      await service.removeCachedFile('f1');
      final allFiles = await db.select(db.cachedFiles).get();
      expect(allFiles, isEmpty);
    });

    test('currentCacheBytes returns total size', () async {
      await service.cacheFile(id: 'f1', fileName: 'a', sizeBytes: 100);
      await service.cacheFile(id: 'f2', fileName: 'b', sizeBytes: 200);
      expect(await service.currentCacheBytes(), 300);
    });

    test('eviction removes oldest files when over limit', () async {
      // maxBytes = 500, 添加两个文件超过限制
      await service.cacheFile(id: 'f1', fileName: 'a', sizeBytes: 300);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await service.cacheFile(id: 'f2', fileName: 'b', sizeBytes: 300);

      // 驱逐后应只剩一个文件
      final allFiles = await db.select(db.cachedFiles).get();
      expect(allFiles, hasLength(1));
      expect(allFiles.first.id, 'f2');
    });

    test('eviction keeps files when under limit', () async {
      await service.cacheFile(id: 'f1', fileName: 'a', sizeBytes: 100);
      await service.cacheFile(id: 'f2', fileName: 'b', sizeBytes: 100);
      final allFiles = await db.select(db.cachedFiles).get();
      expect(allFiles, hasLength(2));
    });

    test('cacheFile with insertOnConflictUpdate replaces existing', () async {
      await service.cacheFile(id: 'f1', fileName: 'old.pdf', sizeBytes: 100);
      await service.cacheFile(id: 'f1', fileName: 'new.pdf', sizeBytes: 200);
      final allFiles = await db.select(db.cachedFiles).get();
      expect(allFiles, hasLength(1));
      expect(allFiles.first.fileName, 'new.pdf');
      expect(allFiles.first.sizeBytes, 200);
    });
  });
}
