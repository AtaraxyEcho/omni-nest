import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/domain/photo_album.dart';
import 'package:omninest/features/photos/domain/photo_face_cluster.dart';
import 'package:omninest/features/photos/domain/photo_group.dart';
import 'package:omninest/features/photos/domain/photo_relation.dart';
import 'package:omninest/features/photos/domain/photo_timeline.dart';

// -- 状态管理 --

/// 照片模块的三个顶级浏览表面（导航层），内部通过 PhotoTab 路由到具体内容。
enum PhotoSurface { library, people, explore }

/// 照片中心的内容页签（数据加载层）。
enum PhotoTab { all, favorites, albums, timeline, groups, graph, people }

/// 导航表面到默认数据页签的映射。
PhotoTab photoSurfaceToTab(PhotoSurface surface) => switch (surface) {
  PhotoSurface.library => PhotoTab.all,
  PhotoSurface.people => PhotoTab.people,
  PhotoSurface.explore => PhotoTab.timeline,
};

/// 导入流程提示类型；文案由界面层按语言映射。
enum PhotoImportNotice { completedNotVisible, stillProcessing, backendFailed }

/// 照片中心状态
class PhotoCenterState {
  const PhotoCenterState({
    required this.dashboard,
    required this.photos,
    required this.favorites,
    required this.albums,
    required this.tab,
    this.surface = PhotoSurface.library,
    this.searchQuery = '',
    this.timeline,
    this.groups,
    this.groupBy = GroupBy.date,
    this.selectedPhotoIds = const {},
    this.isSelectionMode = false,
    this.faceClusters = const [],
    this.isLoadingFaceClusters = false,
    this.relationGraph = PhotoRelationGraph.empty,
    this.isLoadingRelationGraph = false,
    this.relationGraphError,
    this.faceClusterError,
    this.photoPage = 0,
    this.favoritePage = 0,
    this.photoTotalElements = 0,
    this.favoriteTotalElements = 0,
    this.isLoadingMorePhotos = false,
    this.isLoadingMoreFavorites = false,
    this.photoRefreshVersion = 0,
    this.favoriteRefreshVersion = 0,
    this.photoPageError,
    this.favoritePageError,
    this.timelinePage = 0,
    this.timelineTotalElements = 0,
    this.isLoadingMoreTimeline = false,
    this.timelinePageError,
    this.groupPage = 0,
    this.groupTotalElements = 0,
    this.isLoadingGroups = false,
    this.isLoadingMoreGroups = false,
    this.groupPageError,
    this.errorMessage,
  });

  factory PhotoCenterState.empty() {
    return PhotoCenterState(
      dashboard: PhotoDashboard.empty(),
      photos: const [],
      favorites: const [],
      albums: const [],
      tab: PhotoTab.all,
    );
  }

  final PhotoDashboard dashboard;
  final List<PhotoItem> photos;
  final List<PhotoItem> favorites;
  final List<PhotoAlbum> albums;
  final PhotoTab tab;
  final PhotoSurface surface;
  final String searchQuery;
  final PhotoTimeline? timeline;
  final List<PhotoGroup>? groups;
  final GroupBy groupBy;
  final Set<String> selectedPhotoIds;
  final bool isSelectionMode;
  final List<PhotoFaceCluster> faceClusters;
  final bool isLoadingFaceClusters;
  final PhotoRelationGraph relationGraph;
  final bool isLoadingRelationGraph;
  final String? relationGraphError;
  final String? faceClusterError;
  final int photoPage;
  final int favoritePage;
  final int photoTotalElements;
  final int favoriteTotalElements;
  final bool isLoadingMorePhotos;
  final bool isLoadingMoreFavorites;
  final int photoRefreshVersion;
  final int favoriteRefreshVersion;
  final String? photoPageError;
  final String? favoritePageError;
  final int timelinePage;
  final int timelineTotalElements;
  final bool isLoadingMoreTimeline;
  final String? timelinePageError;
  final int groupPage;
  final int groupTotalElements;
  final bool isLoadingGroups;
  final bool isLoadingMoreGroups;
  final String? groupPageError;
  final String? errorMessage;

  bool get hasMorePhotos => photos.length < photoTotalElements;

  bool get hasMoreFavorites => favorites.length < favoriteTotalElements;

  bool get hasMoreTimeline =>
      timeline != null && timeline!.monthCount < timelineTotalElements;

  bool get hasMoreGroups =>
      groups != null && groups!.length < groupTotalElements;

  bool get hasMoreVisiblePhotos => switch (tab) {
    PhotoTab.all => hasMorePhotos,
    PhotoTab.favorites => hasMoreFavorites,
    _ => false,
  };

  bool get isLoadingMoreVisiblePhotos => switch (tab) {
    PhotoTab.all => isLoadingMorePhotos,
    PhotoTab.favorites => isLoadingMoreFavorites,
    _ => false,
  };

  int get visiblePhotoTotalElements => switch (tab) {
    PhotoTab.all => photoTotalElements,
    PhotoTab.favorites => favoriteTotalElements,
    _ => visiblePhotos.length,
  };

  /// 当前 tab 下可见的照片
  List<PhotoItem> get visiblePhotos {
    final source = switch (tab) {
      PhotoTab.all => photos,
      PhotoTab.favorites => favorites,
      PhotoTab.albums => const <PhotoItem>[],
      PhotoTab.timeline => photos,
      PhotoTab.groups => photos,
      PhotoTab.graph => photos,
      PhotoTab.people => const <PhotoItem>[],
    };
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return source;
    return source
        .where(
          (photo) =>
              photo.title.toLowerCase().contains(query) ||
              (photo.description ?? '').toLowerCase().contains(query),
        )
        .toList();
  }

  PhotoCenterState copyWith({
    PhotoDashboard? dashboard,
    List<PhotoItem>? photos,
    List<PhotoItem>? favorites,
    List<PhotoAlbum>? albums,
    PhotoTab? tab,
    PhotoSurface? surface,
    String? searchQuery,
    PhotoTimeline? timeline,
    List<PhotoGroup>? groups,
    GroupBy? groupBy,
    Set<String>? selectedPhotoIds,
    bool? isSelectionMode,
    List<PhotoFaceCluster>? faceClusters,
    PhotoRelationGraph? relationGraph,
    bool? isLoadingRelationGraph,
    String? relationGraphError,
    bool clearRelationGraphError = false,
    bool? isLoadingFaceClusters,
    String? faceClusterError,
    int? photoPage,
    int? favoritePage,
    int? photoTotalElements,
    int? favoriteTotalElements,
    bool? isLoadingMorePhotos,
    bool? isLoadingMoreFavorites,
    int? photoRefreshVersion,
    int? favoriteRefreshVersion,
    String? photoPageError,
    String? favoritePageError,
    int? timelinePage,
    int? timelineTotalElements,
    bool? isLoadingMoreTimeline,
    String? timelinePageError,
    int? groupPage,
    int? groupTotalElements,
    bool? isLoadingGroups,
    bool? isLoadingMoreGroups,
    String? groupPageError,
    bool clearPhotoPageError = false,
    bool clearFavoritePageError = false,
    bool clearTimelinePageError = false,
    bool clearGroupPageError = false,
    bool clearFaceClusterError = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PhotoCenterState(
      dashboard: dashboard ?? this.dashboard,
      photos: photos ?? this.photos,
      favorites: favorites ?? this.favorites,
      albums: albums ?? this.albums,
      tab: tab ?? this.tab,
      surface: surface ?? this.surface,
      searchQuery: searchQuery ?? this.searchQuery,
      timeline: timeline ?? this.timeline,
      groups: groups ?? this.groups,
      groupBy: groupBy ?? this.groupBy,
      selectedPhotoIds: selectedPhotoIds ?? this.selectedPhotoIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      faceClusters: faceClusters ?? this.faceClusters,
      relationGraph: relationGraph ?? this.relationGraph,
      isLoadingRelationGraph:
          isLoadingRelationGraph ?? this.isLoadingRelationGraph,
      relationGraphError:
          clearRelationGraphError
              ? null
              : (relationGraphError ?? this.relationGraphError),
      isLoadingFaceClusters:
          isLoadingFaceClusters ?? this.isLoadingFaceClusters,
      faceClusterError:
          clearFaceClusterError
              ? null
              : (faceClusterError ?? this.faceClusterError),
      photoPage: photoPage ?? this.photoPage,
      favoritePage: favoritePage ?? this.favoritePage,
      photoTotalElements: photoTotalElements ?? this.photoTotalElements,
      favoriteTotalElements:
          favoriteTotalElements ?? this.favoriteTotalElements,
      isLoadingMorePhotos: isLoadingMorePhotos ?? this.isLoadingMorePhotos,
      isLoadingMoreFavorites:
          isLoadingMoreFavorites ?? this.isLoadingMoreFavorites,
      photoRefreshVersion: photoRefreshVersion ?? this.photoRefreshVersion,
      favoriteRefreshVersion:
          favoriteRefreshVersion ?? this.favoriteRefreshVersion,
      photoPageError:
          clearPhotoPageError ? null : (photoPageError ?? this.photoPageError),
      favoritePageError:
          clearFavoritePageError
              ? null
              : (favoritePageError ?? this.favoritePageError),
      timelinePage: timelinePage ?? this.timelinePage,
      timelineTotalElements:
          timelineTotalElements ?? this.timelineTotalElements,
      isLoadingMoreTimeline:
          isLoadingMoreTimeline ?? this.isLoadingMoreTimeline,
      timelinePageError:
          clearTimelinePageError
              ? null
              : (timelinePageError ?? this.timelinePageError),
      groupPage: groupPage ?? this.groupPage,
      groupTotalElements: groupTotalElements ?? this.groupTotalElements,
      isLoadingGroups: isLoadingGroups ?? this.isLoadingGroups,
      isLoadingMoreGroups: isLoadingMoreGroups ?? this.isLoadingMoreGroups,
      groupPageError:
          clearGroupPageError ? null : (groupPageError ?? this.groupPageError),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
