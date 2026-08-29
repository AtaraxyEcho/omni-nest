import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/core/security/encrypted_file_vault.dart';
import 'package:omninest/core/security/offline_key_store_base.dart';
import 'package:omninest/features/reader/data/local_book_cache.dart';

void main() {
  test('原生阅读缓存按需生成会话明文并在关闭后删除', () async {
    final directory = await Directory.systemTemp.createTemp(
      'local-book-cache-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final plaintext = Uint8List.fromList(
      List<int>.generate(9500, (index) => index % 251),
    );
    final staleSession = File(
      '${directory.path}/stale.onf.plain.session.abandoned',
    );
    await staleSession.writeAsBytes(<int>[9]);
    final cache = LocalBookCache(
      userId: 'user-1',
      vault: EncryptedFileVault(
        keyStore: _FixedOfflineKeyStore(),
        chunkSize: 4096,
      ),
      cacheDirectoryResolver: (_) async => directory,
    );

    final handle = await cache.ensureCachedHandle(
      'item-1',
      nativeDownloader: (path) => File(path).writeAsBytes(plaintext),
    );
    final filesBeforeOpen = await directory.list().toList();
    expect(filesBeforeOpen.whereType<File>(), hasLength(1));
    expect(filesBeforeOpen.single.path, endsWith('.onf'));
    expect(await staleSession.exists(), isFalse);

    final sessionPath = await handle.openFilePath();
    final secondHandle = await cache.ensureCachedHandle('item-1');
    final secondSessionPath = await secondHandle.openFilePath();
    expect(sessionPath, isNotNull);
    expect(secondSessionPath, isNot(sessionPath));
    expect(await File(sessionPath!).readAsBytes(), plaintext);
    expect(sessionPath, contains('.plain.session.'));

    await handle.close();

    expect(await File(sessionPath).exists(), isFalse);
    expect(await File(secondSessionPath!).exists(), isTrue);
    await secondHandle.close();
    expect(await File(secondSessionPath).exists(), isFalse);
    expect(await cache.isCached('item-1'), isTrue);
  });
}

class _FixedOfflineKeyStore implements OfflineKeyStore {
  final Uint8List _key = Uint8List.fromList(
    List<int>.generate(32, (index) => index),
  );

  @override
  Future<OfflineMasterKey> readOrCreate(String userId) async {
    return OfflineMasterKey(keyId: 'master-v1', bytes: _key);
  }

  @override
  Future<void> delete(String userId) async {}
}
