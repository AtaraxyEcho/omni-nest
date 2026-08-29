import 'package:omninest/core/security/offline_key_store_base.dart';
import 'package:omninest/core/security/offline_key_store_web.dart';

/// 创建不支持平台安全存储时的内存密钥存储。
OfflineKeyStore createOfflineKeyStore() {
  return MemoryOfflineKeyStore();
}
