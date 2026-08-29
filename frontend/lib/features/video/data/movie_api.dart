import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:omninest/core/device/playback_device_identity.dart';
import 'package:omninest/core/errors/app_exception.dart';
import 'package:omninest/core/network/api_client.dart';
import 'package:omninest/features/video/domain/movie_models.dart';
import 'package:omninest/features/tasks/domain/task_record.dart';

class MovieApi {
  const MovieApi(this.apiClient);

  static const int _subtitleMaxBytes = 2 * 1024 * 1024;

  final ApiClient apiClient;

  Future<MovieDashboard> dashboard() async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/dashboard',
    );
    return MovieDashboard.fromJson(parseData(response.data));
  }

  Future<List<MovieVideoItem>> library({String mediaType = 'MOVIE'}) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/library',
      queryParameters: {'mediaType': mediaType},
    );
    final data = parseEnvelope(response.data)['data'];
    if (data is! List) {
      throw const AppException(code: 'INVALID_RESPONSE', message: '影视列表格式不正确');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(MovieVideoItem.fromJson)
        .toList();
  }

  Future<MediaPage<MovieVideoItem>> libraryPage({
    String mediaType = 'MOVIE',
    String? metadataStatus,
    int page = 0,
    int size = 36,
    String sort = 'updatedAt,desc',
  }) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/library/page',
      queryParameters: {
        'mediaType': mediaType,
        if (metadataStatus != null) 'metadataStatus': metadataStatus,
        'page': page,
        'size': size,
        'sort': sort,
      },
    );
    return MediaPage.fromJson(
      parseData(response.data),
      MovieVideoItem.fromJson,
    );
  }

  Future<List<MovieVideoItem>> recent({int days = 30}) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/recent',
      queryParameters: {'days': days},
    );
    return parseList(response.data).map(MovieVideoItem.fromJson).toList();
  }

  Future<List<MovieVideoItem>> seriesEpisodes(String seriesId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/series/$seriesId/episodes',
    );
    return parseList(response.data).map(MovieVideoItem.fromJson).toList();
  }

  Future<List<MovieContinueWatching>> continueWatching() async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/continue',
    );
    return parseList(
      response.data,
    ).map(MovieContinueWatching.fromJson).toList();
  }

  Future<List<MovieVideoItem>> favorites() async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/favorites',
    );
    return parseList(response.data).map(MovieVideoItem.fromJson).toList();
  }

  Future<List<MovieWatchHistory>> history() async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/history',
    );
    return parseList(response.data).map(MovieWatchHistory.fromJson).toList();
  }

  Future<void> deleteHistoryItem(String historyId) async {
    await apiClient.dio.delete<Map<String, dynamic>>(
      '/video/history/$historyId',
    );
  }

  Future<void> clearHistory() async {
    await apiClient.dio.delete<Map<String, dynamic>>('/video/history');
  }

  Future<List<MovieCollection>> collections() async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/collections',
    );
    return parseList(response.data).map(MovieCollection.fromJson).toList();
  }

  Future<List<MovieTask>> tasks({String? type}) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/tasks',
      queryParameters: {if (type != null) 'type': type},
    );
    return parseList(response.data).map(MovieTask.fromJson).toList();
  }

  Future<MovieVideoItem> detail(String videoItemId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/items/$videoItemId',
    );
    return MovieVideoItem.fromJson(parseData(response.data));
  }

  Future<List<MovieVideoItem>> versions(String videoItemId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/items/$videoItemId/versions',
    );
    return parseList(response.data).map(MovieVideoItem.fromJson).toList();
  }

  Future<TaskSubmission> deleteItem(
    String videoItemId, {
    bool cascade = false,
  }) async {
    final response = await apiClient.dio.delete<Map<String, dynamic>>(
      '/video/items/$videoItemId',
      queryParameters: {'cascade': cascade},
    );
    return TaskSubmission.fromJson(parseData(response.data));
  }

  Future<MovieVideoItem> updateMetadata({
    required String videoItemId,
    required String title,
    String? originalTitle,
    DateTime? releaseDate,
    String? overview,
    String? posterFileId,
    String? backdropFileId,
    int? runtimeSeconds,
    String metadataStatus = 'MANUAL',
  }) async {
    final response = await apiClient.dio.put<Map<String, dynamic>>(
      '/admin/video/items/$videoItemId/metadata',
      data: {
        'title': title,
        'originalTitle': originalTitle,
        'releaseDate': releaseDate?.toIso8601String().split('T').first,
        'overview': overview,
        'posterFileId': posterFileId,
        'backdropFileId': backdropFileId,
        'runtimeSeconds': runtimeSeconds,
        'metadataStatus': metadataStatus,
      },
    );
    return MovieVideoItem.fromJson(parseData(response.data));
  }

  Future<PlaybackPlan> playbackPlan(String videoItemId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/items/$videoItemId/playback',
    );
    return PlaybackPlan.fromJson(parseData(response.data));
  }

  Future<PlaybackPlan> updateProgress({
    required String videoItemId,
    required int positionSeconds,
    required int durationSeconds,
    bool completed = false,
  }) async {
    final deviceId = await PlaybackDeviceIdentity.getOrCreate();
    final response = await apiClient.dio.put<Map<String, dynamic>>(
      '/video/items/$videoItemId/progress',
      data: {
        'positionSeconds': positionSeconds,
        'durationSeconds': durationSeconds,
        'completed': completed,
        'clientUpdatedAt': DateTime.now().toUtc().toIso8601String(),
        'deviceId': deviceId,
      },
    );
    return PlaybackPlan.fromJson(parseData(response.data));
  }

  /// 读取有界字幕文本。
  Future<String> loadSubtitle(String url) async {
    final response = await apiClient.dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Range': 'bytes=0-${_subtitleMaxBytes - 1}'},
        validateStatus: (status) => status == 200 || status == 206,
      ),
    );
    final body = response.data;
    if (body == null) {
      return '';
    }
    final bytes = BytesBuilder(copy: false);
    var remaining = _subtitleMaxBytes;
    await for (final chunk in body.stream) {
      if (remaining <= 0) {
        break;
      }
      if (chunk.length <= remaining) {
        bytes.add(chunk);
        remaining -= chunk.length;
      } else {
        bytes.add(chunk.sublist(0, remaining));
        remaining = 0;
      }
    }
    return utf8.decode(bytes.takeBytes(), allowMalformed: true);
  }

  Future<List<VideoScrapeCandidate>> scrapeCandidates(String fileNodeId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/scrape/candidates',
      queryParameters: {'fileNodeId': fileNodeId},
    );
    return parseList(response.data).map(VideoScrapeCandidate.fromJson).toList();
  }

  Future<ScrapeTask> createScrapeTask({
    required String fileNodeId,
    bool force = false,
  }) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/video/scrape/tasks',
      data: {'fileNodeId': fileNodeId, 'force': force},
    );
    return ScrapeTask.fromJson(parseData(response.data));
  }

  Future<void> probeItem(String videoItemId) async {
    await apiClient.dio.post<Map<String, dynamic>>(
      '/video/items/$videoItemId/probe',
    );
  }

  Future<MovieFavoriteState> favorite({
    required String videoItemId,
    required bool favorite,
  }) async {
    final response = await apiClient.dio.put<Map<String, dynamic>>(
      '/video/items/$videoItemId/favorite',
      queryParameters: {'favorite': favorite},
    );
    return MovieFavoriteState.fromJson(parseData(response.data));
  }

  Future<MovieFavoriteState> favoriteStatus(String videoItemId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/items/$videoItemId/favorite/status',
    );
    return MovieFavoriteState.fromJson(parseData(response.data));
  }

  Future<MovieCollection> createCollection({
    required String name,
    String? description,
    String? coverFileId,
  }) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/video/collections',
      data: {
        'name': name,
        'description': description,
        'coverFileId': coverFileId,
      },
    );
    return MovieCollection.fromJson(parseData(response.data));
  }

  Future<List<MovieVideoItem>> collectionItems(String collectionId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/collections/$collectionId/items',
    );
    return parseList(response.data).map(MovieVideoItem.fromJson).toList();
  }

  Future<void> addCollectionItem({
    required String collectionId,
    required String videoItemId,
  }) async {
    await apiClient.dio.post<Map<String, dynamic>>(
      '/video/collections/$collectionId/items',
      data: {'videoItemId': videoItemId},
    );
  }

  Future<void> removeCollectionItem({
    required String collectionId,
    required String videoItemId,
  }) async {
    await apiClient.dio.delete<Map<String, dynamic>>(
      '/video/collections/$collectionId/items/$videoItemId',
    );
  }

  Future<void> deleteCollection(String collectionId) async {
    await apiClient.dio.delete<Map<String, dynamic>>(
      '/video/collections/$collectionId',
    );
  }

  Future<ScrapeTask> createTranscodeTask(
    String videoItemId, {
    bool audioOnly = false,
  }) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/video/items/$videoItemId/transcode/tasks',
      queryParameters: {'audioOnly': audioOnly},
    );
    return ScrapeTask.fromJson(parseData(response.data));
  }

  Future<ScrapeTask> scanLibrary({
    String? rootFolderId,
    bool incremental = true,
  }) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/video/scan/tasks',
      data: {'rootFolderId': rootFolderId, 'incremental': incremental},
    );
    return ScrapeTask.fromJson(parseData(response.data));
  }

  Future<List<VideoStorageLocation>> accessibleStorageLocations() async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/storage/locations/accessible',
    );
    return parseList(response.data).map(VideoStorageLocation.fromJson).toList();
  }

  Future<List<VideoLibrarySource>> librarySources() async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/library-sources',
    );
    return parseList(response.data).map(VideoLibrarySource.fromJson).toList();
  }

  Future<MediaLibraryAccessSettings> libraryAccess(String sourceId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/library-sources/$sourceId/access',
    );
    return MediaLibraryAccessSettings.fromJson(parseData(response.data));
  }

  Future<MediaLibraryAccessSettings> updateLibraryAccess({
    required String sourceId,
    required MediaLibraryVisibility visibility,
    required Set<String> userIds,
    required int expectedVersion,
  }) async {
    final response = await apiClient.dio.put<Map<String, dynamic>>(
      '/video/library-sources/$sourceId/access',
      data: {
        'visibilityType': visibility.apiValue,
        'userIds': userIds.toList()..sort(),
        'expectedVersion': expectedVersion,
      },
    );
    return MediaLibraryAccessSettings.fromJson(parseData(response.data));
  }

  Future<MediaPage<MediaLibraryUserCandidate>> libraryAccessUsers({
    String? query,
    int page = 0,
    int size = 50,
  }) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/library-access/users',
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        'page': page,
        'size': size,
      },
    );
    return MediaPage.fromJson(
      parseData(response.data),
      MediaLibraryUserCandidate.fromJson,
    );
  }

  Future<MediaPage<VideoStorageDirectory>> storageDirectories({
    required String locationId,
    String? parent,
    int page = 0,
    int size = 100,
  }) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/storage/locations/$locationId/directories',
      queryParameters: {
        if (parent != null) 'parent': parent,
        'page': page,
        'size': size,
      },
    );
    return MediaPage.fromJson(
      parseData(response.data),
      VideoStorageDirectory.fromJson,
    );
  }

  Future<VideoLibrarySource> createLibrarySource({
    required String name,
    required String storageLocationId,
    required String relativeRoot,
    required VideoLibraryType libraryType,
    bool enabled = true,
  }) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/video/library-sources',
      data: {
        'name': name,
        'storageLocationId': storageLocationId,
        'relativeRoot': relativeRoot,
        'libraryType': libraryType.apiValue,
        'importPolicy': 'MANUAL_REVIEW',
        'enabled': enabled,
      },
    );
    return VideoLibrarySource.fromJson(parseData(response.data));
  }

  Future<VideoLibrarySource> updateLibrarySource({
    required String sourceId,
    required String name,
    required String relativeRoot,
    required VideoLibraryType libraryType,
    required bool enabled,
  }) async {
    final response = await apiClient.dio.put<Map<String, dynamic>>(
      '/video/library-sources/$sourceId',
      data: {
        'name': name,
        'relativeRoot': relativeRoot,
        'libraryType': libraryType.apiValue,
        'importPolicy': 'MANUAL_REVIEW',
        'enabled': enabled,
      },
    );
    return VideoLibrarySource.fromJson(parseData(response.data));
  }

  Future<void> deleteLibrarySource(String sourceId) async {
    await apiClient.dio.delete<Map<String, dynamic>>(
      '/video/library-sources/$sourceId',
    );
  }

  Future<ScrapeTask> scanLibrarySource(String sourceId) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/video/library-sources/$sourceId/scan/tasks',
    );
    return ScrapeTask.fromJson(parseData(response.data));
  }

  Future<ScrapeTask> discoverLibrarySource(String sourceId) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/video/library-sources/$sourceId/discovery/tasks',
    );
    return ScrapeTask.fromJson(parseData(response.data));
  }

  Future<MediaScanRun?> latestMediaScanRun(String sourceId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/library-sources/$sourceId/scan-runs/latest',
    );
    final data = parseEnvelope(response.data)['data'];
    return data is Map<String, dynamic> ? MediaScanRun.fromJson(data) : null;
  }

  Future<MediaScanRun> mediaScanRun(String runId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/scan-runs/$runId',
    );
    return MediaScanRun.fromJson(parseData(response.data));
  }

  Future<MediaPage<MediaScanTreeNode>> mediaScanTree({
    required String runId,
    String? parentNodeId,
    int page = 0,
    int size = 100,
  }) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/scan-runs/$runId/tree',
      queryParameters: {
        if (parentNodeId != null) 'parentNodeId': parentNodeId,
        'page': page,
        'size': size,
      },
    );
    return MediaPage.fromJson(
      parseData(response.data),
      MediaScanTreeNode.fromJson,
    );
  }

  Future<MediaSelectionSummary> updateMediaSelection({
    required String runId,
    required String nodeId,
    required bool selected,
    required int expectedRevision,
  }) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/video/scan-runs/$runId/selection-rules',
      data: {
        'nodeId': nodeId,
        'selected': selected,
        'expectedRevision': expectedRevision,
      },
    );
    return MediaSelectionSummary.fromJson(parseData(response.data));
  }

  Future<MediaSelectionSummary> mediaSelectionSummary(String runId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/scan-runs/$runId/selection-summary',
    );
    return MediaSelectionSummary.fromJson(parseData(response.data));
  }

  Future<ScrapeTask> applyMediaSelection({
    required String runId,
    required int expectedRevision,
  }) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/video/scan-runs/$runId/apply/tasks',
      data: {'expectedRevision': expectedRevision},
    );
    return ScrapeTask.fromJson(parseData(response.data));
  }

  Future<MediaScanRun> pauseMediaScanRun(String runId) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/video/scan-runs/$runId/pause',
    );
    return MediaScanRun.fromJson(parseData(response.data));
  }

  Future<MediaScanRun> cancelMediaScanRun(String runId) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/video/scan-runs/$runId/cancel',
    );
    return MediaScanRun.fromJson(parseData(response.data));
  }

  Future<MediaPage<MediaUnavailableItem>> unavailableLocalMedia({
    int page = 0,
    int size = 100,
  }) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/library-sources/unavailable',
      queryParameters: {'page': page, 'size': size},
    );
    return MediaPage.fromJson(
      parseData(response.data),
      MediaUnavailableItem.fromJson,
    );
  }

  Future<NfoExport> nfoPreview(String videoItemId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/items/$videoItemId/nfo',
    );
    return NfoExport.fromJson(parseData(response.data));
  }

  Future<NfoExport> exportNfo(String videoItemId) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/video/items/$videoItemId/nfo',
    );
    return NfoExport.fromJson(parseData(response.data));
  }

  Future<List<MovieSeries>> seriesByType({String seriesType = 'TV'}) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/series/by-type',
      queryParameters: {'seriesType': seriesType},
    );
    return parseList(response.data).map(MovieSeries.fromJson).toList();
  }

  Future<MovieSeriesDetail> seriesDetail(String seriesId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/series/$seriesId',
    );
    return MovieSeriesDetail.fromJson(parseData(response.data));
  }

  Future<MovieSeasonDetail> seasonDetail(
    String seriesId,
    int seasonNumber,
  ) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/series/$seriesId/seasons/$seasonNumber',
    );
    return MovieSeasonDetail.fromJson(parseData(response.data));
  }

  Future<List<MovieContentAsset>> itemAssets(String itemId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/items/$itemId/assets',
    );
    return parseList(response.data).map(MovieContentAsset.fromJson).toList();
  }

  Future<bool> seriesFavoriteStatus(String seriesId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/series/$seriesId/favorite/status',
    );
    final data = parseData(response.data);
    return data['favorite'] == true;
  }

  Future<void> toggleSeriesFavorite(String seriesId) async {
    await apiClient.dio.post<Map<String, dynamic>>(
      '/video/series/$seriesId/favorite',
    );
  }

  Future<List<SubtitleTrack>> listSubtitles(String videoItemId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/video/items/$videoItemId/subtitles',
    );
    return parseList(response.data).map(SubtitleTrack.fromJson).toList();
  }

  Future<SubtitleTrack> uploadSubtitle({
    required String videoItemId,
    required String fileNodeId,
    required String language,
    required String label,
    String kind = 'SUBTITLE',
  }) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/video/items/$videoItemId/subtitles',
      data: {
        'fileNodeId': fileNodeId,
        'language': language,
        'label': label,
        'kind': kind,
      },
    );
    return SubtitleTrack.fromJson(parseData(response.data));
  }

  Future<SubtitleTrack> updateSubtitle({
    required String subtitleId,
    String? language,
    String? label,
    String? kind,
  }) async {
    final response = await apiClient.dio.put<Map<String, dynamic>>(
      '/video/subtitles/$subtitleId',
      data: {
        if (language != null) 'language': language,
        if (label != null) 'label': label,
        if (kind != null) 'kind': kind,
      },
    );
    return SubtitleTrack.fromJson(parseData(response.data));
  }

  Future<void> deleteSubtitle(String subtitleId) async {
    await apiClient.dio.delete<Map<String, dynamic>>(
      '/video/subtitles/$subtitleId',
    );
  }

  Future<UploadSession> createUploadSession({
    required String fileName,
    required int sizeBytes,
    String? mimeType,
  }) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/uploads/sessions',
      data: {
        'fileName': fileName,
        'sizeBytes': sizeBytes,
        if (mimeType != null) 'mimeType': mimeType,
      },
    );
    return UploadSession.fromJson(parseData(response.data));
  }

  Future<void> uploadToPresignedUrl({
    required String presignedUrl,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final dio = Dio();
    await dio.put<void>(
      presignedUrl,
      data: bytes,
      options: Options(
        headers: {
          if (mimeType != null) 'Content-Type': mimeType,
          'Content-Length': bytes.length,
        },
      ),
    );
  }

  Future<FileNodeResult> completeUploadSession({
    required String uploadId,
  }) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/uploads/$uploadId/complete',
    );
    return FileNodeResult.fromJson(parseData(response.data));
  }

  Map<String, dynamic> parseData(Map<String, dynamic>? body) {
    final envelope = parseEnvelope(body);
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw const AppException(code: 'INVALID_RESPONSE', message: '影视响应格式不正确');
    }
    return data;
  }

  List<Map<String, dynamic>> parseList(Map<String, dynamic>? body) {
    final data = parseEnvelope(body)['data'];
    if (data is! List) {
      throw const AppException(code: 'INVALID_RESPONSE', message: '影视列表格式不正确');
    }
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Map<String, dynamic> parseEnvelope(Map<String, dynamic>? body) {
    if (body == null) {
      throw const AppException(code: 'EMPTY_RESPONSE', message: '服务端没有返回影视结果');
    }
    final code = body['code'];
    if (code != 200) {
      throw AppException(
        code: code?.toString() ?? 'MOVIE_ERROR',
        message: body['message']?.toString() ?? '影视操作失败',
      );
    }
    return body;
  }
}
