import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/presentation/widgets/frame_empty_view.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_grid_tile.dart';

/// Frame 瀑布流网格：按设计稿 CSS columns 布局。
///
/// 默认 4 列，容器 ≤1280px 时 3 列，≤900px 时 2 列；列距 10px、
/// 图格下边距 10px、容器内边距 16px（md 及以上 24px）。
class FrameMasonryGrid extends ConsumerWidget {
  const FrameMasonryGrid({
    required this.photos,
    required this.onOpenPhoto,
    required this.onToggleFavorite,
    super.key,
  });

  final List<PhotoItem> photos;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoItem> onToggleFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 640) {
          ref
              .read(photoCenterControllerProvider.notifier)
              .loadMoreVisiblePhotos();
        }
        return false;
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (photos.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: FrameEmptyView(
                icon: Icons.image_outlined,
                message: l10n.photosNoPhotos,
              ),
            )
          else
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final padding = constraints.crossAxisExtent > 768 ? 24.0 : 16.0;
                final columns = _columnCountFor(constraints.crossAxisExtent);
                return SliverPadding(
                  padding: EdgeInsets.all(padding),
                  sliver: SliverToBoxAdapter(
                    child: _MasonryColumns(
                      photos: photos,
                      columns: columns,
                      onOpenPhoto: onOpenPhoto,
                      onToggleFavorite: onToggleFavorite,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  int _columnCountFor(double width) {
    if (width > 1280) return 4;
    if (width > 900) return 3;
    return 2;
  }
}

/// 单屏瀑布流：按纵横比贪心分配到最矮列，复刻设计稿顺序铺排。
class _MasonryColumns extends ConsumerWidget {
  const _MasonryColumns({
    required this.photos,
    required this.columns,
    required this.onOpenPhoto,
    required this.onToggleFavorite,
  });

  final List<PhotoItem> photos;
  final int columns;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoItem> onToggleFavorite;

  double _aspectRatioFor(PhotoItem photo) {
    final width = photo.width;
    final height = photo.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return 1.0;
    }
    return (width / height).clamp(0.6, 2.4);
  }

  void _toggleSelect(WidgetRef ref, PhotoItem photo, bool isSelectionMode) {
    final notifier = ref.read(photoCenterControllerProvider.notifier);
    if (!isSelectionMode) {
      notifier.toggleSelectionMode();
    }
    notifier.togglePhotoSelection(photo.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(photoCenterControllerProvider).asData?.value;
    final isSelectionMode = value?.isSelectionMode ?? false;
    final selectedIds = value?.selectedPhotoIds ?? const <String>{};

    final trackCount = columns.clamp(1, 12);
    final tracks = List.generate(trackCount, (_) => <PhotoItem>[]);
    final trackHeights = List.filled(trackCount, 0.0);
    for (final photo in photos) {
      final ratio = _aspectRatioFor(photo);
      var shortest = 0;
      for (var i = 1; i < trackHeights.length; i++) {
        if (trackHeights[i] < trackHeights[shortest]) shortest = i;
      }
      tracks[shortest].add(photo);
      trackHeights[shortest] += 1 / ratio;
    }

    final columnsChildren = <Widget>[];
    for (var i = 0; i < tracks.length; i++) {
      if (i > 0) {
        columnsChildren.add(const SizedBox(width: 10));
      }
      columnsChildren.add(
        Expanded(
          child: Column(
            children: [
              for (final photo in tracks[i])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PhotoGridTile(
                    key: ValueKey(photo.id),
                    photo: photo,
                    aspectRatio: _aspectRatioFor(photo),
                    enableHero: true,
                    isSelectionMode: isSelectionMode,
                    isSelected: selectedIds.contains(photo.id),
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
                      HapticFeedback.mediumImpact();
                      _toggleSelect(ref, photo, isSelectionMode);
                    },
                    onToggleSelection:
                        () => _toggleSelect(ref, photo, isSelectionMode),
                    onToggleFavorite: () => onToggleFavorite(photo),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columnsChildren,
    );
  }
}
