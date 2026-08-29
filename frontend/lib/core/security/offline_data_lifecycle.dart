import 'package:omninest/core/security/offline_memory_cache.dart';
import 'package:omninest/core/storage/local_database.dart';
import 'package:omninest/core/security/offline_data_lifecycle_base.dart';
import 'package:omninest/core/security/offline_data_lifecycle_stub.dart'
    if (dart.library.io) 'package:omninest/core/security/offline_data_lifecycle_io.dart'
    if (dart.library.html) 'package:omninest/core/security/offline_data_lifecycle_web.dart'
    as platform_lifecycle;

export 'package:omninest/core/security/offline_data_lifecycle_base.dart';

/// 初始化当前平台的离线敏感数据生命周期。
Future<void> initializeOfflineDataLifecycle() {
  return platform_lifecycle.initializeOfflineDataLifecycle();
}

/// 创建当前平台的离线敏感数据生命周期实现。
OfflineDataLifecycle createOfflineDataLifecycle({
  required LocalDatabase database,
}) {
  return DatabaseOfflineDataLifecycle(
    delegate: platform_lifecycle.createOfflineDataLifecycle(),
    database: database,
  );
}

/// 统一清理平台文件、内存缓存和本地数据库中的用户数据。
class DatabaseOfflineDataLifecycle implements OfflineDataLifecycle {
  /// 创建数据库感知的离线数据生命周期。
  const DatabaseOfflineDataLifecycle({
    required OfflineDataLifecycle delegate,
    required LocalDatabase database,
  }) : _delegate = delegate,
       _database = database;

  final OfflineDataLifecycle _delegate;
  final LocalDatabase _database;

  @override
  Future<void> clearUser(String userId) async {
    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> runStep(Future<void> Function() action) async {
      try {
        await action();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    await runStep(() => _delegate.clearUser(userId));
    OfflineMemoryCache.clearUser(userId);
    await runStep(() => _database.clearUserData(userId));

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }
}
