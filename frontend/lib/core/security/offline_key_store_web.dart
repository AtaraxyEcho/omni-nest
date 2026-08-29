import 'package:omninest/core/security/offline_crypto.dart';
import 'package:omninest/core/security/offline_key_store_base.dart';

/// 创建 Web 会话级离线主密钥存储。
OfflineKeyStore createOfflineKeyStore() {
  return _sharedStore;
}

final MemoryOfflineKeyStore _sharedStore = MemoryOfflineKeyStore();

/// Web 端只在页面会话内保存离线主密钥。
class MemoryOfflineKeyStore implements OfflineKeyStore {
  MemoryOfflineKeyStore({OfflineCrypto crypto = const OfflineCrypto()})
    : _crypto = crypto;

  final OfflineCrypto _crypto;
  final Map<String, OfflineMasterKey> _keys = <String, OfflineMasterKey>{};

  @override
  Future<OfflineMasterKey> readOrCreate(String userId) async {
    return _keys.putIfAbsent(
      userId,
      () => OfflineMasterKey(keyId: 'session-v1', bytes: _crypto.generateKey()),
    );
  }

  @override
  Future<void> delete(String userId) async {
    _keys.remove(userId);
  }
}
