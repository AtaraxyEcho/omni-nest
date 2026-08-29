import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/features/reader/data/reader_content_preprocessor.dart';
import 'package:omninest/features/reader/data/reader_image_cache.dart';
import 'package:omninest/features/reader/data/reader_image_repository_base.dart';

void main() {
  setUp(() {
    ReaderImageCache.init(const DisabledReaderImageRepository());
  });

  test('章节图片超过 100 张时停止归档展开', () async {
    final archive = Archive();
    final html = StringBuffer('<body>');
    for (var index = 0; index <= 100; index++) {
      final path = 'images/$index.png';
      final bytes = utf8.encode('image-$index');
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
      html.write('<img src="../$path">');
    }
    html.write('</body>');

    await expectLater(
      ReaderContentPreprocessor.preprocessForStorage(
        itemId: 'item-1',
        xhtml: html.toString(),
        archive: archive,
        contentPath: 'text/chapter.xhtml',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('内嵌 Base64 图片写入缓存并保留轻量占位符', () async {
    final repository = _MemoryReaderImageRepository();
    ReaderImageCache.init(repository);
    final encoded = base64Encode(<int>[0x89, 0x50, 0x4e, 0x47]);

    final html = await ReaderContentPreprocessor.preprocessForStorage(
      itemId: 'item-inline',
      xhtml: '<body><img src="data:image/png;base64,$encoded"></body>',
      contentPath: 'text/chapter.xhtml',
      archive: Archive(),
    );

    expect(html, contains('src="__IMG_inline/'));
    expect(html, isNot(contains('data:image/png;base64')));
    expect(repository.images.values.single, <int>[0x89, 0x50, 0x4e, 0x47]);
  });
}

class _MemoryReaderImageRepository implements ReaderImageRepository {
  final Map<String, Uint8List> images = {};

  @override
  Future<void> saveImage({
    required String itemId,
    required String imagePath,
    required Uint8List bytes,
    String mimeType = 'image/png',
  }) async {
    images['$itemId:$imagePath'] = bytes;
  }

  @override
  Future<Uint8List?> loadImage({
    required String itemId,
    required String imagePath,
  }) async => images['$itemId:$imagePath'];

  @override
  Future<void> deleteForItem(String itemId) async {
    images.removeWhere((key, _) => key.startsWith('$itemId:'));
  }

  @override
  Future<void> cleanOld({int maxAgeDays = 30}) async {}

  @override
  Future<void> clearAll() async => images.clear();
}
