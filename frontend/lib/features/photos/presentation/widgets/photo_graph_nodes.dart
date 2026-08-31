part of 'photo_graph_view.dart';

class _GraphFilterBar extends StatelessWidget {
  const _GraphFilterBar({
    required this.enabledKinds,
    required this.onToggle,
    required this.isLoading,
  });

  final Set<PhotoRelationNodeType> enabledKinds;
  final ValueChanged<PhotoRelationNodeType> onToggle;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.photosColors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final type in PhotoRelationNodeType.values)
          FilterChip(
            selected: enabledKinds.contains(type),
            onSelected: (_) => onToggle(type),
            label: Text(_kindLabel(l10n, type)),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
        if (isLoading) ...[
          const SizedBox(width: 4),
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primaryContainer,
            ),
          ),
        ],
      ],
    );
  }
}

String _kindLabel(AppLocalizations l10n, PhotoRelationNodeType type) {
  return switch (type) {
    PhotoRelationNodeType.album => l10n.photosGraphKindAlbum,
    PhotoRelationNodeType.time => l10n.photosGraphKindTime,
    PhotoRelationNodeType.location => l10n.photosGraphKindLocation,
    PhotoRelationNodeType.person => l10n.photosGraphKindPerson,
  };
}

String _nodeCountLabel(AppLocalizations l10n, PhotoGraphNode node) {
  return switch (node.type) {
    PhotoRelationNodeType.person => l10n.photosGraphFaceCount(node.weight),
    _ => l10n.photosGraphPhotoCount(node.weight),
  };
}

class _GraphSearchStatus extends StatelessWidget {
  const _GraphSearchStatus({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.photosColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 17, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.photosGraphSearchActive(query),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphNodeChip extends StatelessWidget {
  const _GraphNodeChip({
    required this.node,
    required this.radius,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
  });

  final PhotoGraphNode node;
  final double radius;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.photosColors;
    final color = switch (node.type) {
      PhotoRelationNodeType.album => colors.primaryContainer,
      PhotoRelationNodeType.time => colors.tertiary,
      PhotoRelationNodeType.location => colors.success,
      PhotoRelationNodeType.person => colors.onSurfaceVariant,
    };
    final child =
        node.coverUrl?.isNotEmpty == true
            ? CachedNetworkImage(
              imageUrl: node.coverUrl!,
              fit: BoxFit.cover,
              width: radius * 2,
              height: radius * 2,
              memCacheWidth: 160,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              errorWidget: (_, _, _) => _placeholder(colors),
              placeholder: (_, _) => _placeholder(colors),
            )
            : _placeholder(colors);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Tooltip(
              message: node.label,
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: selected ? 1 : 0.7),
                    width: selected ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: selected ? 0.32 : 0.14),
                      blurRadius: selected ? 18 : 8,
                      spreadRadius: selected ? 1 : 0,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
          ),
          SizedBox(
            width: radius * 2 + 24,
            child: Text(
              node.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(PhotosColors colors) {
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.hub_outlined,
          color: colors.onSurfaceVariant,
          size: radius * 0.6,
        ),
      ),
    );
  }
}

class _GraphEmptyState extends StatelessWidget {
  const _GraphEmptyState({
    required this.isLoading,
    required this.hasSearch,
    this.onRetry,
  });

  final bool isLoading;
  final bool hasSearch;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.photosColors;
    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 100),
        child: Center(
          child: CircularProgressIndicator(color: colors.primaryContainer),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 90),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hub_outlined, size: 52, color: colors.onSurfaceVariant),
          const SizedBox(height: 14),
          Text(
            hasSearch ? l10n.photosGraphNoSearchResults : l10n.photosGraphEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: Text(l10n.coreRetry),
            ),
          ],
        ],
      ),
    );
  }
}

class _GraphDetail extends ConsumerStatefulWidget {
  const _GraphDetail({
    super.key,
    required this.node,
    required this.onBack,
    required this.onOpenPhoto,
    this.onOpenAlbum,
  });

  final PhotoGraphNode node;
  final VoidCallback onBack;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoAlbum>? onOpenAlbum;

  @override
  ConsumerState<_GraphDetail> createState() => _GraphDetailState();
}

class _GraphDetailState extends ConsumerState<_GraphDetail> {
  static const _chunkSize = 120;

  List<PhotoItem> _photos = const [];
  String? _error;
  bool _loading = false;
  int _loadGeneration = 0;
  int _visibleCount = _chunkSize;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPhotos());
  }

  @override
  void didUpdateWidget(covariant _GraphDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _visibleCount = _chunkSize;
      unawaited(_loadPhotos());
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }

  bool _isCurrent(int generation) {
    return mounted && generation == _loadGeneration;
  }

  Future<void> _loadPhotos() async {
    final generation = ++_loadGeneration;
    final node = widget.node;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _photos = const [];
      });
    }
    try {
      final photos = await _loadNodePhotos(node);
      if (!_isCurrent(generation)) return;
      setState(() {
        _photos = photos;
        _loading = false;
      });
    } catch (error) {
      if (!_isCurrent(generation)) return;
      setState(() {
        _loading = false;
        _error = describeUserFacingError(error).displayMessage;
      });
    }
  }

  Future<List<PhotoItem>> _loadNodePhotos(PhotoGraphNode node) async {
    switch (node.type) {
      case PhotoRelationNodeType.album:
        return (await ref.read(
          photoAlbumDetailProvider(node.key).future,
        )).photos;
      case PhotoRelationNodeType.person:
        return ref
            .read(photoCenterControllerProvider.notifier)
            .getPhotosByCluster(node.key);
      case PhotoRelationNodeType.time:
      case PhotoRelationNodeType.location:
        await ref
            .read(photoCenterControllerProvider.notifier)
            .loadGroups(
              node.type == PhotoRelationNodeType.time
                  ? GroupBy.date
                  : GroupBy.location,
            );
        final state = ref.read(photoCenterControllerProvider).asData?.value;
        final photos =
            state?.groups
                ?.where((group) => group.groupKey == node.key)
                .expand((group) => group.photos)
                .toList(growable: false) ??
            const <PhotoItem>[];
        return photos;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.photosColors;
    final title =
        widget.node.label.trim().isEmpty
            ? switch (widget.node.type) {
              PhotoRelationNodeType.album => l10n.photosGraphUnnamedAlbum,
              PhotoRelationNodeType.person => l10n.photosGraphUnnamedPerson,
              _ => widget.node.key,
            }
            : widget.node.label;
    final countLabel = _nodeCountLabel(l10n, widget.node);
    final visiblePhotos = _photos.take(_visibleCount).toList(growable: false);
    final compact = MediaQuery.sizeOf(context).width < 520;
    final size = compact ? 68.0 : 82.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: widget.onBack,
              tooltip: l10n.photosGraphBack,
              icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (widget.node.type == PhotoRelationNodeType.album &&
                widget.onOpenAlbum != null)
              TextButton.icon(
                onPressed: () {
                  final albumId = widget.node.key;
                  if (albumId.isEmpty) return;
                  widget.onOpenAlbum!(
                    PhotoAlbum(
                      id: albumId,
                      name: title,
                      description: '',
                      photoCount: widget.node.weight,
                      createdAt: null,
                      updatedAt: null,
                      coverUrl: widget.node.coverUrl,
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(l10n.photosGraphOpenAlbum),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 52, bottom: 16),
          child: Text(
            countLabel,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
        ),
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 80),
            child: Center(
              child: CircularProgressIndicator(color: colors.primaryContainer),
            ),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 80),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => unawaited(_loadPhotos()),
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: Text(l10n.coreRetry),
                ),
              ],
            ),
          )
        else if (visiblePhotos.isEmpty)
          const _GraphEmptyState(isLoading: false, hasSearch: false)
        else
          Wrap(
            alignment: WrapAlignment.center,
            spacing: compact ? 16 : 26,
            runSpacing: 22,
            children: [
              for (final photo in visiblePhotos)
                _GraphPlanet(
                  photo: photo,
                  size: photo.favorite ? size * 1.18 : size,
                  onOpen: () => widget.onOpenPhoto(photo),
                ),
            ],
          ),
        if (_photos.length > visiblePhotos.length) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: () {
                if (mounted) {
                  setState(() => _visibleCount += _chunkSize);
                }
              },
              child: Text(l10n.photosGraphLoadMore),
            ),
          ),
        ],
        if (_photos.length > _chunkSize) ...[
          const SizedBox(height: 10),
          Text(
            l10n.photosGraphShowing(visiblePhotos.length, _photos.length),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _GraphPlanet extends StatelessWidget {
  const _GraphPlanet({
    required this.photo,
    required this.size,
    required this.onOpen,
  });

  final PhotoItem photo;
  final double size;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.photosColors;
    return Semantics(
      button: true,
      label: photo.title,
      child: Tooltip(
        message: photo.title,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onOpen,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      photo.favorite
                          ? colors.tertiary.withValues(alpha: 0.9)
                          : colors.outlineVariant.withValues(alpha: 0.7),
                  width: photo.favorite ? 3 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.albumCardShadow.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child:
                  photo.coverUrl?.isNotEmpty == true
                      ? CachedNetworkImage(
                        imageUrl: photo.coverUrl!,
                        fit: BoxFit.cover,
                        width: size,
                        height: size,
                        memCacheWidth: 200,
                        errorWidget: (_, _, _) => _placeholder(colors),
                        placeholder: (_, _) => _placeholder(colors),
                      )
                      : _placeholder(colors),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(PhotosColors colors) {
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.photo_outlined,
          color: colors.onSurfaceVariant,
          size: size * 0.32,
        ),
      ),
    );
  }
}
