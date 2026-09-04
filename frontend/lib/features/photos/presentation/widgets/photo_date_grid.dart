import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/core/widgets/app_empty_state.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_grid_tile.dart';

/// 图库网格的日期分组粒度。
enum PhotoDateGrouping { day, month }

/// 日期分组的连续区段。
class _PhotoDateSection {
  const _PhotoDateSection({required this.label, required this.photos});

  final String label;
  final List<PhotoItem> photos;
}

/// 以日期区段组织的照片瀑布流：粘性日期头、多选、无限滚动。
///
/// 桌面与移动共用；移动端通过 [leadingSlivers] 在网格前插入相册货架等区块。
class PhotoDateGrid extends ConsumerStatefulWidget {
  const PhotoDateGrid({
    required this.photos,
    required this.grouping,
    required this.onOpenPhoto,
    required this.emptyMessage,
    required this.emptySubtitle,
    this.onDeletePhoto,
    this.leadingSlivers = const <Widget>[],
    this.onScrollOffsetChanged,
    this.showScrollToTop = false,
    super.key,
  });

  final List<PhotoItem> photos;
  final PhotoDateGrouping grouping;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoItem>? onDeletePhoto;
  final String emptyMessage;
  final String emptySubtitle;

  /// 插入在日期区段之前的 Sliver（相册货架等）。
  final List<Widget> leadingSlivers;
  final ValueChanged<double>? onScrollOffsetChanged;
  final bool showScrollToTop;

  @override
  ConsumerState<PhotoDateGrid> createState() => _PhotoDateGridState();
}

class _PhotoDateGridState extends ConsumerState<PhotoDateGrid> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolledDeep = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = _buildSections(widget.photos, widget.grouping);
    if (sections.isEmpty && widget.leadingSlivers.isEmpty) {
      return AppEmptyState(
        message: widget.emptyMessage,
        subtitle: widget.emptySubtitle,
        icon: Icons.photo_library_outlined,
      );
    }
    final children = <Widget>[
      ...widget.leadingSlivers,
      for (final section in sections) ...[
        SliverPersistentHeader(
          pinned: true,
          delegate: _DateHeaderDelegate(label: section.label),
        ),
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final columns = _columnCountFor(constraints.crossAxisExtent);
            return SliverToBoxAdapter(
              child: _MasonrySection(
                photos: section.photos,
                columns: columns,
                onOpenPhoto: widget.onOpenPhoto,
                onDeletePhoto: widget.onDeletePhoto,
              ),
            );
          },
        ),
      ],
    ];

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final offset = notification.metrics.pixels;
        final deep = offset > 800;
        if (deep != _scrolledDeep) {
          setState(() => _scrolledDeep = deep);
        }
        widget.onScrollOffsetChanged?.call(offset);
        if (notification.metrics.extentAfter < 640) {
          ref
              .read(photoCenterControllerProvider.notifier)
              .loadMoreVisiblePhotos();
        }
        return false;
      },
      child: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              ...children,
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
          if (widget.showScrollToTop && _scrolledDeep)
            Positioned(
              right: 20,
              bottom: 20,
              child: FloatingActionButton.small(
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                  );
                },
                tooltip: AppLocalizations.of(context).photosScrollToTop,
                child: const Icon(Icons.arrow_upward_rounded),
              ),
            ),
        ],
      ),
    );
  }

  List<_PhotoDateSection> _buildSections(
    List<PhotoItem> photos,
    PhotoDateGrouping grouping,
  ) {
    if (photos.isEmpty) return const [];
    final sections = <_PhotoDateSection>[];
    String? currentLabel;
    var currentPhotos = <PhotoItem>[];
    for (final photo in photos) {
      final date = photo.dateTaken ?? photo.createdAt;
      final label = _sectionLabel(context, date, grouping);
      if (label != currentLabel) {
        if (currentPhotos.isNotEmpty) {
          sections.add(
            _PhotoDateSection(label: currentLabel!, photos: currentPhotos),
          );
        }
        currentLabel = label;
        currentPhotos = <PhotoItem>[];
      }
      currentPhotos.add(photo);
    }
    if (currentPhotos.isNotEmpty) {
      sections.add(
        _PhotoDateSection(label: currentLabel!, photos: currentPhotos),
      );
    }
    return sections;
  }

  String _sectionLabel(
    BuildContext context,
    DateTime? date,
    PhotoDateGrouping grouping,
  ) {
    final resolved = date ?? DateTime.now();
    final locale = Localizations.localeOf(context).toString();
    return grouping == PhotoDateGrouping.month
        ? DateFormat.yMMM(locale).format(resolved)
        : DateFormat.yMMMd(locale).format(resolved);
  }

  int _columnCountFor(double width) {
    if (width >= 1600) return 6;
    if (width >= 1300) return 5;
    if (width >= 1000) return 4;
    if (width >= 700) return 3;
    return 2;
  }
}

/// 单个日期区段内的瀑布流：按纵横比贪心分配到最矮列。
class _MasonrySection extends ConsumerWidget {
  const _MasonrySection({
    required this.photos,
    required this.columns,
    required this.onOpenPhoto,
    required this.onDeletePhoto,
  });

  final List<PhotoItem> photos;
  final int columns;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoItem>? onDeletePhoto;

  double _aspectRatioFor(PhotoItem photo) {
    final width = photo.width;
    final height = photo.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return 1.0;
    }
    return (width / height).clamp(0.6, 2.4);
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final track in tracks)
          Expanded(
            child: Column(
              children: [
                for (final photo in track)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: PhotoGridTile(
                      key: ValueKey(photo.id),
                      photo: photo,
                      aspectRatio: _aspectRatioFor(photo),
                      enableHero: true,
                      isSelectionMode: isSelectionMode,
                      isSelected: selectedIds.contains(photo.id),
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
                          HapticFeedback.mediumImpact();
                          final notifier = ref.read(
                            photoCenterControllerProvider.notifier,
                          );
                          notifier.toggleSelectionMode();
                          notifier.togglePhotoSelection(photo.id);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DateHeaderDelegate({required this.label});

  final String label;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 40;

  @override
  double get minExtent => 40;

  @override
  bool shouldRebuild(_DateHeaderDelegate oldDelegate) =>
      oldDelegate.label != label;
}
