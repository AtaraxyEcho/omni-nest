import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/features/files/application/file_browser_controller.dart';

/// 缓存 presigned download URL，按文件 ID 在会话内复用。
/// 文件夹或获取失败时返回 null。
final fileDownloadUrlProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, fileId) async {
      final repository = ref.read(fileRepositoryProvider);
      try {
        return await repository.downloadUrl(fileId);
      } catch (_) {
        return null;
      }
    });

/// 按文件 ID 加载有界文本预览。
final fileTextPreviewProvider = FutureProvider.autoDispose
    .family<String, String>((ref, fileId) async {
      return ref.read(fileRepositoryProvider).loadTextPreview(fileId);
    });
