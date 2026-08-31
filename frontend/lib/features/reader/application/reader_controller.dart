import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/providers.dart';
import 'package:omninest/core/errors/error_message.dart';
import 'package:omninest/core/storage/local_database_provider.dart';
import 'package:omninest/features/reader/application/reader_cache_providers.dart';
import 'package:omninest/features/reader/application/reader_data_manager.dart';
import 'package:omninest/features/reader/application/reader_parsed_book_cache.dart';
import 'package:omninest/features/reader/data/reader_sync_queue.dart';
import 'package:omninest/features/reader/data/reader_api.dart';
import 'package:omninest/features/reader/data/reader_image_cache.dart';
import 'package:omninest/features/reader/data/reader_local_storage.dart';
import 'package:omninest/features/reader/domain/reader_models.dart';
import 'package:omninest/features/tasks/application/task_controller.dart';
import 'package:omninest/features/tasks/domain/task_record.dart';

// ─── Providers ──────────────────────────────────────────────────

/// 阅读器 API 客户端
final readerApiProvider = Provider<ReaderApi>((ref) {
  return ReaderApi(ref.watch(apiClientProvider));
});

/// 阅读器本地存储（共享 LocalDatabase 单例）
final readerLocalStorageProvider = Provider<ReaderLocalStorage>((ref) {
  return ReaderLocalStorage(ref.watch(localDatabaseProvider));
});

/// 阅读器数据管理器（离线优先写入）
final readerDataManagerProvider = Provider<ReaderDataManager>((ref) {
  return ReaderDataManager(
    api: ref.read(readerApiProvider),
    localStorage: ref.read(readerLocalStorageProvider),
  );
});

/// 仪表盘数据
final readerDashboardProvider = FutureProvider<ReaderDashboard>((ref) async {
  return ref.watch(readerApiProvider).dashboard();
});

/// 条目详情（含进度）
final readerItemDetailProvider = FutureProvider.autoDispose
    .family<ReaderItemDetail, String>((ref, itemId) {
      return ref.watch(readerApiProvider).detail(itemId);
    });

/// 阅读统计
final readerStatsProvider = FutureProvider<ReaderReadingStats>((ref) async {
  return ref.watch(readerApiProvider).getStats();
});

/// 阅读中心控制器
final readerCenterControllerProvider =
    AsyncNotifierProvider<ReaderCenterController, ReaderCenterState>(
      ReaderCenterController.new,
    );

// ─── Bookshelf Toggle Result ────────────────────────────────────

/// 书架切换操作结果
class BookshelfToggleResult {
  const BookshelfToggleResult({required this.addedToBookshelf});

  final bool addedToBookshelf;
}

// ─── State ──────────────────────────────────────────────────────

/// 阅读中心页面状态
class ReaderCenterState {
  const ReaderCenterState({
    required this.dashboard,
    required this.items,
    required this.section,
    required this.searchQuery,
    required this.bookmarks,
    this.sortBy = ReaderSortBy.recent,
    this.librarySegment = ReaderLibrarySegment.all,
    this.errorMessage,
  });

  /// 空状态工厂
  factory ReaderCenterState.empty() => ReaderCenterState(
    dashboard: ReaderDashboard.empty(),
    items: const [],
    section: ReaderSection.bookshelf,
    searchQuery: '',
    bookmarks: const [],
  );

  final ReaderDashboard dashboard;
  final List<ReaderItem> items;
  final ReaderSection section;
  final String searchQuery;
  final ReaderSortBy sortBy;
  final List<ReaderBookmark> bookmarks;
  final ReaderLibrarySegment librarySegment;
  final String? errorMessage;

  /// 继续阅读列表（来自仪表盘）
  List<ReaderItem> get continueItems => dashboard.continueReading;

  /// 当前分区是否展示书架网格
  bool get canShowShelf => switch (section) {
    ReaderSection.bookshelf ||
    ReaderSection.books ||
    ReaderSection.comics ||
    ReaderSection.history => true,
    ReaderSection.bookmarks ||
    ReaderSection.notes ||
    ReaderSection.imports ||
    ReaderSection.metadata => false,
  };

  /// 经过分区过滤 + 分段过滤 + 排序 + 搜索后的可见条目
  List<ReaderItem> get visibleItems {
    // 按分区过滤
    var source = switch (section) {
      // 书架：仅显示已加入书架的条目（个人 + 共享）
      ReaderSection.bookshelf =>
        items.where((i) => i.addedToBookshelf).toList(),
      // 书库：显示所有条目（由 librarySegment 二次过滤）
      ReaderSection.books => items,
      ReaderSection.notes => items,
      _ => items,
    };

    // 书库分段过滤（移动端书库内的 全部/图书/漫画 切换）
    if (section == ReaderSection.books) {
      source = switch (librarySegment) {
        ReaderLibrarySegment.all => source,
        ReaderLibrarySegment.books => source.where((i) => !i.isComic).toList(),
        ReaderLibrarySegment.comics => source.where((i) => i.isComic).toList(),
      };
    }

    // 排序
    final sorted = switch (sortBy) {
      ReaderSortBy.recent => source,
      ReaderSortBy.title => [...source]
        ..sort((a, b) => a.title.compareTo(b.title)),
    };

    // 搜索过滤
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return sorted;
    return sorted
        .where(
          (i) =>
              i.title.toLowerCase().contains(query) ||
              (i.authorName?.toLowerCase().contains(query) ?? false),
        )
        .toList();
  }

  /// 复制状态
  ReaderCenterState copyWith({
    ReaderDashboard? dashboard,
    List<ReaderItem>? items,
    ReaderSection? section,
    String? searchQuery,
    ReaderSortBy? sortBy,
    List<ReaderBookmark>? bookmarks,
    ReaderLibrarySegment? librarySegment,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReaderCenterState(
      dashboard: dashboard ?? this.dashboard,
      items: items ?? this.items,
      section: section ?? this.section,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      bookmarks: bookmarks ?? this.bookmarks,
      librarySegment: librarySegment ?? this.librarySegment,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ─── Controller ─────────────────────────────────────────────────

/// 阅读中心控制器
class ReaderCenterController extends AsyncNotifier<ReaderCenterState> {
  ReaderApi get _api => ref.read(readerApiProvider);

  @override
  Future<ReaderCenterState> build() async {
    return _loadState();
  }

  /// 加载全部数据，部分失败不阻塞整体
  Future<ReaderCenterState> _loadState({
    ReaderSection section = ReaderSection.bookshelf,
    String searchQuery = '',
    ReaderSortBy sortBy = ReaderSortBy.recent,
    bool loadBookmarks = true,
  }) async {
    // 错误随本次加载局部收集，实例字段会被并发 refresh 互相污染
    final partialErrors = <String>[];
    final results = await Future.wait([
      _safe(_api.dashboard, ReaderDashboard.empty(), partialErrors),
      _safe(() => _api.items(), <ReaderItem>[], partialErrors),
    ]);
    final dashboard = results[0] as ReaderDashboard;
    final items = results[1] as List<ReaderItem>;

    // 书签按条目加载（API 仅支持单条目查询）；实时刷新复用现有列表
    final bookmarks =
        loadBookmarks
            ? await _loadAllBookmarks(items, partialErrors)
            : state.asData?.value.bookmarks ?? const <ReaderBookmark>[];

    return ReaderCenterState(
      dashboard: dashboard,
      items: items,
      section: section,
      searchQuery: searchQuery,
      sortBy: sortBy,
      bookmarks: bookmarks,
      errorMessage: partialErrors.isEmpty ? null : partialErrors.join('；'),
    );
  }

  /// 批量加载所有条目的书签
  Future<List<ReaderBookmark>> _loadAllBookmarks(
    List<ReaderItem> items,
    List<String> partialErrors,
  ) async {
    if (items.isEmpty) return const [];
    final futures = items.map(
      (item) => _safe(
        () => _api.bookmarks(item.id),
        <ReaderBookmark>[],
        partialErrors,
      ),
    );
    final results = await Future.wait(futures);
    return results.expand((list) => list).toList();
  }

  /// 安全执行异步调用，失败时记录到调用方传入的错误列表并返回 fallback
  Future<T> _safe<T>(
    Future<T> Function() call,
    T fallback,
    List<String> partialErrors,
  ) async {
    try {
      return await call();
    } on Exception catch (e) {
      partialErrors.add(describeUserFacingError(e).message);
      return fallback;
    }
  }

  /// 设置错误消息
  void _setError(String message) {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(current.copyWith(errorMessage: message));
    }
  }

  /// 清除错误消息
  void clearError() {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(current.copyWith(clearError: true));
    }
  }

  /// 刷新全部数据
  Future<void> refresh() async {
    await _refreshState(strict: false, loadBookmarks: true);
  }

  /// 严格刷新实时事件涉及的阅读数据并保留当前分区与筛选。
  ///
  /// 由导入监控循环周期调用；书签不会因解析变化，复用现有列表，
  /// 避免每轮触发按条目的书签 N+1 请求风暴。
  Future<void> refreshForRealtime() async {
    await _refreshState(strict: true, loadBookmarks: false);
  }

  Future<void> _refreshState({
    required bool strict,
    bool loadBookmarks = true,
  }) async {
    final current = state.asData?.value;
    final next = await _loadState(
      section: current?.section ?? ReaderSection.bookshelf,
      searchQuery: current?.searchQuery ?? '',
      sortBy: current?.sortBy ?? ReaderSortBy.recent,
      loadBookmarks: loadBookmarks,
    );
    if (strict && next.errorMessage != null) {
      throw StateError(next.errorMessage!);
    }
    // 保留分段状态
    state = AsyncData(
      next.copyWith(
        librarySegment: current?.librarySegment ?? ReaderLibrarySegment.all,
      ),
    );
  }

  /// 切换分区
  void selectSection(ReaderSection section) {
    final current = state.asData?.value;
    if (current == null) return;
    // 漫画归一化：comics 统一映射为 books + comics 分段
    // 这样移动端和桌面端数据流一致，visibleItems 由 section + librarySegment 共同决定
    final normalizedSection =
        section == ReaderSection.comics ? ReaderSection.books : section;
    final segment =
        section == ReaderSection.comics
            ? ReaderLibrarySegment.comics
            : (section == ReaderSection.books
                ? current.librarySegment
                : ReaderLibrarySegment.all);
    state = AsyncData(
      current.copyWith(
        section: normalizedSection,
        librarySegment: segment,
        searchQuery: '',
      ),
    );
  }

  /// 切换书库分段（全部/图书/漫画）
  void selectLibrarySegment(ReaderLibrarySegment segment) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(librarySegment: segment));
  }

  /// 设置搜索关键词
  void setSearchQuery(String query) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(searchQuery: query));
  }

  /// 设置排序方式
  void setSortBy(ReaderSortBy sortBy) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(sortBy: sortBy));
  }

  /// 删除阅读条目
  Future<TaskSubmission> deleteItem(
    String itemId, {
    bool cascade = false,
  }) async {
    try {
      final submission = await _api.deleteItem(itemId, cascade: cascade);
      final current = state.asData?.value;
      if (current != null) {
        state = AsyncData(
          current.copyWith(
            items: current.items.where((i) => i.id != itemId).toList(),
            bookmarks:
                current.bookmarks
                    .where((b) => b.readerItemId != itemId)
                    .toList(),
          ),
        );
      }
      ref.invalidate(activeTaskSummaryProvider);
      unawaited(ref.read(taskListProvider.notifier).load());
      unawaited(_cleanupDeletedItemAfterCompletion(itemId, submission.taskId));
      return submission;
    } on Exception catch (e) {
      _setError(describeUserFacingError(e).message);
      rethrow;
    }
  }

  Future<void> _cleanupDeletedItemAfterCompletion(
    String itemId,
    String taskId,
  ) async {
    try {
      final task = await ref.read(taskApiProvider).waitForTerminal(taskId);
      ref.invalidate(activeTaskSummaryProvider);
      unawaited(ref.read(taskListProvider.notifier).load());
      if (!task.isCompleted) {
        _setError(task.errorMessage ?? '阅读条目删除任务未完成');
        await _restoreItemAfterFailedDelete();
        return;
      }
      await Future.wait([
        ref.read(readerLocalStorageProvider).deleteAllForItem(itemId),
        ref.read(localBookCacheProvider).removeCache(itemId),
        ReaderImageCache.deleteForItem(itemId),
      ]);
      ref.read(readerParsedBookCacheProvider).remove(itemId);
      ref.invalidate(readerItemDetailProvider(itemId));
    } on Exception catch (error) {
      _setError(describeUserFacingError(error).message);
      await _restoreItemAfterFailedDelete();
    }
  }

  /// 删除任务失败或等待超时时，恢复被乐观移除的条目。
  /// 后端删除失败则条目仍存在，重新加载列表即可回滚本地移除。
  Future<void> _restoreItemAfterFailedDelete() async {
    try {
      await refresh();
    } on Exception catch (error) {
      _setError(describeUserFacingError(error).message);
    }
  }

  /// 切换书架状态
  ///
  /// 调用 API 切换后刷新仪表盘以同步书架数据。
  Future<BookshelfToggleResult> toggleBookshelf(String itemId) async {
    try {
      await _api.toggleBookshelf(itemId);
      // 刷新仪表盘以获取最新的书架数据
      final dashboard = await _api.dashboard();
      final current = state.asData?.value;
      if (current != null) {
        state = AsyncData(current.copyWith(dashboard: dashboard));
      }
      // 判断是否在书架中：如果仪表盘的继续阅读包含该条目，则认为已加入书架
      final addedToBookshelf = dashboard.continueReading.any(
        (i) => i.id == itemId,
      );
      // 也检查最近条目（书架可能包含未开始阅读的书）
      final inRecent = dashboard.recentItems.any((i) => i.id == itemId);
      return BookshelfToggleResult(
        addedToBookshelf: addedToBookshelf || inRecent,
      );
    } on Exception catch (e) {
      _setError(describeUserFacingError(e).message);
      rethrow;
    }
  }

  // ─── 导入与元数据操作 ────────────────────────────────────────

  /// 导入文件到阅读器
  Future<ReaderItem> importFile({
    required String fileNodeId,
    bool force = false,
    String? contentKindOverride,
  }) async {
    try {
      final item = await _api.importFile(
        fileNodeId: fileNodeId,
        force: force,
        contentKindOverride: contentKindOverride,
      );
      await refresh();
      return item;
    } on Exception catch (e) {
      _setError(describeUserFacingError(e).displayMessage);
      rethrow;
    }
  }

  /// 取消解析中的阅读条目并刷新书库状态。
  Future<void> cancelImport(String itemId) async {
    try {
      await _api.cancelImport(itemId);
      await refresh();
    } on Exception catch (error) {
      _setError(describeUserFacingError(error).displayMessage);
      rethrow;
    }
  }

  /// 重新解析阅读条目。
  Future<ReaderItem> reparseItem(String itemId) async {
    try {
      final item = await _api.reparseItem(itemId);
      await refresh();
      return item;
    } on Exception catch (e) {
      _setError(describeUserFacingError(e).displayMessage);
      rethrow;
    }
  }

  /// 更新条目元数据
  Future<void> updateItemMetadata({
    required String itemId,
    required Map<String, dynamic> fields,
  }) async {
    try {
      await _api.updateItemMetadata(itemId: itemId, fields: fields);
      await refresh();
    } on Exception catch (e) {
      _setError(describeUserFacingError(e).displayMessage);
      rethrow;
    }
  }

  /// 获取导入候选文件列表
  Future<List<ReaderImportCandidate>> importCandidates() async {
    try {
      return await _api.importCandidates();
    } on Exception catch (e) {
      _setError(describeUserFacingError(e).displayMessage);
      rethrow;
    }
  }

  /// 等待文件索引完成并返回与文件名对应的导入候选项。
  ///
  /// 导入后的文件节点可能在上传事务提交后才出现在候选列表中。轮询属于
  /// application 层流程，页面销毁不会让 Widget 再持有或访问无效的 ref。
  Future<ReaderImportCandidate?> waitForImportCandidate(
    String fileName, {
    int maxAttempts = 24,
    Duration interval = const Duration(milliseconds: 500),
  }) async {
    final api = _api;
    Object? lastError;
    var hasSuccessfulQuery = false;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await Future<void>.delayed(interval);
      try {
        final candidates = await api.importCandidates();
        hasSuccessfulQuery = true;
        for (final candidate in candidates) {
          if (candidate.fileName == fileName) {
            return candidate;
          }
        }
      } on Exception catch (error) {
        // 候选列表在上传索引完成前短暂不可用时，继续在限定时间内查询。
        lastError = error;
      }
    }
    if (!hasSuccessfulQuery && lastError != null) {
      _setError(describeUserFacingError(lastError).displayMessage);
      throw lastError;
    }
    return null;
  }

  /// 重放离线队列后加载阅读统计。
  Future<ReaderReadingStats> syncAndLoadStats() async {
    await ReaderSyncQueue.retryFailed();
    await ReaderSyncQueue.flush(api: _api);
    return _api.getStats();
  }

  /// 使用文件节点设置条目封面。
  Future<void> setCoverFromFile({
    required String itemId,
    required String fileNodeId,
  }) {
    return _api.setCoverFromFile(itemId: itemId, fileNodeId: fileNodeId);
  }

  /// 上传条目封面。
  Future<void> uploadCover({
    required String itemId,
    required Uint8List imageBytes,
    required String fileName,
  }) {
    return _api.uploadCover(
      itemId: itemId,
      imageBytes: imageBytes,
      fileName: fileName,
    );
  }
}
