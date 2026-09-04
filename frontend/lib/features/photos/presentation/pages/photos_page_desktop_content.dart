part of 'photos_page.dart';

class _PhotoContent extends ConsumerStatefulWidget {
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
  ConsumerState<_PhotoContent> createState() => _PhotoContentState();
}

class _PhotoContentState extends ConsumerState<_PhotoContent> {
  bool _exploreShowGroups = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final ref = this.ref;
    final onOpenPhoto = widget.onOpenPhoto;
    final onOpenAlbum = widget.onOpenAlbum;
    final onDeletePhoto = widget.onDeletePhoto;
    final onDeleteAlbum = widget.onDeleteAlbum;
    final onCreateAlbum = widget.onCreateAlbum;
    return Column(
      children: [
        // Library 过滤芯片（仅在 library surface 下显示）
        if (state.surface == PhotoSurface.library) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _LibraryFilterChips(state: state),
          ),
          const SizedBox(height: 12),
        ],
        // Explore 时间线/分组切换（仅在 explore surface 下显示）
        if (state.surface == PhotoSurface.explore) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.timeline_rounded, size: 16),
                    label: Text(AppLocalizations.of(context).photosTabTimeline),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.folder_copy_outlined, size: 16),
                    label: Text(AppLocalizations.of(context).photosTabGroups),
                  ),
                ],
                selected: {_exploreShowGroups},
                onSelectionChanged:
                    (v) => setState(() => _exploreShowGroups = v.first),
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        // 回忆横向滚动区域（仅在全部照片模式下显示）
        if (state.tab == PhotoTab.all) ...[
          _MemoriesSection(photos: state.photos),
          const SizedBox(height: 16),
        ],
        Expanded(
          child: AnimatedSwitcher(
            duration: MotionToken.resolve(context, MotionToken.normal),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(state.tab),
              child: switch (state.tab) {
                PhotoTab.all => _PhotoGrid(
                  scrollable: true,
                  photos: state.visiblePhotos,
                  onOpenPhoto: onOpenPhoto,
                  onDeletePhoto: onDeletePhoto,
                  emptyMessage: AppLocalizations.of(context).photosNoPhotos,
                  emptySubtitle:
                      AppLocalizations.of(context).photosNoPhotosHint,
                  state: state,
                  ref: ref,
                ),
                PhotoTab.favorites => _PhotoGrid(
                  scrollable: true,
                  photos: state.visiblePhotos,
                  onOpenPhoto: onOpenPhoto,
                  onDeletePhoto: onDeletePhoto,
                  emptyMessage: AppLocalizations.of(context).photosNoFavorites,
                  emptySubtitle:
                      AppLocalizations.of(context).photosNoFavoritesHint,
                  state: state,
                  ref: ref,
                ),
                PhotoTab.albums => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                  child: _AlbumGrid(
                    albums: state.albums,
                    onOpenAlbum: onOpenAlbum,
                    onDeleteAlbum: onDeleteAlbum,
                    onCreateAlbum: onCreateAlbum,
                  ),
                ),
                PhotoTab.timeline =>
                  _exploreShowGroups
                      ? PhotoGroupView(onOpenPhoto: onOpenPhoto, state: state)
                      : PhotoTimelineView(
                        onOpenPhoto: onOpenPhoto,
                        state: state,
                      ),
                PhotoTab.groups =>
                  _exploreShowGroups
                      ? PhotoGroupView(onOpenPhoto: onOpenPhoto, state: state)
                      : PhotoTimelineView(
                        onOpenPhoto: onOpenPhoto,
                        state: state,
                      ),
                PhotoTab.graph => PhotoGraphView(
                  state: state,
                  onOpenPhoto: onOpenPhoto,
                  onOpenAlbum: onOpenAlbum,
                ),
              },
            ),
          ),
        ),
        // 批量操作栏（进入选择模式时从底部滑入）
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
}

/// 回忆横向滚动区域
class _MemoriesSection extends StatelessWidget {
  const _MemoriesSection({required this.photos});

  final List<PhotoItem> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).photosTabMemories,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: photos.take(10).length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              return _MemoryCard(photo: photo, index: index);
            },
          ),
        ),
      ],
    );
  }
}

/// 回忆卡片
class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.photo, required this.index});

  final PhotoItem photo;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: context.photosColors.surfaceContainerHighest,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo.coverUrl != null && photo.coverUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: photo.coverUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 200,
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, context.photosColors.overlay],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Text(
                photo.title,
                style: TextStyle(
                  color: context.photosColors.mediaOverlayText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 照片网格
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.onOpenPhoto,
    required this.onDeletePhoto,
    required this.emptyMessage,
    required this.emptySubtitle,
    required this.state,
    required this.ref,
    this.scrollable = false,
  });

  final List<PhotoItem> photos;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoItem> onDeletePhoto;
  final String emptyMessage;
  final String emptySubtitle;
  final PhotoCenterState state;
  final WidgetRef ref;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      final empty = AppEmptyState(
        message: emptyMessage,
        icon: Icons.photo_library_outlined,
      );
      return scrollable
          ? empty
          : SizedBox(
            height: MediaQuery.sizeOf(context).height - 120,
            child: empty,
          );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 1600
                ? 7
                : constraints.maxWidth >= 1300
                ? 6
                : constraints.maxWidth >= 1000
                ? 5
                : constraints.maxWidth >= 700
                ? 4
                : constraints.maxWidth >= 500
                ? 3
                : 3;
        final grid = GridView.builder(
          itemCount: photos.length,
          shrinkWrap: !scrollable,
          physics: scrollable ? null : const NeverScrollableScrollPhysics(),
          padding:
              scrollable
                  ? const EdgeInsets.fromLTRB(20, 18, 20, 40)
                  : const EdgeInsets.fromLTRB(16, 16, 16, 40),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final photo = photos[index];
            final isSelectionMode = state.isSelectionMode;
            final isSelected = state.selectedPhotoIds.contains(photo.id);
            return PhotoGridTile(
              key: ValueKey(photo.id),
              photo: photo,
              isSelectionMode: isSelectionMode,
              isSelected: isSelected,
              onDelete: onDeletePhoto,
              onTap: () {
                if (isSelectionMode) {
                  ref
                      .read(photoCenterControllerProvider.notifier)
                      .togglePhotoSelection(photo.id);
                } else {
                  onOpenPhoto(photo);
                }
              },
              onLongPress: () {
                if (!isSelectionMode) {
                  ref
                      .read(photoCenterControllerProvider.notifier)
                      .toggleSelectionMode();
                  ref
                      .read(photoCenterControllerProvider.notifier)
                      .togglePhotoSelection(photo.id);
                }
              },
            );
          },
        );
        if (!scrollable) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              grid,
              if (state.hasMoreVisiblePhotos ||
                  state.isLoadingMoreVisiblePhotos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child:
                      state.isLoadingMoreVisiblePhotos
                          ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : TextButton(
                            onPressed:
                                () =>
                                    ref
                                        .read(
                                          photoCenterControllerProvider
                                              .notifier,
                                        )
                                        .loadMoreVisiblePhotos(),
                            child: Text(
                              AppLocalizations.of(context).photosLoadMore(
                                photos.length,
                                state.visiblePhotoTotalElements,
                              ),
                            ),
                          ),
                ),
              if (_visiblePageError(state) case final error?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.extentAfter < 640) {
              unawaited(
                ref
                    .read(photoCenterControllerProvider.notifier)
                    .loadMoreVisiblePhotos(),
              );
            }
            return false;
          },
          child: Stack(
            children: [
              grid,
              if (state.isLoadingMoreVisiblePhotos)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Center(
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String? _visiblePageError(PhotoCenterState state) {
    return switch (state.tab) {
      PhotoTab.all => state.photoPageError,
      PhotoTab.favorites => state.favoritePageError,
      _ => null,
    };
  }
}

/// 相册网格
class _AlbumGrid extends StatelessWidget {
  const _AlbumGrid({
    required this.albums,
    required this.onOpenAlbum,
    required this.onDeleteAlbum,
    required this.onCreateAlbum,
  });

  final List<PhotoAlbum> albums;
  final ValueChanged<PhotoAlbum> onOpenAlbum;
  final ValueChanged<PhotoAlbum> onDeleteAlbum;
  final VoidCallback onCreateAlbum;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 1200
                ? 5
                : constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 600
                ? 3
                : 2;
        final itemCount = albums.length + 1; // +1 for create button
        return GridView.builder(
          itemCount: itemCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) {
            if (index == albums.length) {
              return _CreateAlbumTile(onTap: onCreateAlbum);
            }
            final album = albums[index];
            return PhotoAlbumCard(
              album: album,
              onTap: () => onOpenAlbum(album),
              onLongPress: () => onDeleteAlbum(album),
            );
          },
        );
      },
    );
  }
}

/// 新建相册按钮
class _CreateAlbumTile extends StatelessWidget {
  const _CreateAlbumTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: context.photosColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: context.photosColors.outlineVariant.withValues(
                alpha: 0.24,
              ),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.photosColors.primaryContainer.withValues(
                    alpha: 0.14,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: context.photosColors.primaryContainer,
                  size: 24,
                ),
              ),
              SizedBox(height: 10),
              Text(
                AppLocalizations.of(context).photosNewAlbum,
                style: TextStyle(
                  color: context.photosColors.primaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 批量操作底部栏

/// Library 表面的过滤芯片行：切换全部/收藏/相册/分组。
class _LibraryFilterChips extends ConsumerWidget {
  const _LibraryFilterChips({required this.state});

  final PhotoCenterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final tab in [
          PhotoTab.all,
          PhotoTab.favorites,
          PhotoTab.albums,
          PhotoTab.groups,
        ])
          FilterChip(
            selected: state.tab == tab,
            onSelected: (_) {
              ref.read(photoCenterControllerProvider.notifier).selectTab(tab);
            },
            label: Text(switch (tab) {
              PhotoTab.all => l10n.photosTabHome,
              PhotoTab.favorites => l10n.photosTabFavorites,
              PhotoTab.albums => l10n.photosTabAlbums,
              PhotoTab.groups => l10n.photosTabGroups,
              _ => '',
            }),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
      ],
    );
  }
}
