import 'dart:typed_data';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// 通过浏览器原生下载能力保存 CSV，返回文件名。
Future<String?> saveAdminCsvBytes({
  required String suggestedName,
  required Uint8List bytes,
}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor =
      web.HTMLAnchorElement()
        ..href = url
        ..download = suggestedName
        ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return suggestedName;
}
