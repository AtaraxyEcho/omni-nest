import 'package:drift/drift.dart';
import 'package:omninest/core/storage/cache_policy.dart';
import 'package:omninest/core/storage/local_database.dart';

/// 离线缓存服务：管理本地文件缓存的读写和驱逐。
class OfflineCacheService {
  OfflineCacheService(this._db, this._policy);

  final LocalDatabase _db;
  final CachePolicy _policy;

  /// 缓存文件元数据。
  Future<void> cacheFile({
    required String id,
    required String fileName,
    required int sizeBytes,
    String? mimeType,
    String? localPath,
  }) async {
    await _db
        .into(_db.cachedFiles)
        .insertOnConflictUpdate(
          CachedFilesCompanion.insert(
            id: id,
            fileName: fileName,
            sizeBytes: sizeBytes,
            mimeType: Value(mimeType),
            localPath: Value(localPath),
            cachedAt: DateTime.now(),
          ),
        );
    await _evictIfNeeded();
  }

  /// 获取缓存的文件元数据。
  Future<CachedFile?> getCachedFile(String id) async {
    final results =
        await (_db.select(_db.cachedFiles)
          ..where((t) => t.id.equals(id))).get();
    if (results.isEmpty) return null;
    // 更新最后访问时间
    await (_db.update(_db.cachedFiles)..where(
      (t) => t.id.equals(id),
    )).write(CachedFilesCompanion(lastAccessedAt: Value(DateTime.now())));
    return results.first;
  }

  /// 删除缓存条目。
  Future<void> removeCachedFile(String id) async {
    await (_db.delete(_db.cachedFiles)..where((t) => t.id.equals(id))).go();
  }

  /// 获取当前缓存总大小（字节）。
  Future<int> currentCacheBytes() async {
    final files = await _db.select(_db.cachedFiles).get();
    return files.fold<int>(0, (sum, f) => sum + f.sizeBytes);
  }

  /// LRU 驱逐：删除最久未访问的条目直到低于限额。
  Future<void> _evictIfNeeded() async {
    final files =
        await (_db.select(_db.cachedFiles)
          ..orderBy([(t) => OrderingTerm.asc(t.lastAccessedAt)])).get();
    int totalBytes = files.fold<int>(0, (sum, f) => sum + f.sizeBytes);
    for (final file in files) {
      if (!_policy.shouldEvict(totalBytes)) break;
      await (_db.delete(_db.cachedFiles)
        ..where((t) => t.id.equals(file.id))).go();
      totalBytes -= file.sizeBytes;
    }
  }
}
