part of 'photos_page.dart';

/// Frame 视图内容分发：网格、时间线、地点、标签、影集与回收站。
///
/// 地点、标签与回收站的完整交互在后续批次实现，当前提供 Frame 风格空态。
class _FrameViewContent extends ConsumerWidget {
  const _FrameViewContent({
    required this.state,
    required this.compact,
    required this.onOpenPhoto,
    required this.onOpenAlbum,
    required this.onDeletePhoto,
    required this.onDeleteAlbum,
    required this.onCreateAlbum,
  });

  final PhotoCenterState state;
  final bool compact;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoAlbum> onOpenAlbum;
  final ValueChanged<PhotoItem> onDeletePhoto;
  final ValueChanged<PhotoAlbum> onDeleteAlbum;
  final VoidCallback onCreateAlbum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedSwitcher(
      duration:
          MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
      child: switch (state.frameView) {
        FrameView.grid => _buildGrid(context, ref),
        FrameView.timeline => PhotoTimelineView(
          key: const ValueKey('frame-timeline'),
          onOpenPhoto: onOpenPhoto,
          state: state,
        ),
        FrameView.locations => FrameEmptyView(
          key: const ValueKey('frame-locations'),
          icon: Icons.place_outlined,
          message: AppLocalizations.of(context).photosFrameLocationsEmpty,
          hint: AppLocalizations.of(context).photosFrameLocationsEmptyHint,
        ),
        FrameView.tags => FrameEmptyView(
          key: const ValueKey('frame-tags'),
          icon: Icons.sell_outlined,
          message: AppLocalizations.of(context).photosFrameTagsEmpty,
          hint: AppLocalizations.of(context).photosFrameTagsEmptyHint,
        ),
        FrameView.albums => _buildAlbums(context),
        FrameView.trash => FrameEmptyView(
          key: const ValueKey('frame-trash'),
          icon: Icons.delete_outlined,
          message: AppLocalizations.of(context).photosFrameTrashEmpty,
          hint: AppLocalizations.of(context).photosFrameTrashEmptyHint,
        ),
      },
    );
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final grid = PhotoDateGrid(
      key: const ValueKey('frame-grid'),
      photos: state.visiblePhotos,
      grouping: PhotoDateGrouping.day,
      onOpenPhoto: onOpenPhoto,
      onDeletePhoto: onDeletePhoto,
      emptyMessage: l10n.photosNoPhotos,
      emptySubtitle: l10n.photosNoPhotosHint,
      showScrollToTop: compact,
    );
    if (!compact) {
      return grid;
    }
    return RefreshIndicator(
      displacement: 48,
      strokeWidth: 2.5,
      color: FramePalette.accent,
      onRefresh:
          () => ref.read(photoCenterControllerProvider.notifier).refresh(),
      child: grid,
    );
  }

  Widget _buildAlbums(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CustomScrollView(
      key: const ValueKey('frame-albums'),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.photosAlbums,
                style: const TextStyle(
                  fontFamily: FramePalette.serifFamily,
                  color: FramePalette.ink,
                  fontSize: 22,
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          sliver: SliverToBoxAdapter(
            child: PhotoAlbumGrid(
              albums: state.albums,
              onOpenAlbum: onOpenAlbum,
              onDeleteAlbum: onDeleteAlbum,
              onCreateAlbum: onCreateAlbum,
            ),
          ),
        ),
      ],
    );
  }
}
