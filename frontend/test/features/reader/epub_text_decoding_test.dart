import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:omninest/features/reader/data/epub_parser_service.dart';

void main() {
  test('GBK 声明的 EPUB 条目按 GBK 解码而非静默失败', () {
    final xhtml =
        '<?xml version="1.0" encoding="gbk"?>'
        '<html><body><p>第一章 中文内容测试</p></body></html>';
    final bytes = gbk.encode(xhtml);

    final decoded = decodeEpubText(bytes);

    expect(decoded, contains('第一章 中文内容测试'));
  });

  test('UTF-8 条目正常解码且容忍坏字节', () {
    final xhtml =
        '<?xml version="1.0" encoding="utf-8"?><html><body>ok</body></html>';
    final bytes = <int>[...utf8.encode(xhtml), 0xFF];

    final decoded = decodeEpubText(bytes);

    expect(decoded, contains('<body>ok</body>'));
  });
}
