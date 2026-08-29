import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:omninest/features/reader/application/reader_sync_queue.dart';
import 'package:omninest/features/reader/reader_debug_log.dart';

/// 阅读会话记录工具。
///
/// 记录阅读时长，先写入统一同步队列，再由后台刷新同步后端。
/// 从 reader_view_page.dart 提取。
class ReaderSessionRecorder {
  ReaderSessionRecorder._();

  /// 记录阅读会话。
  ///
  /// 会话只进入 ReaderSyncQueue，避免 SharedPreferences 与同步队列双写。
  static void recordSession({
    required String itemId,
    required DateTime sessionStart,
  }) {
    final now = DateTime.now();
    final duration = now.difference(sessionStart).inSeconds;
    if (duration < 10) return;

    final clientSessionId =
        '$itemId-${sessionStart.toUtc().microsecondsSinceEpoch}-${now.toUtc().microsecondsSinceEpoch}';
    unawaited(
      _enqueueSession(
        clientSessionId: clientSessionId,
        itemId: itemId,
        startedAt: sessionStart.toUtc().toIso8601String(),
        endedAt: now.toUtc().toIso8601String(),
        durationSeconds: duration,
      ),
    );
  }

  static Future<void> _enqueueSession({
    required String clientSessionId,
    required String itemId,
    required String startedAt,
    required String endedAt,
    required int durationSeconds,
  }) async {
    try {
      await ReaderSyncQueue.enqueueSessionCreate(
        clientSessionId: clientSessionId,
        itemId: itemId,
        startedAt: startedAt,
        endedAt: endedAt,
        durationSeconds: durationSeconds,
      );
    } on Exception catch (e) {
      if (kDebugMode) {
        readerDebugLog('ReaderSessionRecorder: session enqueue failed: $e');
      }
    }
  }
}
