import 'package:archive/archive.dart';

/// EPUB 归档文件源。
abstract interface class EpubArchiveSource {
  /// 延迟解压的归档目录。
  Archive get archive;

  /// 关闭归档底层文件句柄。
  void close();
}
