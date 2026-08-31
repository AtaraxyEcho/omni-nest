import 'package:omninest/features/photos/data/photo_api.dart';
import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/domain/photo_album.dart';
import 'package:omninest/features/photos/domain/photo_batch_task.dart';
import 'package:omninest/features/photos/domain/photo_batch_download_ticket.dart';
import 'package:omninest/features/photos/domain/photo_edit_version.dart';
import 'package:omninest/features/photos/domain/photo_face_cluster.dart';
import 'package:omninest/features/photos/domain/photo_group.dart';
import 'package:omninest/features/photos/domain/photo_relation.dart';
import 'package:omninest/features/photos/domain/photo_repository.dart';
import 'package:omninest/features/photos/domain/photo_share_link.dart';
import 'package:omninest/features/photos/domain/photo_timeline.dart';
import 'package:omninest/features/tasks/domain/task_record.dart';

/// 照片仓储实现
class PhotoRepositoryImpl implements PhotoRepository {
  const PhotoRepositoryImpl(this._api);

  final PhotoApi _api;

  @override
  Future<PhotoDashboard> dashboard() => _api.dashboard();

  @override
  Future<PhotoPage> listPhotos({
    String? query,
    int page = 0,
    int size = 50,
    String sort = 'createdAt,desc',
  }) => _api.listPhotos(query: query, page: page, size: size, sort: sort);

  @override
  Future<PhotoItem> getPhoto(String photoId) => _api.getPhoto(photoId);

  @override
  Future<TaskSubmission> deletePhoto(String photoId, {bool cascade = false}) =>
      _api.deletePhoto(photoId, cascade: cascade);

  @override
  Future<TaskSubmission> deletePhotos(
    List<String> photoIds, {
    bool cascade = false,
  }) => _api.deletePhotos(photoIds, cascade: cascade);

  @override
  Future<PhotoPage> listFavorites({
    String? query,
    int page = 0,
    int size = 50,
    String sort = 'createdAt,desc',
  }) => _api.listFavorites(query: query, page: page, size: size, sort: sort);

  @override
  Future<void> addFavorite(String photoId) => _api.addFavorite(photoId);

  @override
  Future<void> removeFavorite(String photoId) => _api.removeFavorite(photoId);

  @override
  Future<List<PhotoAlbum>> listAlbums() => _api.listAlbums();

  @override
  Future<PhotoAlbum> createAlbum({required String name, String? description}) =>
      _api.createAlbum(name: name, description: description);

  @override
  Future<PhotoAlbumDetail> getAlbumDetail(String albumId) =>
      _api.getAlbumDetail(albumId);

  @override
  Future<PhotoAlbum> updateAlbum({
    required String albumId,
    String? name,
    String? description,
  }) =>
      _api.updateAlbum(albumId: albumId, name: name, description: description);

  @override
  Future<void> deleteAlbum(String albumId) => _api.deleteAlbum(albumId);

  @override
  Future<void> addPhotosToAlbum({
    required String albumId,
    required List<String> photoIds,
  }) => _api.addPhotosToAlbum(albumId: albumId, photoIds: photoIds);

  @override
  Future<void> removePhotoFromAlbum({
    required String albumId,
    required String photoId,
  }) => _api.removePhotoFromAlbum(albumId: albumId, photoId: photoId);

  @override
  Future<Map<String, dynamic>> triggerScan() => _api.triggerScan();

  @override
  Future<Map<String, dynamic>> getScanStatus(String jobId) =>
      _api.getScanStatus(jobId);

  @override
  @override
  Future<String> regenerateThumbnails() => _api.regenerateThumbnails();

  @override
  Future<PhotoTimelinePage> getTimeline({int page = 0, int size = 50}) =>
      _api.getTimeline(page: page, size: size);

  @override
  Future<PhotoRelationGraph> getRelationGraph() => _api.getRelationGraph();

  @override
  Future<PhotoGroupPage> getGroups(String by, {int page = 0, int size = 50}) =>
      _api.getGroups(by, page: page, size: size);

  @override
  Future<void> addTag(String photoId, String tag) => _api.addTag(photoId, tag);

  @override
  Future<void> removeTag(String photoId, String tag) =>
      _api.removeTag(photoId, tag);

  @override
  Future<List<String>> listTags() => _api.listTags();

  @override
  Future<PhotoBatchTask> createBatchTask({
    required String taskType,
    required List<String> photoIds,
    Map<String, dynamic>? params,
  }) => _api.createBatchTask(
    taskType: taskType,
    photoIds: photoIds,
    params: params,
  );

  @override
  Future<PhotoBatchTask> getBatchTask(String taskId) =>
      _api.getBatchTask(taskId);

  @override
  Future<PhotoBatchDownloadTicket> getBatchDownloadTicket(String taskId) =>
      _api.getBatchDownloadTicket(taskId);

  @override
  Future<void> downloadBatchArchive(
    PhotoBatchDownloadTicket ticket,
    String destinationPath,
  ) => _api.downloadBatchArchive(ticket, destinationPath);

  @override
  Future<PhotoEditVersion> applyEdit(
    String photoId,
    String editType,
    Map<String, dynamic> editParams,
  ) => _api.applyEdit(photoId, editType, editParams);

  @override
  Future<List<PhotoEditVersion>> listVersions(String photoId) =>
      _api.listVersions(photoId);

  @override
  Future<void> revertToVersion(String photoId, String versionId) =>
      _api.revertToVersion(photoId, versionId);

  @override
  Future<PhotoShareLink> createAlbumShare(
    String albumId, {
    String? password,
    DateTime? expiresAt,
    int? maxAccessCount,
  }) => _api.createAlbumShare(
    albumId,
    password: password,
    expiresAt: expiresAt,
    maxAccessCount: maxAccessCount,
  );

  @override
  Future<List<PhotoShareLink>> listAlbumShares(String albumId) =>
      _api.listAlbumShares(albumId);

  @override
  Future<void> revokeAlbumShare(String shareId) =>
      _api.revokeAlbumShare(shareId);

  @override
  Future<String> authorizeSharedAlbum(String token, {String? password}) =>
      _api.authorizeSharedAlbum(token, password: password);

  @override
  Future<PhotoSharedAlbum> accessSharedAlbum(
    String token, {
    required String sessionToken,
    int page = 0,
    int size = 50,
  }) => _api.accessSharedAlbum(
    token,
    sessionToken: sessionToken,
    page: page,
    size: size,
  );

  @override
  Future<List<PhotoFaceCluster>> listFaceClusters() => _api.listFaceClusters();

  @override
  Future<List<PhotoItem>> getPhotosByCluster(String clusterId) =>
      _api.getPhotosByCluster(clusterId);

  @override
  Future<void> nameCluster(String clusterId, String name) =>
      _api.nameCluster(clusterId, name);

  @override
  Future<String> reclusterFaces() => _api.reclusterFaces();

  @override
  Future<String> reanalyzeLibrary() => _api.reanalyzeLibrary();

  @override
  Future<Map<String, dynamic>> getBackupStatus(String deviceId) =>
      _api.getBackupStatus(deviceId);

  @override
  Future<void> reportBackup(String deviceId, int photoCount) =>
      _api.reportBackup(deviceId, photoCount);

  @override
  Future<List<String>> checkDuplicate(List<String> contentHashes) =>
      _api.checkDuplicate(contentHashes);
}
