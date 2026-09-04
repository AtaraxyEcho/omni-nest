import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/providers.dart';
import 'package:omninest/core/errors/error_message.dart';
import 'package:omninest/features/photos/application/photo_center_models.dart';
import 'package:omninest/features/photos/data/photo_api.dart';
import 'package:omninest/features/photos/data/photo_repository_impl.dart';
import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/domain/photo_album.dart';
import 'package:omninest/features/photos/domain/photo_batch_task.dart';
import 'package:omninest/features/photos/domain/photo_batch_download_ticket.dart';
import 'package:omninest/features/photos/domain/photo_edit_version.dart';
import 'package:omninest/features/photos/domain/photo_group.dart';
import 'package:omninest/features/photos/domain/photo_repository.dart';
import 'package:omninest/features/photos/domain/photo_share_link.dart';
import 'package:omninest/features/photos/domain/photo_timeline.dart';
import 'package:omninest/features/tasks/application/task_controller.dart';
import 'package:omninest/features/tasks/domain/task_record.dart';

export 'package:omninest/features/photos/application/photo_center_models.dart';

part 'photo_controller_commands.dart';

part 'photo_center_providers.dart';

part 'photo_center_collection_loaders.dart';

enum _ImportTaskPollOutcome { completed, failed, pending, unavailable }

// -- 数据 Provider --

final photoListProvider = FutureProvider<PhotoPage>((ref) {
  return ref.watch(photoRepositoryProvider).listPhotos();
});

final photoFavoritesProvider = FutureProvider<PhotoPage>((ref) {
  return ref.watch(photoRepositoryProvider).listFavorites();
});

final photoAlbumsProvider = FutureProvider<List<PhotoAlbum>>((ref) {
  return ref.watch(photoRepositoryProvider).listAlbums();
});

final photoDetailProvider = FutureProvider.autoDispose
    .family<PhotoItem, String>((ref, photoId) {
      return ref.watch(photoRepositoryProvider).getPhoto(photoId);
    });

final photoAlbumDetailProvider = FutureProvider.autoDispose
    .family<PhotoAlbumDetail, String>((ref, albumId) {
      return ref.watch(photoRepositoryProvider).getAlbumDetail(albumId);
    });

/// 照片中心控制器
class PhotoCenterController extends AsyncNotifier<PhotoCenterState>
    with PhotoCenterControllerCommands, PhotoCenterCollectionLoaders {
  @override
  PhotoRepository get _repo => ref.read(photoRepositoryProvider);
  Timer? _searchDebounce;
  int _importRefreshEpoch = 0;
  int _refreshGeneration = 0;
  Future<bool>? _importRefreshInFlight;
  Future<void>? _realtimeRefreshInFlight;
  PhotoImportNotice? _lastImportNotice;
  String? _lastImportDetail;

  /// 最近一次导入后台任务的终态错误，供导入入口显示准确反馈。
  PhotoImportNotice? get lastImportNotice => _lastImportNotice;

  /// 后端任务返回的自定义错误信息（如安全隔离提示），仅 backendFailed 时有值。
  String? get lastImportDetail => _lastImportDetail;

  @override
  Future<PhotoCenterState> build() async {
    ref.onDispose(() {
      _searchDebounce?.cancel();
      _importRefreshEpoch++;
      _refreshGeneration++;
      _importRefreshInFlight = null;
      _realtimeRefreshInFlight = null;
    });
    return _loadState();
  }

  Future<PhotoCenterState> _loadState() async {
    final partialErrors = <String>[];
    final results = await Future.wait([
      _safe(_repo.dashboard, PhotoDashboard.empty(), partialErrors),
      _safe(_repo.listPhotos, PhotoPage.empty(), partialErrors),
      _safe(_repo.listFavorites, PhotoPage.empty(), partialErrors),
      _safe(_repo.listAlbums, <PhotoAlbum>[], partialErrors),
    ]);
    final photoPage = results[1] as PhotoPage;
    final favoritePage = results[2] as PhotoPage;
    return PhotoCenterState(
      dashboard: results[0] as PhotoDashboard,
      photos: photoPage.items,
      favorites: favoritePage.items,
      albums: results[3] as List<PhotoAlbum>,
      tab: PhotoTab.all,
      searchQuery: '',
      photoPage: photoPage.page,
      favoritePage: favoritePage.page,
      photoTotalElements: photoPage.totalElements,
      favoriteTotalElements: favoritePage.totalElements,
      errorMessage: partialErrors.isEmpty ? null : partialErrors.join('；'),
    );
  }

  /// 刷新全部数据
  @override
  Future<void> refresh() async {
    _importRefreshEpoch++;
    final generation = ++_refreshGeneration;
    final current = state.asData?.value ?? PhotoCenterState.empty();
    final partialErrors = <String>[];
    final results = await Future.wait([
      _safe(_repo.dashboard, PhotoDashboard.empty(), partialErrors),
      _safe(
        () => _repo.listPhotos(
          query: current.tab == PhotoTab.all ? current.searchQuery : null,
        ),
        PhotoPage.empty(),
        partialErrors,
      ),
      _safe(
        () => _repo.listFavorites(
          query: current.tab == PhotoTab.favorites ? current.searchQuery : null,
        ),
        PhotoPage.empty(),
        partialErrors,
      ),
      _safe(_repo.listAlbums, <PhotoAlbum>[], partialErrors),
    ]);
    final photoPage = results[1] as PhotoPage;
    final favoritePage = results[2] as PhotoPage;
    if (!ref.mounted || generation != _refreshGeneration) return;
    state = AsyncData(
      current.copyWith(
        dashboard: results[0] as PhotoDashboard,
        photos: photoPage.items,
        favorites: favoritePage.items,
        albums: results[3] as List<PhotoAlbum>,
        photoPage: photoPage.page,
        favoritePage: favoritePage.page,
        photoTotalElements: photoPage.totalElements,
        favoriteTotalElements: favoritePage.totalElements,
        photoRefreshVersion: current.photoRefreshVersion + 1,
        favoriteRefreshVersion: current.favoriteRefreshVersion + 1,
        clearPhotoPageError: true,
        clearFavoritePageError: true,
        errorMessage: partialErrors.isEmpty ? null : partialErrors.join('；'),
      ),
    );
  }

  /// 上传完成后立即刷新，并在异步自动导入尚未完成时执行有限补查。
  Future<bool> refreshAfterImport({
    Iterable<String> expectedFileIds = const <String>[],
    Iterable<String> taskIds = const <String>[],
  }) {
    final active = _importRefreshInFlight;
    if (active != null) return active;
    _lastImportNotice = null;
    _lastImportDetail = null;
    final baseline = state.asData?.value.dashboard.totalPhotos ?? 0;
    final epoch = ++_importRefreshEpoch;
    final generation = ++_refreshGeneration;
    final expectedIds = expectedFileIds.where((id) => id.isNotEmpty).toSet();
    final importTaskIds = taskIds.where((id) => id.isNotEmpty).toSet();
    late final Future<bool> future;
    future = _refreshAfterImport(
      baseline: baseline,
      epoch: epoch,
      generation: generation,
      expectedFileIds: expectedIds,
      taskIds: importTaskIds,
    );
    _importRefreshInFlight = future;
    unawaited(
      future.then(
        (_) {
          if (identical(_importRefreshInFlight, future)) {
            _importRefreshInFlight = null;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_importRefreshInFlight, future)) {
            _importRefreshInFlight = null;
          }
        },
      ),
    );
    return future;
  }

  Future<bool> _refreshAfterImport({
    required int baseline,
    required int epoch,
    required int generation,
    required Set<String> expectedFileIds,
    required Set<String> taskIds,
  }) async {
    final imported = await _refreshImportSnapshot(
      baseline,
      epoch,
      generation,
      expectedFileIds,
    );
    if (imported) return true;
    if (!ref.mounted ||
        epoch != _importRefreshEpoch ||
        generation != _refreshGeneration) {
      return false;
    }

    if (taskIds.isNotEmpty) {
      final taskOutcome = await _pollImportTasks(
        taskIds,
        epoch: epoch,
        generation: generation,
      );
      if (taskOutcome == _ImportTaskPollOutcome.failed) {
        return false;
      }
      if (taskOutcome == _ImportTaskPollOutcome.completed) {
        final visible = await _refreshImportSnapshot(
          baseline,
          epoch,
          generation,
          expectedFileIds,
        );
        if (!visible && ref.mounted && epoch == _importRefreshEpoch) {
          _lastImportNotice = PhotoImportNotice.completedNotVisible;
        }
        return visible;
      }
    }

    final visible = await _pollImportedPhotos(
      baseline,
      epoch,
      generation,
      expectedFileIds,
    );
    if (!visible &&
        ref.mounted &&
        epoch == _importRefreshEpoch &&
        generation == _refreshGeneration) {
      _lastImportNotice = PhotoImportNotice.stillProcessing;
    }
    return visible;
  }

  Future<_ImportTaskPollOutcome> _pollImportTasks(
    Set<String> taskIds, {
    required int epoch,
    required int generation,
  }) async {
    if (!ref.mounted) {
      return _ImportTaskPollOutcome.pending;
    }
    final taskApi = ref.read(taskApiProvider);
    for (var attempt = 0; attempt < 15; attempt++) {
      if (!ref.mounted ||
          epoch != _importRefreshEpoch ||
          generation != _refreshGeneration) {
        return _ImportTaskPollOutcome.pending;
      }
      try {
        final tasks = await Future.wait(
          taskIds.map(taskApi.get),
          eagerError: true,
        );
        if (!ref.mounted ||
            epoch != _importRefreshEpoch ||
            generation != _refreshGeneration) {
          return _ImportTaskPollOutcome.pending;
        }
        TaskRecord? failed;
        for (final task in tasks) {
          if (task.isFailed || task.isCancelled) {
            failed = task;
            break;
          }
        }
        if (failed != null) {
          _lastImportDetail = failed.errorMessage?.trim();
          _lastImportNotice = PhotoImportNotice.backendFailed;
          return _ImportTaskPollOutcome.failed;
        }
        if (tasks.every((task) => task.isCompleted)) {
          return _ImportTaskPollOutcome.completed;
        }
      } on Exception {
        // 任务接口不可用时退回照片列表轮询，不阻断已完成的文件上传。
        return _ImportTaskPollOutcome.unavailable;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return _ImportTaskPollOutcome.pending;
  }

  Future<bool> _pollImportedPhotos(
    int baseline,
    int epoch,
    int generation,
    Set<String> expectedFileIds,
  ) async {
    for (var attempt = 0; attempt < 15; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!ref.mounted ||
          epoch != _importRefreshEpoch ||
          generation != _refreshGeneration) {
        return false;
      }
      try {
        if (await _refreshImportSnapshot(
          baseline,
          epoch,
          generation,
          expectedFileIds,
        )) {
          return true;
        }
      } on Exception catch (error) {
        if (attempt == 14 &&
            ref.mounted &&
            epoch == _importRefreshEpoch &&
            generation == _refreshGeneration) {
          _setError(describeUserFacingError(error).message);
        }
      }
    }
    return false;
  }

  Future<bool> _refreshImportSnapshot(
    int baseline,
    int epoch,
    int generation,
    Set<String> expectedFileIds,
  ) async {
    final current = state.asData?.value ?? PhotoCenterState.empty();
    final query = current.searchQuery.trim();
    final photosFuture =
        current.tab == PhotoTab.favorites
            ? _repo.listFavorites(query: query)
            : _repo.listPhotos(
              query: current.tab == PhotoTab.all ? query : null,
            );
    final results = await Future.wait([_repo.dashboard(), photosFuture]);
    if (!ref.mounted ||
        epoch != _importRefreshEpoch ||
        generation != _refreshGeneration) {
      return false;
    }
    final dashboard = results[0] as PhotoDashboard;
    final photoPage = results[1] as PhotoPage;
    final containsExpected = expectedFileIds.any(
      (id) => photoPage.items.any((photo) => photo.fileNodeId == id),
    );
    final isFavorites = current.tab == PhotoTab.favorites;
    state = AsyncData(
      isFavorites
          ? current.copyWith(
            dashboard: dashboard,
            favorites: photoPage.items,
            favoritePage: photoPage.page,
            favoriteTotalElements: photoPage.totalElements,
            favoriteRefreshVersion: current.favoriteRefreshVersion + 1,
            clearFavoritePageError: true,
          )
          : current.copyWith(
            dashboard: dashboard,
            photos: photoPage.items,
            photoPage: photoPage.page,
            photoTotalElements: photoPage.totalElements,
            photoRefreshVersion: current.photoRefreshVersion + 1,
            clearPhotoPageError: true,
          ),
    );
    ref.read(photoDashboardProvider.notifier).replace(dashboard);
    final imported =
        expectedFileIds.isEmpty
            ? dashboard.totalPhotos > baseline
            : containsExpected || dashboard.totalPhotos > baseline;
    return imported;
  }

  /// 严格刷新实时事件涉及的核心照片数据。
  Future<void> refreshForRealtime() {
    final active = _realtimeRefreshInFlight;
    if (active != null) return active;
    _importRefreshEpoch++;
    final generation = ++_refreshGeneration;
    late final Future<void> future;
    future = _refreshForRealtime(generation);
    _realtimeRefreshInFlight = future;
    unawaited(
      future.then(
        (_) {
          if (identical(_realtimeRefreshInFlight, future)) {
            _realtimeRefreshInFlight = null;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_realtimeRefreshInFlight, future)) {
            _realtimeRefreshInFlight = null;
          }
        },
      ),
    );
    return future;
  }

  Future<void> _refreshForRealtime(int generation) async {
    final current = state.asData?.value ?? PhotoCenterState.empty();
    final results = await Future.wait([
      _repo.dashboard(),
      _repo.listPhotos(
        query: current.tab == PhotoTab.all ? current.searchQuery : null,
      ),
      _repo.listFavorites(
        query: current.tab == PhotoTab.favorites ? current.searchQuery : null,
      ),
      _repo.listAlbums(),
    ]);
    if (!ref.mounted || generation != _refreshGeneration) return;
    final photoPage = results[1] as PhotoPage;
    final favoritePage = results[2] as PhotoPage;
    state = AsyncData(
      current.copyWith(
        dashboard: results[0] as PhotoDashboard,
        photos: _mergeRefreshedPage(
          current.photos,
          photoPage.items,
          photoPage.totalElements,
        ),
        favorites: _mergeRefreshedPage(
          current.favorites,
          favoritePage.items,
          favoritePage.totalElements,
        ),
        albums: results[3] as List<PhotoAlbum>,
        photoTotalElements: photoPage.totalElements,
        favoriteTotalElements: favoritePage.totalElements,
        photoRefreshVersion: current.photoRefreshVersion + 1,
        favoriteRefreshVersion: current.favoriteRefreshVersion + 1,
        clearError: true,
      ),
    );
    if (current.timeline != null) {
      if (!ref.mounted || generation != _refreshGeneration) return;
      await loadTimeline(force: true);
    }
    if (current.groups != null) {
      if (!ref.mounted || generation != _refreshGeneration) return;
      await loadGroups(current.groupBy, force: true);
    }
  }

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

  @override
  void _setError(String message) {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(current.copyWith(errorMessage: message));
    }
  }

  void clearError() {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(current.copyWith(clearError: true));
    }
  }

  /// 切换 Tab
  void selectTab(PhotoTab tab) {
    final current = state.asData?.value;
    if (current == null) return;
    _importRefreshEpoch++;
    _refreshGeneration++;
    state = AsyncData(current.copyWith(tab: tab, searchQuery: ''));
    _searchDebounce?.cancel();
    if (current.searchQuery.isNotEmpty &&
        (tab == PhotoTab.all || tab == PhotoTab.favorites)) {
      unawaited(_reloadVisiblePage(tab, ''));
    }
  }

  /// 设置搜索关键字
  void setSearchQuery(String query) {
    final current = state.asData?.value;
    if (current == null) return;
    _importRefreshEpoch++;
    _refreshGeneration++;
    state = AsyncData(current.copyWith(searchQuery: query));
    if (current.tab != PhotoTab.all && current.tab != PhotoTab.favorites) {
      return;
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_reloadVisiblePage(current.tab, query));
    });
  }

  /// 切换收藏状态。
  ///
  /// [currentFavorite] 必须由调用方传入照片的真实当前值（如详情页持有的
  /// photo.favorite），避免分页快照缺失或过期时把取消收藏误判为收藏。
  Future<void> toggleFavorite(
    String photoId, {
    required bool currentFavorite,
  }) async {
    final current = state.asData?.value;
    if (current == null) return;
    try {
      if (currentFavorite) {
        await _repo.removeFavorite(photoId);
      } else {
        await _repo.addFavorite(photoId);
      }
      await refresh();
    } on Exception catch (e) {
      _setError(describeUserFacingError(e).message);
      rethrow;
    }
  }

  /// 删除照片
  Future<TaskSubmission> deletePhoto(
    String photoId, {
    bool cascade = false,
  }) async {
    try {
      final submission = await _repo.deletePhoto(photoId, cascade: cascade);
      _removePhotosOptimistically(<String>{photoId});
      ref.invalidate(activeTaskSummaryProvider);
      unawaited(ref.read(taskListProvider.notifier).load());
      return submission;
    } on Exception catch (e) {
      _setError(describeUserFacingError(e).message);
      rethrow;
    }
  }

  /// 批量删除照片并跟踪统一任务。
  Future<TaskSubmission> deletePhotos(
    List<String> photoIds, {
    bool cascade = false,
  }) async {
    try {
      final submission = await _repo.deletePhotos(photoIds, cascade: cascade);
      _removePhotosOptimistically(photoIds.toSet());
      ref.invalidate(activeTaskSummaryProvider);
      unawaited(ref.read(taskListProvider.notifier).load());
      return submission;
    } on Exception catch (error) {
      _setError(describeUserFacingError(error).message);
      rethrow;
    }
  }

  void _removePhotosOptimistically(Set<String> photoIds) {
    final current = state.asData?.value;
    if (current == null || photoIds.isEmpty) return;
    final removedFavoriteCount =
        current.favorites.where((photo) => photoIds.contains(photo.id)).length;
    final dashboard = current.dashboard;
    state = AsyncData(
      current.copyWith(
        dashboard: PhotoDashboard(
          totalPhotos: _subtractFloorZero(
            dashboard.totalPhotos,
            photoIds.length,
          ),
          totalAlbums: dashboard.totalAlbums,
          totalFavorites: _subtractFloorZero(
            dashboard.totalFavorites,
            removedFavoriteCount,
          ),
          recentPhotos: dashboard.recentPhotos
              .where((photo) => !photoIds.contains(photo.id))
              .toList(growable: false),
          favoritePhotos: dashboard.favoritePhotos
              .where((photo) => !photoIds.contains(photo.id))
              .toList(growable: false),
        ),
        photos: current.photos
            .where((photo) => !photoIds.contains(photo.id))
            .toList(growable: false),
        favorites: current.favorites
            .where((photo) => !photoIds.contains(photo.id))
            .toList(growable: false),
        selectedPhotoIds: current.selectedPhotoIds.difference(photoIds),
        photoTotalElements: _subtractFloorZero(
          current.photoTotalElements,
          photoIds.length,
        ),
        favoriteTotalElements: _subtractFloorZero(
          current.favoriteTotalElements,
          removedFavoriteCount,
        ),
      ),
    );
    ref.read(photoDashboardProvider.notifier).removePhotos(photoIds);
  }

  int _subtractFloorZero(int value, int decrement) {
    final result = value - decrement;
    return result < 0 ? 0 : result;
  }

  /// 创建相册
  Future<PhotoAlbum> createAlbum({
    required String name,
    String? description,
  }) async {
    try {
      final album = await _repo.createAlbum(
        name: name,
        description: description,
      );
      await refresh();
      return album;
    } on Exception catch (e) {
      _setError(describeUserFacingError(e).message);
      rethrow;
    }
  }

  /// 删除相册
  Future<void> deleteAlbum(String albumId) async {
    try {
      await _repo.deleteAlbum(albumId);
      await refresh();
    } on Exception catch (e) {
      _setError(describeUserFacingError(e).message);
      rethrow;
    }
  }

  /// 添加照片到相册
  Future<void> addPhotosToAlbum({
    required String albumId,
    required List<String> photoIds,
  }) async {
    try {
      await _repo.addPhotosToAlbum(albumId: albumId, photoIds: photoIds);
      await refresh();
    } on Exception catch (e) {
      _setError(describeUserFacingError(e).message);
      rethrow;
    }
  }

  /// 获取相册列表（用于选择对话框）
  Future<List<PhotoAlbum>> listAlbums() async {
    return _repo.listAlbums();
  }

  /// 触发照片扫描
  Future<Map<String, dynamic>> triggerScan() async {
    return _repo.triggerScan();
  }

  /// 查询扫描状态
  Future<Map<String, dynamic>> getScanStatus(String jobId) async {
    return _repo.getScanStatus(jobId);
  }

  /// 创建缩略图重建任务，返回任务 ID（进度在任务中心查看）。
  Future<String> regenerateThumbnails() async {
    return _repo.regenerateThumbnails();
  }

  /// 从相册移除照片
  Future<void> removePhotoFromAlbum({
    required String albumId,
    required String photoId,
  }) async {
    try {
      await _repo.removePhotoFromAlbum(albumId: albumId, photoId: photoId);
      await refresh();
    } on Exception catch (e) {
      _setError(describeUserFacingError(e).message);
      rethrow;
    }
  }
}

final photoCenterControllerProvider =
    AsyncNotifierProvider<PhotoCenterController, PhotoCenterState>(
      PhotoCenterController.new,
    );
