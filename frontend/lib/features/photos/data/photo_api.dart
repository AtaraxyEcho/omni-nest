import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:omninest/core/errors/app_exception.dart';
import 'package:omninest/core/network/api_client.dart';
import 'package:omninest/features/photos/data/photo_batch_archive_downloader.dart';
import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/domain/photo_album.dart';
import 'package:omninest/features/photos/domain/photo_batch_task.dart';
import 'package:omninest/features/photos/domain/photo_batch_download_ticket.dart';
import 'package:omninest/features/photos/domain/photo_edit_version.dart';
import 'package:omninest/features/photos/domain/photo_face_cluster.dart';
import 'package:omninest/features/photos/domain/photo_group.dart';
import 'package:omninest/features/photos/domain/photo_share_link.dart';
import 'package:omninest/features/photos/domain/photo_timeline.dart';
import 'package:omninest/features/tasks/domain/task_record.dart';

/// 照片 API 客户端
class PhotoApi {
  const PhotoApi(this.apiClient);

  final ApiClient apiClient;

  /// 获取仪表盘数据
  Future<PhotoDashboard> dashboard() async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/photos/dashboard',
    );
    return PhotoDashboard.fromJson(parseData(response.data));
  }

  /// 分页获取照片列表。
  Future<PhotoPage> listPhotos({
    String? query,
    int page = 0,
    int size = 50,
    String sort = 'createdAt,desc',
  }) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/photos/page',
      queryParameters: {
        'page': page,
        'size': size,
        'sort': sort,
        if (query != null && query.isNotEmpty) 'query': query,
      },
    );
    return PhotoPage.fromJson(parseData(response.data));
  }

  /// 获取单张照片详情
  Future<PhotoItem> getPhoto(String photoId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/photos/$photoId',
    );
    return PhotoItem.fromJson(parseData(response.data));
  }

  /// 删除照片
  Future<TaskSubmission> deletePhoto(
    String photoId, {
    bool cascade = false,
  }) async {
    final response = await apiClient.dio.delete<Map<String, dynamic>>(
      '/photos/$photoId',
      queryParameters: {'cascade': cascade},
    );
    return TaskSubmission.fromJson(parseData(response.data));
  }

  /// 批量删除照片并返回统一任务。
  Future<TaskSubmission> deletePhotos(
    List<String> photoIds, {
    bool cascade = false,
  }) async {
    final response = await apiClient.dio.delete<Map<String, dynamic>>(
      '/photos/batch/purge',
      data: {'photoIds': photoIds},
      queryParameters: {'cascade': cascade},
    );
    return TaskSubmission.fromJson(parseData(response.data));
  }

  /// 分页获取收藏照片列表。
  Future<PhotoPage> listFavorites({
    String? query,
    int page = 0,
    int size = 50,
    String sort = 'createdAt,desc',
  }) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/photos/favorites/page',
      queryParameters: {
        'page': page,
        'size': size,
        'sort': sort,
        if (query != null && query.isNotEmpty) 'query': query,
      },
    );
    return PhotoPage.fromJson(parseData(response.data));
  }

  /// 添加收藏
  Future<void> addFavorite(String photoId) async {
    await apiClient.dio.post<Map<String, dynamic>>('/photos/$photoId/favorite');
  }

  /// 取消收藏
  Future<void> removeFavorite(String photoId) async {
    await apiClient.dio.delete<Map<String, dynamic>>(
      '/photos/$photoId/favorite',
    );
  }

  /// 获取相册列表
  Future<List<PhotoAlbum>> listAlbums() async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/photos/albums',
    );
    return parseList(response.data).map(PhotoAlbum.fromJson).toList();
  }

  /// 创建相册
  Future<PhotoAlbum> createAlbum({
    required String name,
    String? description,
  }) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/photos/albums',
      data: {
        'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    return PhotoAlbum.fromJson(parseData(response.data));
  }

  /// 获取相册详情
  Future<PhotoAlbumDetail> getAlbumDetail(String albumId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/photos/albums/$albumId',
    );
    return PhotoAlbumDetail.fromJson(parseData(response.data));
  }

  /// 更新相册
  Future<PhotoAlbum> updateAlbum({
    required String albumId,
    String? name,
    String? description,
  }) async {
    final response = await apiClient.dio.put<Map<String, dynamic>>(
      '/photos/albums/$albumId',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      },
    );
    return PhotoAlbum.fromJson(parseData(response.data));
  }

  /// 删除相册
  Future<void> deleteAlbum(String albumId) async {
    await apiClient.dio.delete<Map<String, dynamic>>('/photos/albums/$albumId');
  }

  /// 添加照片到相册
  Future<void> addPhotosToAlbum({
    required String albumId,
    required List<String> photoIds,
  }) async {
    await apiClient.dio.post<Map<String, dynamic>>(
      '/photos/albums/$albumId/items',
      data: {'photoIds': photoIds},
    );
  }

  /// 从相册移除照片
  Future<void> removePhotoFromAlbum({
    required String albumId,
    required String photoId,
  }) async {
    await apiClient.dio.delete<Map<String, dynamic>>(
      '/photos/albums/$albumId/items/$photoId',
    );
  }

  /// 触发照片扫描任务
  Future<Map<String, dynamic>> triggerScan() async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/admin/photos/scan',
    );
    return parseData(response.data);
  }

  /// 查询扫描任务状态
  Future<Map<String, dynamic>> getScanStatus(String jobId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/admin/photos/scan/$jobId/status',
    );
    return parseData(response.data);
  }

  /// 重建所有缩略图
  Future<int> regenerateThumbnails() async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/admin/photos/thumbnails/regenerate',
    );
    final data = parseData(response.data);
    if (data['regenerated'] is int) {
      return data['regenerated'] as int;
    }
    return 0;
  }

  /// 分页获取时间线月份数据。
  Future<PhotoTimelinePage> getTimeline({int page = 0, int size = 50}) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/photos/timeline/page',
      queryParameters: {'page': page, 'size': size},
    );
    return PhotoTimelinePage.fromJson(parseData(response.data));
  }

  /// 按维度分页查询照片分组。
  Future<PhotoGroupPage> getGroups(
    String by, {
    int page = 0,
    int size = 50,
  }) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/photos/groups/page',
      queryParameters: {'by': by, 'page': page, 'size': size},
    );
    return PhotoGroupPage.fromJson(parseData(response.data));
  }

  /// 添加标签
  Future<void> addTag(String photoId, String tag) async {
    await apiClient.dio.post<Map<String, dynamic>>(
      '/photos/$photoId/tags',
      data: {'tag': tag},
    );
  }

  /// 移除标签
  Future<void> removeTag(String photoId, String tag) async {
    await apiClient.dio.delete<Map<String, dynamic>>(
      '/photos/$photoId/tags/$tag',
    );
  }

  /// 查询所有标签
  Future<List<String>> listTags() async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/photos/tags',
    );
    final envelope = parseEnvelope(response.data);
    final data = envelope['data'];
    if (data is! List) return [];
    return data.map((e) => e.toString()).toList();
  }

  /// 创建批量任务
  Future<PhotoBatchTask> createBatchTask({
    required String taskType,
    required List<String> photoIds,
    Map<String, dynamic>? params,
  }) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/photos/batch',
      data: {
        'taskType': taskType,
        'photoIds': photoIds,
        if (params != null) 'params': params,
      },
    );
    return PhotoBatchTask.fromJson(parseData(response.data));
  }

  /// 查询批量任务状态
  Future<PhotoBatchTask> getBatchTask(String taskId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/photos/batch/$taskId',
    );
    return PhotoBatchTask.fromJson(parseData(response.data));
  }

  /// 获取照片批量 ZIP 的完整下载票据。
  Future<PhotoBatchDownloadTicket> getBatchDownloadTicket(String taskId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/photos/batch/$taskId/download-ticket',
    );
    final ticket = PhotoBatchDownloadTicket.fromJson(parseData(response.data));
    if (ticket.url.isEmpty ||
        ticket.fileName.isEmpty ||
        ticket.sizeBytes <= 0 ||
        ticket.expiresAt.isBefore(DateTime.now().toUtc())) {
      throw const AppException(
        code: 'PHOTO_BATCH_ARCHIVE_TICKET_INVALID',
        message: '照片批量 ZIP 下载票据无效或已过期',
      );
    }
    return ticket;
  }

  /// 在原生平台续传照片批量 ZIP 并原子保存。
  Future<void> downloadBatchArchive(
    PhotoBatchDownloadTicket ticket,
    String destinationPath,
  ) {
    return downloadPhotoBatchArchive(
      dio: apiClient.dio,
      ticket: ticket,
      destinationPath: destinationPath,
    );
  }

  /// 获取 RAW 格式照片的预览图。
  Future<Uint8List> rawPreview(String photoId) async {
    final response = await apiClient.dio.get<List<int>>(
      '/photos/$photoId/raw-preview',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? []);
  }

  /// 应用编辑操作
  Future<PhotoEditVersion> applyEdit(
    String photoId,
    String editType,
    Map<String, dynamic> editParams,
  ) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/photos/$photoId/edit',
      data: {'editType': editType, 'editParams': editParams},
    );
    return PhotoEditVersion.fromJson(parseData(response.data));
  }

  /// 获取编辑版本列表
  Future<List<PhotoEditVersion>> listVersions(String photoId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/photos/$photoId/versions',
    );
    return parseList(response.data).map(PhotoEditVersion.fromJson).toList();
  }

  /// 回滚到指定版本
  Future<void> revertToVersion(String photoId, String versionId) async {
    await apiClient.dio.post<Map<String, dynamic>>(
      '/photos/$photoId/versions/$versionId/revert',
    );
  }

  /// 创建相册分享链接
  Future<PhotoShareLink> createAlbumShare(
    String albumId, {
    String? password,
    DateTime? expiresAt,
    int? maxAccessCount,
  }) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/photos/albums/$albumId/share',
      data: {
        if (password != null && password.isNotEmpty) 'password': password,
        if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
        if (maxAccessCount != null) 'maxAccessCount': maxAccessCount,
      },
    );
    return PhotoShareLink.fromJson(parseData(response.data));
  }

  /// 列出相册分享链接
  Future<List<PhotoShareLink>> listAlbumShares(String albumId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/photos/albums/$albumId/share',
    );
    return parseList(response.data).map(PhotoShareLink.fromJson).toList();
  }

  /// 撤销分享链接
  Future<void> revokeAlbumShare(String shareId) async {
    await apiClient.dio.delete<Map<String, dynamic>>('/photos/share/$shareId');
  }

  /// 校验共享相册密码并获取短期会话令牌。
  Future<String> authorizeSharedAlbum(String token, {String? password}) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/public/photos/share/$token/authorize',
      data: {if (password != null && password.isNotEmpty) 'password': password},
    );
    return parseData(response.data)['sessionToken']?.toString() ??
        (throw StateError('分享会话响应无效'));
  }

  /// 访问共享相册（公开接口）
  Future<PhotoSharedAlbum> accessSharedAlbum(
    String token, {
    required String sessionToken,
    int page = 0,
    int size = 50,
  }) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/public/photos/share/$token',
      queryParameters: {'page': page, 'size': size},
      options: Options(headers: {'X-OmniNest-Share-Session': sessionToken}),
    );
    return PhotoSharedAlbum.fromJson(parseData(response.data));
  }

  // -- AI 人脸聚类 --

  /// 获取人脸聚类列表
  Future<List<PhotoFaceCluster>> listFaceClusters() async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/photos/people',
    );
    return parseList(response.data).map(PhotoFaceCluster.fromJson).toList();
  }

  /// 获取聚类中的照片
  Future<List<PhotoItem>> getPhotosByCluster(String clusterId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/photos/people/$clusterId',
    );
    return parseList(response.data).map(PhotoItem.fromJson).toList();
  }

  /// 为聚类命名
  Future<void> nameCluster(String clusterId, String name) async {
    await apiClient.dio.put<Map<String, dynamic>>(
      '/photos/people/$clusterId',
      data: {'name': name},
    );
  }

  /// 提交重新聚类任务
  Future<String> reclusterFaces() async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/photos/ai/recluster',
    );
    return parseData(response.data)['taskId']?.toString() ?? '';
  }

  /// 提交照片库存量 AI 重分析任务
  Future<String> reanalyzeLibrary() async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/photos/ai/reanalyze',
    );
    return parseData(response.data)['taskId']?.toString() ?? '';
  }

  // -- 备份状态 --

  /// 获取备份状态
  Future<Map<String, dynamic>> getBackupStatus(String deviceId) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/photos/backup/status',
      data: {'deviceId': deviceId},
    );
    return parseData(response.data);
  }

  /// 上报备份进度
  Future<void> reportBackup(String deviceId, int photoCount) async {
    await apiClient.dio.post<Map<String, dynamic>>(
      '/photos/backup/report',
      data: {'deviceId': deviceId, 'photoCount': photoCount},
    );
  }

  /// 检查重复文件（返回已存在的哈希列表）
  Future<List<String>> checkDuplicate(List<String> contentHashes) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/photos/backup/check-duplicate',
      data: contentHashes,
    );
    final envelope = parseEnvelope(response.data);
    final data = envelope['data'];
    if (data is List) {
      return data.map((e) => e.toString()).toList();
    }
    return [];
  }

  // -- 解析辅助函数 --

  Map<String, dynamic> parseData(Map<String, dynamic>? body) {
    final envelope = parseEnvelope(body);
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw const AppException(
        code: 'INVALID_RESPONSE',
        message: '照片中心返回格式不正确',
      );
    }
    return data;
  }

  List<Map<String, dynamic>> parseList(Map<String, dynamic>? body) {
    final envelope = parseEnvelope(body);
    final data = envelope['data'];
    if (data is! List) {
      throw const AppException(
        code: 'INVALID_RESPONSE',
        message: '照片中心列表返回格式不正确',
      );
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  Map<String, dynamic> parseEnvelope(Map<String, dynamic>? body) {
    final data = body ?? const <String, dynamic>{};
    final code = data['code'];
    if (code is num && code.toInt() >= 400) {
      throw AppException(
        code: code.toInt().toString(),
        message: data['message']?.toString() ?? '照片中心请求失败',
      );
    }
    return data;
  }
}
