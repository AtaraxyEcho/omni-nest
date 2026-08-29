import 'package:flutter/foundation.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/domain/photo_album.dart';
import 'package:omninest/features/photos/domain/photo_face_cluster.dart';
import 'package:omninest/features/photos/domain/photo_group.dart';

/// 组成星系视图的筛选维度。
///
/// 这些维度必须对应当前后端真实提供的关系数据。事件推理尚未接入，
/// 因此不在星系筛选器中伪装成可用维度。
enum PhotoGalaxyMode { all, time, location, people }

/// 星系节点对应的数据来源。
enum PhotoGalaxyClusterKind { album, group, person, unassigned }

/// 节点数量的实际含义，避免把人脸数量误显示为照片数量。
enum PhotoGalaxyCountKind { photos, faces }

/// 星系总览中的一个可交互节点。
@immutable
class PhotoGalaxyCluster {
  const PhotoGalaxyCluster({
    required this.id,
    required this.title,
    required this.photoCount,
    required this.photos,
    required this.kind,
    this.countKind = PhotoGalaxyCountKind.photos,
    this.sourceId,
    this.coverUrl,
    this.album,
  });

  final String id;
  final String title;
  final int photoCount;
  final List<PhotoItem> photos;
  final PhotoGalaxyClusterKind kind;
  final PhotoGalaxyCountKind countKind;
  final String? sourceId;
  final String? coverUrl;
  final PhotoAlbum? album;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (title.toLowerCase().contains(normalized)) return true;
    return photos.any(
      (photo) =>
          photo.title.toLowerCase().contains(normalized) ||
          photo.tags.any((tag) => tag.toLowerCase().contains(normalized)),
    );
  }
}

/// 将相册、分组和人物数据转换为星系节点。
///
/// 保持转换函数为纯函数，便于验证节点来源、数量语义和空数据行为。
List<PhotoGalaxyCluster> buildPhotoGalaxyClusters(
  PhotoCenterState state,
  PhotoGalaxyMode mode,
) {
  switch (mode) {
    case PhotoGalaxyMode.people:
      return state.faceClusters.map(_personCluster).toList(growable: false);
    case PhotoGalaxyMode.time:
      return _groupClustersFor(state, GroupBy.date);
    case PhotoGalaxyMode.location:
      return _groupClustersFor(state, GroupBy.location);
    case PhotoGalaxyMode.all:
      final groups =
          state.groupBy == GroupBy.date
              ? (state.groups ?? const <PhotoGroup>[])
              : const <PhotoGroup>[];
      final clusters = <PhotoGalaxyCluster>[
        ...state.albums.map(_albumCluster),
        ..._groupClusters(groups),
      ];
      final relatedPhotoIds = <String>{
        for (final group in groups)
          for (final photo in group.photos) photo.id,
      };
      final unassignedPhotos = state.photos
          .where((photo) => !relatedPhotoIds.contains(photo.id))
          .toList(growable: false);
      if (unassignedPhotos.isNotEmpty) {
        clusters.add(
          PhotoGalaxyCluster(
            id: 'unassigned',
            title: '',
            photoCount: unassignedPhotos.length,
            photos: unassignedPhotos,
            kind: PhotoGalaxyClusterKind.unassigned,
          ),
        );
      }
      return clusters;
  }
}

List<PhotoGalaxyCluster> _groupClustersFor(
  PhotoCenterState state,
  GroupBy expectedGroupBy,
) {
  if (state.groupBy != expectedGroupBy) return const [];
  return _groupClusters(state.groups);
}

PhotoGalaxyCluster _albumCluster(PhotoAlbum album) {
  return PhotoGalaxyCluster(
    id: 'album:${album.id}',
    sourceId: album.id,
    title: album.name,
    photoCount: album.photoCount,
    photos: const [],
    coverUrl: album.coverUrl,
    album: album,
    kind: PhotoGalaxyClusterKind.album,
  );
}

PhotoGalaxyCluster _personCluster(PhotoFaceCluster cluster) {
  return PhotoGalaxyCluster(
    id: 'person:${cluster.id}',
    sourceId: cluster.id,
    title: cluster.name?.trim() ?? '',
    photoCount: cluster.faceCount,
    photos: const [],
    coverUrl: cluster.coverPhotoUrl,
    kind: PhotoGalaxyClusterKind.person,
    countKind: PhotoGalaxyCountKind.faces,
  );
}

List<PhotoGalaxyCluster> _groupClusters(List<PhotoGroup>? groups) {
  return (groups ?? const <PhotoGroup>[])
      .map(
        (group) => PhotoGalaxyCluster(
          id: 'group:${group.groupKey}',
          title: group.groupKey,
          photoCount: group.photoCount,
          photos: group.photos,
          coverUrl: group.photos.firstOrNull?.coverUrl,
          kind: PhotoGalaxyClusterKind.group,
        ),
      )
      .toList(growable: false);
}
