# -*- coding: utf-8 -*-
"""幻灯片动态范围 + 详情页范围感知导航/预取 + 关闭按钮样式。"""
import io


def load(p):
    return io.open(p, encoding='utf-8').read()


def save(p, s):
    io.open(p, 'w', encoding='utf-8', newline='').write(s)


def rep(s, old, new, what):
    assert old in s, 'NOT FOUND [' + what + ']: ' + old[:90]
    return s.replace(old, new, 1)

# ── 1) 浏览范围 Provider ──
p = 'lib/features/photos/application/photo_controller.dart'
s = load(p)
s = rep(s, """/// 照片详情页信息面板的展开状态；在上一张/下一张切换间保持。""",
"""/// 当前浏览的照片序列：详情页的上一张/下一张与幻灯片范围来源。
///
/// 由各浏览视图（全部照片、收藏、时间线、影集详情等）在用户打开照片时写入。
class PhotoBrowseScopeNotifier extends Notifier<List<PhotoItem>> {
  @override
  List<PhotoItem> build() => const [];

  void set(List<PhotoItem> photos) => state = List.unmodifiable(photos);
}

final photoBrowseScopeProvider =
    NotifierProvider<PhotoBrowseScopeNotifier, List<PhotoItem>>(
      PhotoBrowseScopeNotifier.new,
    );

/// 照片详情页信息面板的展开状态；在上一张/下一张切换间保持。""", 'scope provider')
save(p, s)
print('provider ok')

# ── 2) 视图接线：网格/收藏/时间线 ──
p = 'lib/features/photos/presentation/pages/photos_page_view_content.dart'
s = load(p)
s = rep(s, """  Widget _buildGrid(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isFavorites = state.tab == PhotoTab.favorites;
    final grid = FrameMasonryGrid(
      key: ValueKey(isFavorites ? 'frame-grid-favorites' : 'frame-grid-all'),
      photos: state.visiblePhotos,
      onOpenPhoto: onOpenPhoto,""",
"""  Widget _buildGrid(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isFavorites = state.tab == PhotoTab.favorites;
    final grid = FrameMasonryGrid(
      key: ValueKey(isFavorites ? 'frame-grid-favorites' : 'frame-grid-all'),
      photos: state.visiblePhotos,
      onOpenPhoto: (photo) {
        // 记录浏览范围：详情页的上一张/下一张与幻灯片以该序列为准。
        ref.read(photoBrowseScopeProvider.notifier).set(state.visiblePhotos);
        onOpenPhoto(photo);
      },""", 'grid scope')

s = rep(s, """        FrameView.timeline => PhotoTimelineView(
          key: const ValueKey('frame-timeline'),
          onOpenPhoto: onOpenPhoto,
          state: state,
        ),""",
"""        FrameView.timeline => PhotoTimelineView(
          key: const ValueKey('frame-timeline'),
          onOpenPhoto: (photo) {
            // 时间线的浏览范围为当前已加载的各月份预览照片。
            final timeline = state.timeline;
            if (timeline != null) {
              final previews = <PhotoItem>[
                for (final year in timeline.years)
                  for (final month in year.months) ...month.previewPhotos,
              ];
              ref.read(photoBrowseScopeProvider.notifier).set(previews);
            }
            onOpenPhoto(photo);
          },
          state: state,
        ),""", 'timeline scope')
save(p, s)
print('view content ok')

# ── 3) 影集详情：范围 = 相册照片 ──
p = 'lib/features/photos/presentation/pages/photo_album_detail_page.dart'
s = load(p)
s = rep(s, """                                return PhotoGridTile(
                                  key: ValueKey(photo.id),
                                  photo: photo,
                                  onTap:
                                      () => context.push('/photos/${photo.id}'),""",
"""                                return PhotoGridTile(
                                  key: ValueKey(photo.id),
                                  photo: photo,
                                  onTap: () {
                                    // 浏览范围 = 当前相册的照片序列。
                                    ref
                                        .read(photoBrowseScopeProvider.notifier)
                                        .set(photos);
                                    context.push('/photos/${photo.id}');
                                  },""", 'album scope')
save(p, s)
print('album ok')

# ── 4) 详情页：范围感知的相邻照片 + 幻灯片范围 + 预取 ──
p = 'lib/features/photos/presentation/pages/photo_detail_page.dart'
s = load(p)

s = rep(s, """  /// 在当前照片列表中找到相邻照片 ID，返回 null 表示无相邻照片。
  String? _adjacentPhotoId(PhotoItem photo, int offset) {
    final centerState = ref.read(photoCenterControllerProvider).asData?.value;
    if (centerState == null) return null;
    final list = centerState.photos;
    final index = list.indexWhere((p) => p.id == photo.id);
    if (index < 0) return null;
    final target = index + offset;
    if (target < 0 || target >= list.length) return null;
    return list[target].id;
  }

  void _navigateToAdjacent(PhotoItem photo, int offset) {
    final targetId = _adjacentPhotoId(photo, offset);
    if (targetId == null || !mounted) return;
    context.pushReplacement('/photos/$targetId');
  }""",
"""  /// 当前浏览范围：浏览视图打开照片时写入；未写入时回退为全部照片。
  List<PhotoItem> _browseScope(PhotoItem photo) {
    final centerState = ref.read(photoCenterControllerProvider).asData?.value;
    final scope = ref.read(photoBrowseScopeProvider);
    if (scope.length > 1 && scope.any((item) => item.id == photo.id)) {
      return scope;
    }
    return centerState?.photos ?? const <PhotoItem>[];
  }

  /// 在当前浏览范围中找到相邻照片 ID，返回 null 表示无相邻照片。
  String? _adjacentPhotoId(PhotoItem photo, int offset) {
    final list = _browseScope(photo);
    final index = list.indexWhere((p) => p.id == photo.id);
    if (index < 0) return null;
    final target = index + offset;
    if (target < 0 || target >= list.length) return null;
    return list[target].id;
  }

  void _navigateToAdjacent(PhotoItem photo, int offset) {
    final targetId = _adjacentPhotoId(photo, offset);
    if (targetId == null || !mounted) return;
    unawaited(_goToAdjacentPhoto(targetId));
  }

  /// 预取目标详情后再替换路由，避免切换时出现加载动画。
  Future<void> _goToAdjacentPhoto(String targetId) async {
    try {
      await ref.read(photoDetailProvider(targetId).future);
    } on Exception {
      // 预取失败时照常跳转，由目标页面展示错误。
    }
    if (!mounted) return;
    context.pushReplacement('/photos/$targetId');
  }""", 'scope-aware nav')

s = rep(s, """  /// 幻灯片播放当前可见照片全集，从当前照片开始。
  Map<String, dynamic> _slideshowExtra(PhotoItem photo) {
    final state = ref.read(photoCenterControllerProvider).asData?.value;
    final visible = state?.visiblePhotos ?? const <PhotoItem>[];
    final photos = visible.isNotEmpty ? visible : <PhotoItem>[photo];
    final index = photos.indexWhere((item) => item.id == photo.id);
    return {
      'photos': photos,
      'initialIndex': index < 0 ? 0 : index,
    };
  }""",
"""  /// 幻灯片播放当前浏览范围的照片全集，从当前照片开始。
  Map<String, dynamic> _slideshowExtra(PhotoItem photo) {
    var photos = _browseScope(photo);
    if (photos.isEmpty) {
      photos = <PhotoItem>[photo];
    }
    final index = photos.indexWhere((item) => item.id == photo.id);
    return {
      'photos': photos,
      'initialIndex': index < 0 ? 0 : index,
    };
  }""", 'slideshow scope')
save(p, s)
print('detail ok')

# ── 5) 关闭按钮样式：与查看器箭头一致的描边胶囊 ──
p = 'lib/features/photos/presentation/widgets/slideshow_controls.dart'
s = load(p)
s = rep(s, """        // 顶部关闭按钮
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            tooltip: AppLocalizations.of(context).coreClose,
            onPressed: onClose,
            icon: Icon(
              Icons.close_rounded,
              color: context.photosColors.slideshowText,
              size: 28,
            ),
            style: IconButton.styleFrom(
              backgroundColor: context.photosColors.badgeBg,
              padding: const EdgeInsets.all(8),
            ),
          ),
        ),""",
"""        // 顶部关闭按钮：与查看器箭头一致的描边方块
        Positioned(
          top: 16,
          right: 16,
          child: Material(
            color: Colors.black.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onClose,
              child: Tooltip(
                message: AppLocalizations.of(context).coreClose,
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.close_rounded,
                    size: 22,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ),
          ),
        ),""", 'close button')
save(p, s)
print('close ok')
