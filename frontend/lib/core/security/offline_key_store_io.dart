import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:omninest/core/security/offline_crypto.dart';
import 'package:omninest/core/security/offline_key_store_base.dart';

/// 创建原生平台离线主密钥存储。
OfflineKeyStore createOfflineKeyStore() {
  return SecureOfflineKeyStore();
}

/// 使用系统安全存储保存离线主密钥。
class SecureOfflineKeyStore implements OfflineKeyStore {
  SecureOfflineKeyStore({
    FlutterSecureStorage? secureStorage,
    OfflineCrypto crypto = const OfflineCrypto(),
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _crypto = crypto;

  static const _keyId = 'master-v1';
  static const _storagePrefix = 'omninest.offline.master.v1.';

  final FlutterSecureStorage _secureStorage;
  final OfflineCrypto _crypto;

  @override
  Future<OfflineMasterKey> readOrCreate(String userId) async {
    final storageKey = _storageKey(userId);
    final encoded = await _secureStorage.read(key: storageKey);
    if (encoded != null && encoded.isNotEmpty) {
      final bytes = _decodeKey(encoded);
      if (bytes != null) {
        return OfflineMasterKey(keyId: _keyId, bytes: bytes);
      }
    }

    final bytes = _crypto.generateKey();
    await _secureStorage.write(key: storageKey, value: base64Encode(bytes));
    return OfflineMasterKey(keyId: _keyId, bytes: bytes);
  }

  @override
  Future<void> delete(String userId) {
    return _secureStorage.delete(key: _storageKey(userId));
  }

  Uint8List? _decodeKey(String encoded) {
    try {
      final bytes = base64Decode(encoded);
      return bytes.length == 32 ? Uint8List.fromList(bytes) : null;
    } on FormatException {
      return null;
    }
  }

  String _storageKey(String userId) {
    final userKey = base64UrlEncode(utf8.encode(userId)).replaceAll('=', '');
    return '$_storagePrefix$userKey';
  }
}
