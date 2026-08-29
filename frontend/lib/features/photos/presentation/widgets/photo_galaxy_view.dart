import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/photos_colors.dart';
import 'package:omninest/core/errors/error_message.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/domain/photo_album.dart';
import 'package:omninest/features/photos/domain/photo_group.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_galaxy_models.dart';

part 'photo_galaxy_controls.dart';
part 'photo_galaxy_nodes.dart';
part 'photo_galaxy_painters.dart';

class PhotoGalaxyView extends ConsumerStatefulWidget {
  const PhotoGalaxyView({
    super.key,
    required this.state,
    required this.onOpenPhoto,
    this.onOpenAlbum,
  });

  final PhotoCenterState state;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoAlbum>? onOpenAlbum;

  @override
  ConsumerState<PhotoGalaxyView> createState() => _PhotoGalaxyViewState();
}

class _PhotoGalaxyViewState extends ConsumerState<PhotoGalaxyView> {
  PhotoGalaxyMode _mode = PhotoGalaxyMode.all;
  String? _selectedClusterId;
  String? _modeError;
  int _modeRequestGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startModeDataLoad(_mode);
    });
  }

  @override
  void didUpdateWidget(covariant PhotoGalaxyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = _selectedClusterId;
    if (selected == null) return;
    final stillExists = buildPhotoGalaxyClusters(
      widget.state,
      _mode,
    ).any((cluster) => cluster.id == selected);
    if (!stillExists && mounted) {
      _selectedClusterId = null;
    }
  }

  void _selectMode(PhotoGalaxyMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _selectedClusterId = null;
      _modeError = null;
    });
    _startModeDataLoad(mode);
  }

  void _startModeDataLoad(PhotoGalaxyMode mode, {bool force = false}) {
    final generation = ++_modeRequestGeneration;
    unawaited(_loadModeData(mode, generation: generation, force: force));
  }

  @override
  void dispose() {
    _modeRequestGeneration++;
    super.dispose();
  }

  Future<void> _loadModeData(
    PhotoGalaxyMode mode, {
    required int generation,
    bool force = false,
  }) async {
    try {
      await _ensureModeData(mode, force: force);
      if (!mounted || generation != _modeRequestGeneration || mode != _mode) {
        return;
      }
      setState(() => _modeError = null);
    } on Exception catch (error) {
      if (!mounted || generation != _modeRequestGeneration || mode != _mode) {
        return;
      }
      setState(
        () => _modeError = describeUserFacingError(error).displayMessage,
      );
    }
  }

  Future<void> _ensureModeData(
    PhotoGalaxyMode mode, {
    bool force = false,
  }) async {
    if (!mounted) return;
    if (mode == PhotoGalaxyMode.people) {
      if (!force && widget.state.faceClusters.isNotEmpty) return;
      await ref
          .read(photoCenterControllerProvider.notifier)
          .loadFaceClusters(propagateError: true);
      return;
    }

    final groupBy = switch (mode) {
      PhotoGalaxyMode.all || PhotoGalaxyMode.time => GroupBy.date,
      PhotoGalaxyMode.location => GroupBy.location,
      PhotoGalaxyMode.people => GroupBy.date,
    };
    final current = widget.state;
    if (!force && current.groups != null && current.groupBy == groupBy) {
      return;
    }
    await ref
        .read(photoCenterControllerProvider.notifier)
        .loadGroups(groupBy, force: force);
  }

  @override
  Widget build(BuildContext context) {
    final clusters = buildPhotoGalaxyClusters(widget.state, _mode);
    final selected =
        clusters
            .where((cluster) => cluster.id == _selectedClusterId)
            .firstOrNull;
    final query = widget.state.searchQuery.trim();
    final colors = context.photosColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final minHeight =
            constraints.hasBoundedHeight ? constraints.maxHeight : 640.0;
        final slivers =
            selected == null
                ? _buildUniverseSlivers(context, clusters, query, compact)
                : <Widget>[
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 16 : 24,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _GalaxyDetail(
                        key: ValueKey(selected.id),
                        cluster: selected,
                        onBack: () {
                          if (mounted) {
                            setState(() => _selectedClusterId = null);
                          }
                        },
                        onOpenPhoto: widget.onOpenPhoto,
                        onOpenAlbum: widget.onOpenAlbum,
                      ),
                    ),
                  ),
                ];

        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: DecoratedBox(
            key: const Key('photo-galaxy-canvas'),
            decoration: BoxDecoration(color: colors.galaxyCanvas),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _GalaxyBackdropPainter(colors: colors),
                    ),
                  ),
                ),
                CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    ...slivers,
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildUniverseSlivers(
    BuildContext context,
    List<PhotoGalaxyCluster> clusters,
    String query,
    bool compact,
  ) {
    final l10n = AppLocalizations.of(context);
    final isLoading =
        widget.state.isLoadingGroups || widget.state.isLoadingFaceClusters;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final baseRowHeight = compact ? 184.0 : 202.0;
    final rowHeight = baseRowHeight + (textScale - 1) * 140;
    final ordered = [...clusters]
      ..sort((left, right) => right.photoCount.compareTo(left.photoCount));
    final visible =
        query.isEmpty
            ? ordered
            : ordered.where((cluster) => cluster.matches(query)).toList();

    final result = <Widget>[
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : 24,
          16,
          compact ? 16 : 24,
          0,
        ),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            _GalaxyControlBar(
              mode: _mode,
              onModeChanged: _selectMode,
              isLoading: isLoading,
            ),
          ]),
        ),
      ),
    ];
    if (query.isNotEmpty) {
      final status = _GalaxySearchStatus(
        query: query,
        onClear: () {
          if (!mounted) return;
          ref.read(photoCenterControllerProvider.notifier).setSearchQuery('');
        },
      );
      result.add(
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24),
          sliver: SliverToBoxAdapter(child: status),
        ),
      );
    }
    if (_modeError != null) {
      result.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 24,
            10,
            compact ? 16 : 24,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Text(
              _modeError!,
              style: TextStyle(color: context.photosColors.galaxyMuted),
            ),
          ),
        ),
      );
    }

    if (visible.isEmpty) {
      result.add(
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24),
          sliver: SliverToBoxAdapter(
            child: _GalaxyEmptyState(
              isLoading: isLoading,
              hasSearch: query.isNotEmpty,
              onRetry:
                  isLoading
                      ? null
                      : () => _startModeDataLoad(_mode, force: true),
            ),
          ),
        ),
      );
      return result;
    }

    result.add(
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : 24,
          20,
          compact ? 16 : 24,
          0,
        ),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate((context, index) {
            final cluster = visible[index];
            final featured = index == 0 && query.isEmpty;
            return _GalaxyNode(
              key: ValueKey(cluster.id),
              cluster: cluster,
              fallbackTitle: _fallbackClusterTitle(l10n, cluster),
              countLabel: _clusterCountLabel(l10n, cluster),
              featured: featured,
              onTap: () {
                if (mounted) {
                  setState(() => _selectedClusterId = cluster.id);
                }
              },
            );
          }, childCount: visible.length),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: compact ? 176 : 216,
            mainAxisExtent: rowHeight,
            crossAxisSpacing: compact ? 10 : 22,
            mainAxisSpacing: compact ? 18 : 28,
          ),
        ),
      ),
    );
    return result;
  }

  String _fallbackClusterTitle(
    AppLocalizations l10n,
    PhotoGalaxyCluster cluster,
  ) {
    return switch (cluster.kind) {
      PhotoGalaxyClusterKind.album => l10n.photosGalaxyUnnamedAlbum,
      PhotoGalaxyClusterKind.group => l10n.photosGalaxyUnnamedGroup,
      PhotoGalaxyClusterKind.person => l10n.photosGalaxyUnnamedPerson,
      PhotoGalaxyClusterKind.unassigned => l10n.photosGalaxyUnsorted,
    };
  }

  String _clusterCountLabel(AppLocalizations l10n, PhotoGalaxyCluster cluster) {
    return switch (cluster.countKind) {
      PhotoGalaxyCountKind.photos => l10n.photosGalaxyPhotoCount(
        cluster.photoCount,
      ),
      PhotoGalaxyCountKind.faces => l10n.photosGalaxyFaceCount(
        cluster.photoCount,
      ),
    };
  }
}

class _GalaxyDetail extends ConsumerStatefulWidget {
  const _GalaxyDetail({
    super.key,
    required this.cluster,
    required this.onBack,
    required this.onOpenPhoto,
    this.onOpenAlbum,
  });

  final PhotoGalaxyCluster cluster;
  final VoidCallback onBack;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoAlbum>? onOpenAlbum;

  @override
  ConsumerState<_GalaxyDetail> createState() => _GalaxyDetailState();
}

class _GalaxyDetailState extends ConsumerState<_GalaxyDetail> {
  List<PhotoItem> _photos = const [];
  PhotoItem? _focusedPhoto;
  String? _error;
  bool _loading = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPhotos());
  }

  @override
  void didUpdateWidget(covariant _GalaxyDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cluster.id != widget.cluster.id) {
      _focusedPhoto = null;
      unawaited(_loadPhotos());
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }

  bool _isCurrent(int generation, String clusterId) {
    return mounted &&
        generation == _loadGeneration &&
        widget.cluster.id == clusterId;
  }

  Future<void> _loadPhotos() async {
    final generation = ++_loadGeneration;
    final cluster = widget.cluster;
    if (cluster.kind == PhotoGalaxyClusterKind.group ||
        cluster.kind == PhotoGalaxyClusterKind.unassigned) {
      if (_isCurrent(generation, cluster.id)) {
        setState(() {
          _photos = cluster.photos;
          _loading = false;
          _error = null;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _photos = const [];
    });
    try {
      final photos = switch (cluster.kind) {
        PhotoGalaxyClusterKind.album =>
          (await ref.read(
            photoAlbumDetailProvider(cluster.sourceId!).future,
          )).photos,
        PhotoGalaxyClusterKind.person => await ref
            .read(photoCenterControllerProvider.notifier)
            .getPhotosByCluster(cluster.sourceId!),
        PhotoGalaxyClusterKind.group ||
        PhotoGalaxyClusterKind.unassigned => cluster.photos,
      };
      if (!_isCurrent(generation, cluster.id)) return;
      setState(() {
        _photos = photos;
        _loading = false;
      });
    } on Exception catch (error) {
      if (!_isCurrent(generation, cluster.id)) return;
      setState(() {
        _loading = false;
        _error = describeUserFacingError(error).displayMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.photosColors;
    final title =
        widget.cluster.title.trim().isEmpty
            ? switch (widget.cluster.kind) {
              PhotoGalaxyClusterKind.album => l10n.photosGalaxyUnnamedAlbum,
              PhotoGalaxyClusterKind.group => l10n.photosGalaxyUnnamedGroup,
              PhotoGalaxyClusterKind.person => l10n.photosGalaxyUnnamedPerson,
              PhotoGalaxyClusterKind.unassigned => l10n.photosGalaxyUnsorted,
            }
            : widget.cluster.title;
    final visiblePhotos = _photos.take(80).toList(growable: false);
    final countLabel = switch (widget.cluster.countKind) {
      PhotoGalaxyCountKind.photos => l10n.photosGalaxyPhotoCount(
        widget.cluster.photoCount,
      ),
      PhotoGalaxyCountKind.faces => l10n.photosGalaxyFaceCount(
        widget.cluster.photoCount,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: widget.onBack,
              tooltip: l10n.photosGalaxyBack,
              icon: Icon(
                Icons.arrow_back_rounded,
                color: colors.galaxyOnCanvas,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.galaxyOnCanvas,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (widget.cluster.kind == PhotoGalaxyClusterKind.album &&
                widget.onOpenAlbum != null)
              TextButton.icon(
                onPressed: () {
                  final albumId = widget.cluster.sourceId;
                  if (albumId == null) return;
                  widget.onOpenAlbum!(
                    widget.cluster.album ??
                        PhotoAlbum(
                          id: albumId,
                          name: title,
                          description: '',
                          photoCount: widget.cluster.photoCount,
                          createdAt: null,
                          updatedAt: null,
                          coverUrl: widget.cluster.coverUrl,
                        ),
                  );
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(l10n.photosGalaxyOpenAlbum),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 52, bottom: 16),
          child: Text(
            countLabel,
            style: TextStyle(color: colors.galaxyMuted, fontSize: 13),
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
          _GalaxyErrorState(message: _error!, onRetry: _loadPhotos)
        else if (visiblePhotos.isEmpty)
          const _GalaxyEmptyState(isLoading: false, hasSearch: false)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final size = compact ? 68.0 : 82.0;
              return Wrap(
                alignment: WrapAlignment.center,
                spacing: compact ? 16 : 26,
                runSpacing: 22,
                children: [
                  for (final photo in visiblePhotos)
                    _GalaxyPlanet(
                      photo: photo,
                      size: photo.favorite ? size * 1.22 : size,
                      focused: _focusedPhoto?.id == photo.id,
                      onFocus: () => setState(() => _focusedPhoto = photo),
                      onOpen: () => widget.onOpenPhoto(photo),
                    ),
                ],
              );
            },
          ),
        if (_photos.length > visiblePhotos.length)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              l10n.photosGalaxyShowing(visiblePhotos.length, _photos.length),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.galaxyMuted, fontSize: 12),
            ),
          ),
        if (_focusedPhoto != null) ...[
          const SizedBox(height: 24),
          _GalaxyFocusPanel(
            photo: _focusedPhoto!,
            onOpen: () => widget.onOpenPhoto(_focusedPhoto!),
            onDismiss: () => setState(() => _focusedPhoto = null),
          ),
        ],
      ],
    );
  }
}

class _GalaxyFocusPanel extends StatelessWidget {
  const _GalaxyFocusPanel({
    required this.photo,
    required this.onOpen,
    required this.onDismiss,
  });

  final PhotoItem photo;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.photosColors;
    final metadata = [
      if (photo.locationDisplay != null) photo.locationDisplay!,
      if (photo.dateTaken != null) _formatGalaxyDate(context, photo.dateTaken!),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: colors.galaxyCanvasRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.galaxyLine),
      ),
      child: Row(
        children: [
          _GalaxyOrb(
            url: photo.coverUrl,
            size: 48,
            accent: true,
            favorite: photo.favorite,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photo.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.galaxyOnCanvas,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (metadata.isNotEmpty)
                  Text(
                    metadata,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.galaxyMuted, fontSize: 12),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onOpen,
            tooltip: l10n.photosGalaxyViewPhoto,
            icon: Icon(Icons.open_in_new_rounded, color: colors.galaxyOnCanvas),
          ),
          IconButton(
            onPressed: onDismiss,
            tooltip: l10n.photosClose,
            icon: Icon(Icons.close_rounded, color: colors.galaxyMuted),
          ),
        ],
      ),
    );
  }
}

class _GalaxyEmptyState extends StatelessWidget {
  const _GalaxyEmptyState({
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
          Icon(
            Icons.auto_awesome_outlined,
            size: 52,
            color: colors.galaxyMuted,
          ),
          const SizedBox(height: 14),
          Text(
            hasSearch
                ? l10n.photosGalaxyNoSearchResults
                : l10n.photosGalaxyEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.galaxyOnCanvas,
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

class _GalaxyErrorState extends StatelessWidget {
  const _GalaxyErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.photosColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.galaxyMuted),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => unawaited(onRetry()),
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: Text(l10n.coreRetry),
            ),
          ],
        ),
      ),
    );
  }
}
