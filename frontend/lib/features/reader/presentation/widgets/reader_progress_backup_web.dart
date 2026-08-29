import 'dart:convert';
import 'package:web/web.dart' as web;

/// Web 平台 localStorage 备份（同步 API）。
class ReaderProgressBackupWeb {
  static const _prefix = 'omninest_progress_';

  static void save({
    required String itemId,
    required String chapterId,
    required int charOffset,
    required double chapterProgress,
  }) {
    try {
      final key = '$_prefix$itemId';
      final data = jsonEncode({
        'chapterId': chapterId,
        'charOffset': charOffset,
        'chapterProgress': chapterProgress,
        'savedAt': DateTime.now().toIso8601String(),
      });
      web.window.localStorage.setItem(key, data);
    } on Exception catch (_) {}
  }

  static Map<String, dynamic>? load(String itemId) {
    try {
      final key = '$_prefix$itemId';
      final data = web.window.localStorage.getItem(key);
      if (data == null || data.isEmpty) return null;
      return jsonDecode(data) as Map<String, dynamic>;
    } on Exception catch (_) {
      return null;
    }
  }

  static void clear(String itemId) {
    try {
      web.window.localStorage.removeItem('$_prefix$itemId');
    } on Exception catch (_) {}
  }
}
