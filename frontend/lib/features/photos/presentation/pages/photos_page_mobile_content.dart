part of 'photos_page.dart';

class _PhotoScrollableContent extends StatelessWidget {
  const _PhotoScrollableContent({
    required this.state,
    required this.onOpenPhoto,
    required this.onOpenAlbum,
    required this.onDeletePhoto,
    required this.onDeleteAlbum,
    required this.onCreateAlbum,
    required this.ref,
  });

  final PhotoCenterState state;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoAlbum> onOpenAlbum;
  final ValueChanged<PhotoItem> onDeletePhoto;
  final ValueChanged<PhotoAlbum> onDeleteAlbum;
  final VoidCallback onCreateAlbum;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (state.surface == PhotoSurface.library)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _MobileLibraryFilterChips(state: state, ref: ref),
          ),
        Expanded(child: _buildTabContent(context)),
      ],
    );
  }

  Widget _buildTabContent(BuildContext context) {
    return switch (state.tab) {
      PhotoTab.all => _PhotoMobileAllSection(
        state: state,
        onOpenPhoto: onOpenPhoto,
        onOpenAlbum: onOpenAlbum,
      ),
      PhotoTab.favorites => _PhotoGrid(
        scrollable: true,
        photos: state.visiblePhotos,
        onOpenPhoto: onOpenPhoto,
        onDeletePhoto: onDeletePhoto,
        emptyMessage: AppLocalizations.of(context).photosNoFavorites,
        emptySubtitle: AppLocalizations.of(context).photosNoFavoritesHint,
        state: state,
        ref: ref,
      ),
      PhotoTab.albums => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: _AlbumGrid(
          albums: state.albums,
          onOpenAlbum: onOpenAlbum,
          onDeleteAlbum: onDeleteAlbum,
          onCreateAlbum: onCreateAlbum,
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// 独立滚动内容区（时间线/分组/星系/人物 tab）— 有自己的滚动容器
class _PhotoIndependentContent extends ConsumerStatefulWidget {
  const _PhotoIndependentContent({
    required this.state,
    required this.onOpenPhoto,
    required this.onOpenAlbum,
  });

  final PhotoCenterState state;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoAlbum> onOpenAlbum;

  @override
  ConsumerState<_PhotoIndependentContent> createState() =>
      _PhotoIndependentContentState();
}

class _PhotoIndependentContentState
    extends ConsumerState<_PhotoIndependentContent> {
  bool _showGroups = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        if (widget.state.surface == PhotoSurface.explore)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.timeline_rounded, size: 16),
                  label: Text(l10n.photosTabTimeline),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.folder_copy_outlined, size: 16),
                  label: Text(l10n.photosTabGroups),
                ),
              ],
              selected: {_showGroups},
              onSelectionChanged: (v) => setState(() => _showGroups = v.first),
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        Expanded(
          child:
              _showGroups
                  ? PhotoGroupView(
                    onOpenPhoto: widget.onOpenPhoto,
                    state: widget.state,
                  )
                  : PhotoTimelineView(
                    onOpenPhoto: widget.onOpenPhoto,
                    state: widget.state,
                  ),
        ),
      ],
    );
  }
}

/// 移动端"全部"页面 — 最近照片六宫格 + 影集横向滚动
class _PhotoMobileAllSection extends ConsumerWidget {
  const _PhotoMobileAllSection({
    required this.state,
    required this.onOpenPhoto,
    required this.onOpenAlbum,
  });

  final PhotoCenterState state;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoAlbum> onOpenAlbum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentPhotos = state.photos.take(6).toList();
    final albums = state.albums;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 最近照片六宫格
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                AppLocalizations.of(context).photosRecentPhotos,
                style: TextStyle(
                  color: context.mobileColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/photos/browse'),
                child: Text(
                  AppLocalizations.of(context).photosViewAll,
                  style: TextStyle(
                    color: context.mobileColors.musicAccent,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (recentPhotos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 40,
                    color: context.mobileColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context).photosNoPhotos,
                    style: TextStyle(
                      color: context.mobileColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: recentPhotos.length,
              itemBuilder: (context, index) {
                final photo = recentPhotos[index];
                return PhotoGridTile(
                  key: ValueKey(photo.id),
                  photo: photo,
                  onTap: () => onOpenPhoto(photo),
                );
              },
            ),
          ),
        const SizedBox(height: 24),
        // 影集横向滚动
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Text(
                AppLocalizations.of(context).photosAlbums,
                style: TextStyle(
                  color: context.mobileColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed:
                    () => ref
                        .read(photoCenterControllerProvider.notifier)
                        .selectTab(PhotoTab.albums),
                child: Text(
                  AppLocalizations.of(context).photosViewAll,
                  style: TextStyle(
                    color: context.mobileColors.musicAccent,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (albums.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_album_outlined,
                    size: 40,
                    color: context.mobileColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context).photosNoAlbums,
                    style: TextStyle(
                      color: context.mobileColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 176,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                return _AlbumHorizontalCard(
                  album: album,
                  onTap: () => onOpenAlbum(album),
                );
              },
            ),
          ),
        const SizedBox(height: 40),
      ],
    );
  }
}

/// 横向滚动的影集卡片
class _AlbumHorizontalCard extends StatelessWidget {
  const _AlbumHorizontalCard({required this.album, required this.onTap});

  final PhotoAlbum album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: context.mobileColors.surfaceRaised,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (album.coverUrl != null && album.coverUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: album.coverUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 200,
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.name,
                      style: TextStyle(
                        color: context.mobileColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(
                        context,
                      ).photosAlbumPhotoCount(album.photoCount),
                      style: TextStyle(
                        color: context.mobileColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 主内容区

/// 移动端 Library 过滤芯片：全部/收藏/相册/分组。
class _MobileLibraryFilterChips extends ConsumerWidget {
  const _MobileLibraryFilterChips({required this.state, required this.ref});

  final PhotoCenterState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef buildRef) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in [
            PhotoTab.all,
            PhotoTab.favorites,
            PhotoTab.albums,
            PhotoTab.groups,
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: state.tab == tab,
                onSelected: (_) {
                  buildRef
                      .read(photoCenterControllerProvider.notifier)
                      .selectTab(tab);
                },
                label: Text(switch (tab) {
                  PhotoTab.all => l10n.photosTabHome,
                  PhotoTab.favorites => l10n.photosTabFavorites,
                  PhotoTab.albums => l10n.photosTabAlbums,
                  PhotoTab.groups => l10n.photosTabGroups,
                  _ => '',
                }),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
        ],
      ),
    );
  }
}

/// 人物表面：人脸聚类网格与关系图谱的可切换视图。
class _PeopleSurfaceContent extends ConsumerStatefulWidget {
  const _PeopleSurfaceContent({
    required this.state,
    required this.onOpenPhoto,
    required this.onOpenAlbum,
  });

  final PhotoCenterState state;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoAlbum> onOpenAlbum;

  @override
  ConsumerState<_PeopleSurfaceContent> createState() =>
      _PeopleSurfaceContentState();
}

class _PeopleSurfaceContentState extends ConsumerState<_PeopleSurfaceContent> {
  bool _showGraph = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                l10n.photosSurfacePeople,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                tooltip: l10n.photosGraphToggle,
                onPressed: () => setState(() => _showGraph = !_showGraph),
                icon: Icon(
                  _showGraph ? Icons.grid_view_rounded : Icons.hub_outlined,
                  color: context.photosColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration:
                MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
            child:
                _showGraph
                    ? PhotoGraphView(
                      key: const ValueKey('graph'),
                      state: widget.state,
                      onOpenPhoto: widget.onOpenPhoto,
                      onOpenAlbum: widget.onOpenAlbum,
                    )
                    : const PhotoFacesPage(key: ValueKey('faces')),
          ),
        ),
      ],
    );
  }
}
