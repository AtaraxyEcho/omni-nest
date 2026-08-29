import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:omninest/features/video/presentation/widgets/subtitle_file_decoder.dart';

void main() {
  test('解码 UTF-8 BOM 字幕', () {
    final bytes = Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode('字幕内容'),
    ]);

    expect(decodeSubtitleFile(bytes), '字幕内容');
  });

  test('解码 GBK 字幕', () {
    final bytes = Uint8List.fromList(gbk_bytes.encode('中文字幕'));

    expect(decodeSubtitleFile(bytes), '中文字幕');
  });

  test('从文件名推断字幕语言', () {
    expect(inferSubtitleLanguage('movie.zh.srt'), 'chi');
    expect(inferSubtitleLanguage('movie.en.ass'), 'eng');
    expect(inferSubtitleLanguage('movie.srt'), 'und');
  });
}
