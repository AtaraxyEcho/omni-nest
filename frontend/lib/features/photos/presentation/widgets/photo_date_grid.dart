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

/// 以日期区段组织的照片网格：粘性日期头、多选、无限滚动。
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
    this.scrollController,
    this.onScrollOffsetChanged,
    this.showScrollToTop = false,
    this.onScrollToTop,
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
  final ScrollController? scrollController;
  final ValueChanged<double>? onScrollOffsetChanged;
  final bool showScrollToTop;
  final VoidCallback? onScrollToTop;

  @override
  ConsumerState<PhotoDateGrid> createState() => _PhotoDateGridState();
}

class _PhotoDateGridState extends ConsumerState<PhotoDateGrid> {
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
            return SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final photo = section.photos[index];
                final value =
                    ref.watch(photoCenterControllerProvider).asData?.value;
                final isSelectionMode = value?.isSelectionMode ?? false;
                final isSelected =
                    value?.selectedPhotoIds.contains(photo.id) ?? false;
                return PhotoGridTile(
                  key: ValueKey(photo.id),
                  photo: photo,
                  isSelectionMode: isSelectionMode,
                  isSelected: isSelected,
                  onDelete: widget.onDeletePhoto,
                  onTap: () {
                    if (isSelectionMode) {
                      ref
                          .read(photoCenterControllerProvider.notifier)
                          .togglePhotoSelection(photo.id);
                    } else {
                      widget.onOpenPhoto(photo);
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
                );
              }, childCount: section.photos.length),
            );
          },
        ),
      ],
    ];

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final offset = notification.metrics.pixels;
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
            controller: widget.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              ...children,
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
          if (widget.showScrollToTop)
            Positioned(
              right: 20,
              bottom: 20,
              child: FloatingActionButton.small(
                onPressed: widget.onScrollToTop,
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
      final label = _sectionLabel(date, grouping);
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

  String _sectionLabel(DateTime? date, PhotoDateGrouping grouping) {
    final resolved = date ?? DateTime.now();
    final locale = Localizations.localeOf(context).toString();
    return grouping == PhotoDateGrouping.month
        ? DateFormat.yMMM(locale).format(resolved)
        : DateFormat.yMMMd(locale).format(resolved);
  }

  int _columnCountFor(double width) {
    if (width >= 1600) return 7;
    if (width >= 1300) return 6;
    if (width >= 1000) return 5;
    if (width >= 700) return 4;
    if (width >= 380) return 3;
    return 2;
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
