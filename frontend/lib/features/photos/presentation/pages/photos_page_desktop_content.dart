part of 'photos_page.dart';

class _PhotoContent extends ConsumerWidget {
  const _PhotoContent({
    required this.state,
    required this.onOpenPhoto,
    required this.onOpenAlbum,
    required this.onDeletePhoto,
    required this.onDeleteAlbum,
    required this.onCreateAlbum,
  });

  final PhotoCenterState state;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoAlbum> onOpenAlbum;
  final ValueChanged<PhotoItem> onDeletePhoto;
  final ValueChanged<PhotoAlbum> onDeleteAlbum;
  final VoidCallback onCreateAlbum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
          child: _LibraryFilterChips(state: state),
        ),
        if (state.libraryView == PhotoLibraryView.gridDay ||
            state.libraryView == PhotoLibraryView.gridMonth)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
            child: _DesktopAlbumShelf(
              state: state,
              onOpenAlbum: onOpenAlbum,
              onDeleteAlbum: onDeleteAlbum,
              onCreateAlbum: onCreateAlbum,
            ),
          ),
        Expanded(child: _buildViewContent(context, ref)),
        if (state.isSelectionMode && state.selectedPhotoIds.isNotEmpty)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration:
                MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            builder:
                (context, t, child) => Transform.translate(
                  offset: Offset(0, t * 72),
                  child: Opacity(opacity: 1 - t, child: child),
                ),
            child: _BatchActionBar(state: state, ref: ref),
          ),
      ],
    );
  }

  Widget _buildViewContent(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isFavorites = state.tab == PhotoTab.favorites;
    return AnimatedSwitcher(
      duration:
          MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
      child: switch (state.libraryView) {
        PhotoLibraryView.gridDay => PhotoDateGrid(
          key: const ValueKey('grid-day'),
          photos: state.visiblePhotos,
          grouping: PhotoDateGrouping.day,
          onOpenPhoto: onOpenPhoto,
          onDeletePhoto: onDeletePhoto,
          emptyMessage:
              isFavorites ? l10n.photosNoFavorites : l10n.photosNoPhotos,
          emptySubtitle:
              isFavorites
                  ? l10n.photosNoFavoritesHint
                  : l10n.photosNoPhotosHint,
        ),
        PhotoLibraryView.gridMonth => PhotoDateGrid(
          key: const ValueKey('grid-month'),
          photos: state.visiblePhotos,
          grouping: PhotoDateGrouping.month,
          onOpenPhoto: onOpenPhoto,
          onDeletePhoto: onDeletePhoto,
          emptyMessage:
              isFavorites ? l10n.photosNoFavorites : l10n.photosNoPhotos,
          emptySubtitle:
              isFavorites
                  ? l10n.photosNoFavoritesHint
                  : l10n.photosNoPhotosHint,
        ),
        PhotoLibraryView.timeline => PhotoTimelineView(
          key: const ValueKey('timeline'),
          onOpenPhoto: onOpenPhoto,
          state: state,
        ),
        PhotoLibraryView.groups => PhotoGroupView(
          key: const ValueKey('groups'),
          onOpenPhoto: onOpenPhoto,
          state: state,
        ),
      },
    );
  }
}

/// 图库数据源芯片：全部 / 收藏，带结果计数。
class _LibraryFilterChips extends ConsumerWidget {
  const _LibraryFilterChips({required this.state});

  final PhotoCenterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.photosColors;
    Widget chip(
      PhotoTab tab, {
      required String label,
      required int count,
      IconData? icon,
    }) {
      final selected = state.tab == tab;
      return FilterChip(
        selected: selected,
        onSelected: (_) {
          ref.read(photoCenterControllerProvider.notifier).selectTab(tab);
        },
        showCheckmark: false,
        avatar:
            icon == null
                ? null
                : Icon(
                  icon,
                  size: 16,
                  color:
                      selected
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                ),
        label: Text('$label · $count'),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        chip(
          PhotoTab.all,
          label: l10n.photosAll,
          count: state.photoTotalElements,
        ),
        chip(
          PhotoTab.favorites,
          label: l10n.photosTabFavorites,
          count: state.favoriteTotalElements,
          icon: Icons.favorite_rounded,
        ),
      ],
    );
  }
}

/// 桌面相册货架：横向相册卡片 + 管理与新建入口。
class _DesktopAlbumShelf extends StatelessWidget {
  const _DesktopAlbumShelf({
    required this.state,
    required this.onOpenAlbum,
    required this.onDeleteAlbum,
    required this.onCreateAlbum,
  });

  final PhotoCenterState state;
  final ValueChanged<PhotoAlbum> onOpenAlbum;
  final ValueChanged<PhotoAlbum> onDeleteAlbum;
  final VoidCallback onCreateAlbum;

  @override
  Widget build(BuildContext context) {
    final albums = state.albums;
    final colors = context.photosColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.photo_album_outlined,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              AppLocalizations.of(context).photosAlbums,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              ' (${albums.length})',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => context.push('/photos/albums'),
              icon: const Icon(Icons.settings_rounded, size: 16),
              label: Text(AppLocalizations.of(context).photosAlbumsManage),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 170,
          child:
              albums.isEmpty
                  ? Row(
                    children: [
                      CreateAlbumTile(onTap: onCreateAlbum),
                      const SizedBox(width: 12),
                      Text(
                        AppLocalizations.of(context).photosNoAlbums,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  )
                  : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: albums.length + 1,
                    itemBuilder: (context, index) {
                      if (index == albums.length) {
                        return SizedBox(
                          width: 150,
                          child: CreateAlbumTile(onTap: onCreateAlbum),
                        );
                      }
                      final album = albums[index];
                      return SizedBox(
                        width: 150,
                        child: PhotoAlbumCard(
                          album: album,
                          onTap: () => onOpenAlbum(album),
                          onLongPress: () => onDeleteAlbum(album),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
