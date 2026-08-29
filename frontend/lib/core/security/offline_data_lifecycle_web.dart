import 'package:omninest/core/security/offline_data_lifecycle_base.dart';
import 'package:omninest/core/security/offline_key_store.dart';
import 'package:omninest/core/security/offline_memory_cache.dart';

/// Web 平台没有需要迁移的持久化明文缓存。
Future<void> initializeOfflineDataLifecycle() async {}

/// 创建 Web 会话级离线敏感数据生命周期实现。
OfflineDataLifecycle createOfflineDataLifecycle() {
  return WebOfflineDataLifecycle(keyStore: createOfflineKeyStore());
}

/// 清理 Web 会话级主密钥。
class WebOfflineDataLifecycle implements OfflineDataLifecycle {
  WebOfflineDataLifecycle({required OfflineKeyStore keyStore})
    : _keyStore = keyStore;

  final OfflineKeyStore _keyStore;

  @override
  Future<void> clearUser(String userId) async {
    OfflineMemoryCache.clearUser(userId);
    await _keyStore.delete(userId);
  }
}
