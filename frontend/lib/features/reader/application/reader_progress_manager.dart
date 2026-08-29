import 'package:flutter/foundation.dart';
import 'package:omninest/features/reader/data/reader_api.dart';
import 'package:omninest/features/reader/data/reader_local_storage.dart';
import 'package:omninest/features/reader/domain/reader_progress.dart';
import 'package:omninest/features/reader/reader_debug_log.dart';

/// 阅读进度管理器
///
/// 采用 Local-First 策略：先写本地 SQLite，再异步同步到服务端。
/// 本地写入始终成功，服务端同步失败不影响本地数据，
/// 下次保存或应用重启时会重试同步。
class ReaderProgressManager {
  ReaderProgressManager({
    required ReaderApi api,
    required ReaderLocalStorage localStorage,
  }) : _api = api,
       _localStorage = localStorage;

  final ReaderApi _api;
  final ReaderLocalStorage _localStorage;

  /// 保存阅读进度
  ///
  /// 1. 立即写入本地 SQLite（始终成功）
  /// 2. 异步同步到服务端（失败不阻塞）
  ///
  /// 每次翻页都会调用，不做 debounce。
  Future<void> saveProgress({
    required String itemId,
    required int charOffset,
    required double progressPercent,
    required String readingMode,
    String? chapterId,
  }) async {
    final progress = ReaderProgress(
      readerItemId: itemId,
      charOffset: charOffset,
      progressPercent: progressPercent,
      readingMode: readingMode,
      chapterId: chapterId,
      updatedAt: DateTime.now(),
    );

    // 本地写入优先
    await _localStorage.saveProgress(progress);

    // 异步同步到服务端
    try {
      await _api.updateProgress(
        itemId: itemId,
        charOffset: charOffset,
        progressPercent: progressPercent,
        readingMode: readingMode,
        chapterId: chapterId,
      );
    } on Exception catch (e) {
      // 服务端同步失败，本地已保存
      // 下次保存或应用重启时会重试
      if (kDebugMode) {
        readerDebugLog('ReaderProgressManager: 服务端同步失败: $e');
      }
    }
  }

  /// 加载阅读进度
  ///
  /// 本地优先，同时尝试从服务端获取。
  /// 取 updatedAt 更新的一方，确保跨设备同步。
  Future<ReaderProgress?> loadProgress(String itemId) async {
    final local = await _localStorage.loadProgress(itemId);

    // 尝试从服务端获取进度
    try {
      final detail = await _api.detail(itemId);
      final serverProgress = detail.progress;
      if (serverProgress != null) {
        final server = ReaderProgress(
          readerItemId: itemId,
          charOffset: serverProgress.charOffset,
          progressPercent: serverProgress.progressPercent,
          readingMode: serverProgress.readingMode,
          updatedAt: serverProgress.updatedAt,
        );

        // 本地无数据 → 用服务端
        if (local == null) {
          await _localStorage.saveProgress(server);
          return server;
        }

        // 比较 updatedAt，取更新的一方
        if (server.updatedAt != null && local.updatedAt != null) {
          if (server.updatedAt!.isAfter(local.updatedAt!)) {
            await _localStorage.saveProgress(server);
            return server;
          }
        }
      }
    } on Exception {
      // 服务端不可用，使用本地数据
    }

    return local;
  }

  /// 删除本地进度缓存
  Future<void> clearProgress(String itemId) async {
    await _localStorage.deleteProgress(itemId);
  }

  /// 获取所有本地缓存的进度
  ///
  /// 用于应用启动时批量同步到服务端。
  Future<List<ReaderProgress>> allLocalProgress() async {
    return _localStorage.allProgress();
  }
}
