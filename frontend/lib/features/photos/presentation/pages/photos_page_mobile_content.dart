part of 'photos_page.dart';

/// 移动端图库主表面：过滤芯片 + 相册区 + 日期网格单流滚动。
class _PhotoLibrarySurface extends ConsumerStatefulWidget {
  const _PhotoLibrarySurface({
    required this.state,
    required this.hosted,
    required this.onOpenPhoto,
    required this.onOpenAlbum,
    required this.onDeletePhoto,
  });

  final PhotoCenterState state;
  final bool hosted;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoAlbum> onOpenAlbum;
  final ValueChanged<PhotoItem> onDeletePhoto;

  @override
  ConsumerState<_PhotoLibrarySurface> createState() =>
      _PhotoLibrarySurfaceState();
}

class _PhotoLibrarySurfaceState extends ConsumerState<_PhotoLibrarySurface> {
  bool _chipsCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = widget.state;
    return Column(
      children: [
        if (widget.hosted)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.photosSurfaceLibrary,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        AnimatedSize(
          duration:
              MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child:
              _chipsCollapsed
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: _MobileLibraryFilterChips(state: state, ref: ref),
                    ),
                  ),
        ),
        Expanded(
          child: RefreshIndicator(
            displacement: 48,
            strokeWidth: 2.5,
            color: context.photosColors.primaryContainer,
            onRefresh:
                () =>
                    ref.read(photoCenterControllerProvider.notifier).refresh(),
            child: switch (state.libraryView) {
              PhotoLibraryView.gridDay ||
              PhotoLibraryView.gridMonth => PhotoDateGrid(
                photos: state.visiblePhotos,
                grouping:
                    state.libraryView == PhotoLibraryView.gridMonth
                        ? PhotoDateGrouping.month
                        : PhotoDateGrouping.day,
                onOpenPhoto: widget.onOpenPhoto,
                onDeletePhoto: widget.onDeletePhoto,
                emptyMessage:
                    state.tab == PhotoTab.favorites
                        ? l10n.photosNoFavorites
                        : l10n.photosNoPhotos,
                emptySubtitle:
                    state.tab == PhotoTab.favorites
                        ? l10n.photosNoFavoritesHint
                        : l10n.photosNoPhotosHint,
                leadingSlivers: _albumLeadingSlivers(context),
                onScrollOffsetChanged: (offset) {
                  final collapsed = offset > 200;
                  if (collapsed != _chipsCollapsed) {
                    setState(() => _chipsCollapsed = collapsed);
                  }
                },
                showScrollToTop: true,
              ),
              PhotoLibraryView.timeline => PhotoTimelineView(
                onOpenPhoto: widget.onOpenPhoto,
                state: state,
              ),
              PhotoLibraryView.groups => PhotoGroupView(
                onOpenPhoto: widget.onOpenPhoto,
                state: state,
              ),
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _albumLeadingSlivers(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final albums = widget.state.albums;
    final topAlbums = albums.take(3).toList();
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              Icon(
                Icons.photo_album_outlined,
                size: 18,
                color: context.photosColors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                '${l10n.photosAlbums} (${albums.length})',
                style: TextStyle(
                  color: context.photosColors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.push('/photos/albums'),
                icon: const Icon(Icons.unfold_more_rounded, size: 15),
                label: Text(l10n.photosExpandAlbums),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
            ],
          ),
        ),
      ),
      if (topAlbums.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              l10n.photosNoAlbums,
              style: TextStyle(
                color: context.photosColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
        )
      else
        SliverToBoxAdapter(
          child: Column(
            children: [
              for (final album in topAlbums)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    color: context.photosColors.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: context.photosColors.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child:
                              album.coverUrl != null &&
                                      album.coverUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                    imageUrl: album.coverUrl!,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 120,
                                  )
                                  : ColoredBox(
                                    color:
                                        context
                                            .photosColors
                                            .surfaceContainerHighest,
                                    child: Icon(
                                      Icons.photo_album_outlined,
                                      color:
                                          context.photosColors.onSurfaceVariant,
                                    ),
                                  ),
                        ),
                      ),
                      title: Text(
                        album.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        l10n.photosAlbumPhotoCount(album.photoCount),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => widget.onOpenAlbum(album),
                    ),
                  ),
                ),
            ],
          ),
        ),
    ];
  }
}

/// 移动端 Library 过滤芯片：全部 / 收藏。
class _MobileLibraryFilterChips extends ConsumerWidget {
  const _MobileLibraryFilterChips({required this.state, required this.ref});

  final PhotoCenterState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef buildRef) {
    final l10n = AppLocalizations.of(context);
    Widget chip(PhotoTab tab, {required String label, IconData? icon}) {
      final selected = state.tab == tab;
      return FilterChip(
        selected: selected,
        onSelected: (_) {
          buildRef.read(photoCenterControllerProvider.notifier).selectTab(tab);
        },
        showCheckmark: false,
        avatar:
            icon == null
                ? null
                : Icon(
                  icon,
                  size: 15,
                  color:
                      selected
                          ? context.photosColors.onPrimaryContainer
                          : context.photosColors.onSurfaceVariant,
                ),
        label: Text(label),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(PhotoTab.all, label: l10n.photosAll),
          const SizedBox(width: 8),
          chip(
            PhotoTab.favorites,
            label: l10n.photosTabFavorites,
            icon: Icons.favorite_rounded,
          ),
        ],
      ),
    );
  }
}
