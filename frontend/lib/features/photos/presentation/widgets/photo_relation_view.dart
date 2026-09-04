import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/photos_colors.dart';
import 'package:omninest/core/errors/error_message.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/domain/photo_album.dart';
import 'package:omninest/features/photos/domain/photo_group.dart';
import 'package:omninest/features/photos/domain/photo_relation.dart';

/// 关联视图每个维度默认展示的实体数量；超出部分聚合并提示。
const int relationEntitiesPerDimension = 12;

/// 关系实体：图谱节点的展示模型。
class RelationEntity {
  const RelationEntity({
    required this.type,
    required this.key,
    required this.label,
    required this.weight,
    this.coverUrl,
  });

  final PhotoRelationNodeType type;
  final String key;
  final String label;
  final int weight;
  final String? coverUrl;

  String get id => '${type.value}:$key';
}

/// 构建指定维度的关系实体列表（按权重排序，可选截断）。
List<RelationEntity> relationEntitiesForDimension({
  required PhotoRelationGraph relation,
  required PhotoRelationNodeType dimension,
  Iterable<PhotoAlbum> albums = const [],
  int limit = relationEntitiesPerDimension,
}) {
  final covers = {for (final album in albums) album.id: album.coverUrl};
  final entities =
      relation.nodes
          .where((node) => node.type == dimension)
          .map(
            (node) => RelationEntity(
              type: node.type,
              key: node.key,
              label: node.label ?? node.key,
              weight: node.weight,
              coverUrl: covers[node.key],
            ),
          )
          .toList()
        ..sort((left, right) {
          final byWeight = right.weight.compareTo(left.weight);
          return byWeight != 0 ? byWeight : left.key.compareTo(right.key);
        });
  if (limit <= 0 || entities.length <= limit) {
    return entities;
  }
  return entities.sublist(0, limit);
}

/// 某维度超出展示上限的实体数量。
int relationEntitiesOverflow({
  required PhotoRelationGraph relation,
  required PhotoRelationNodeType dimension,
  int limit = relationEntitiesPerDimension,
}) {
  final total = relation.nodes.where((node) => node.type == dimension).length;
  final overflow = total - limit;
  return overflow > 0 ? overflow : 0;
}

/// 找出与选中实体关联的其他实体（按共现强度排序，可选截断）。
List<RelationEntity> relatedEntities({
  required PhotoRelationGraph relation,
  required RelationEntity selected,
  Iterable<PhotoRelationNodeType> dimensions = const [
    PhotoRelationNodeType.time,
    PhotoRelationNodeType.location,
    PhotoRelationNodeType.album,
  ],
  int limit = relationEntitiesPerDimension,
}) {
  final connected = <String, RelationEntity>{};
  final otherEntities = relation.nodes.where((node) {
    if (node.type == PhotoRelationNodeType.person) return false;
    return !(node.type == selected.type && node.key == selected.key);
  });
  final entityByKey = {
    for (final node in otherEntities)
      '${node.type.value}:${node.key}': RelationEntity(
        type: node.type,
        key: node.key,
        label: node.label ?? node.key,
        weight: node.weight,
      ),
  };
  for (final edge in relation.edges) {
    final sourceId = '${edge.sourceType.value}:${edge.sourceKey}';
    final targetId = '${edge.targetType.value}:${edge.targetKey}';
    final selectedId = '${selected.type.value}:${selected.key}';
    final otherId =
        sourceId == selectedId
            ? targetId
            : targetId == selectedId
            ? sourceId
            : null;
    if (otherId == null) continue;
    final other = entityByKey[otherId];
    if (other == null) continue;
    connected[otherId] = other;
  }
  final list =
      connected.values.toList()..sort((left, right) {
        final byWeight = right.weight.compareTo(left.weight);
        return byWeight != 0 ? byWeight : left.key.compareTo(right.key);
      });
  if (limit <= 0 || list.length <= limit) {
    return list;
  }
  return list.sublist(0, limit);
}

/// 关联视图：以确定性布局展示时间、地点与相册之间的共现关系。
/// 无物理模拟：选中实体居中，关联实体按强度环绕，连线宽度与共现数成正比。
class PhotoRelationView extends ConsumerStatefulWidget {
  const PhotoRelationView({super.key, this.onOpenPhoto, this.onOpenAlbum});

  final ValueChanged<PhotoItem>? onOpenPhoto;
  final ValueChanged<PhotoAlbum>? onOpenAlbum;

  @override
  ConsumerState<PhotoRelationView> createState() => _PhotoRelationViewState();
}

class _PhotoRelationViewState extends ConsumerState<PhotoRelationView> {
  RelationEntity? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(photoCenterControllerProvider.notifier);
      ref.read(photoCenterControllerProvider).asData?.value.relationGraph.nodes;
      controller.loadRelationGraph();
      _ensureSelection();
    });
  }

  void _ensureSelection() {
    final state = ref.read(photoCenterControllerProvider).asData?.value;
    if (state == null) return;
    if (_selected != null) return;
    final relation = state.relationGraph;
    for (final dimension in [
      PhotoRelationNodeType.time,
      PhotoRelationNodeType.location,
      PhotoRelationNodeType.album,
    ]) {
      final entities = relationEntitiesForDimension(
        relation: relation,
        dimension: dimension,
        albums: state.albums,
      );
      if (entities.isNotEmpty) {
        setState(() => _selected = entities.first);
        return;
      }
    }
  }

  void _select(RelationEntity entity) {
    setState(() => _selected = entity);
  }

  /// 按选中实体回图库：相册打开详情，时间/地点切换分组视图。
  void _openInLibrary(BuildContext context, WidgetRef ref) {
    final selected = _selected;
    if (selected == null) return;
    switch (selected.type) {
      case PhotoRelationNodeType.album:
        widget.onOpenAlbum?.call(
          PhotoAlbum(
            id: selected.key,
            name: selected.label,
            description: '',
            photoCount: selected.weight,
            createdAt: null,
            updatedAt: null,
            coverUrl: selected.coverUrl,
          ),
        );
      case PhotoRelationNodeType.time:
        ref
            .read(photoCenterControllerProvider.notifier)
            .setLibraryView(PhotoLibraryView.groups);
        ref
            .read(photoCenterControllerProvider.notifier)
            .setGroupBy(GroupBy.date);
        context.go('/photos');
      case PhotoRelationNodeType.location:
        ref
            .read(photoCenterControllerProvider.notifier)
            .setLibraryView(PhotoLibraryView.groups);
        ref
            .read(photoCenterControllerProvider.notifier)
            .setGroupBy(GroupBy.location);
        context.go('/photos');
      case PhotoRelationNodeType.person:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(photoCenterControllerProvider);
    return stateAsync.when(
      data:
          (state) =>
              state.relationGraph.nodes.isEmpty && !state.isLoadingRelationGraph
                  ? _EmptyHint(
                    message: AppLocalizations.of(context).photosGraphEmpty,
                    isLoading: state.isLoadingRelationGraph,
                  )
                  : _RelationBody(
                    state: state,
                    selected: _selected,
                    onSelect: _select,
                    onOpenPhoto:
                        widget.onOpenPhoto ??
                        (photo) => context.push('/photos/${photo.id}'),
                    onOpenAlbum: widget.onOpenAlbum,
                    onOpenInLibrary: () => _openInLibrary(context, ref),
                  ),
      error:
          (error, stackTrace) => _EmptyHint(
            message: describeUserFacingError(error).displayMessage,
            isLoading: false,
          ),
      loading: () => const _EmptyHint(message: '', isLoading: true),
    );
  }
}

class _RelationBody extends ConsumerWidget {
  const _RelationBody({
    required this.state,
    required this.selected,
    required this.onSelect,
    required this.onOpenPhoto,
    required this.onOpenAlbum,
    required this.onOpenInLibrary,
  });

  final PhotoCenterState state;
  final RelationEntity? selected;
  final ValueChanged<RelationEntity> onSelect;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoAlbum>? onOpenAlbum;
  final VoidCallback onOpenInLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) {
      return _DesktopRelationLayout(
        state: state,
        selected: selected,
        onSelect: onSelect,
        onOpenPhoto: onOpenPhoto,
        onOpenAlbum: onOpenAlbum,
        onOpenInLibrary: onOpenInLibrary,
      );
    }
    return _CompactRelationLayout(
      state: state,
      selected: selected,
      onSelect: onSelect,
      onOpenPhoto: onOpenPhoto,
      onOpenInLibrary: onOpenInLibrary,
    );
  }
}

class _DimensionNav extends StatelessWidget {
  const _DimensionNav({
    required this.state,
    required this.selected,
    required this.onSelect,
  });

  final PhotoCenterState state;
  final RelationEntity? selected;
  final ValueChanged<RelationEntity> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.photosColors;
    final sections = <(PhotoRelationNodeType, String, IconData)>[
      (
        PhotoRelationNodeType.time,
        l10n.photosGraphKindTime,
        Icons.schedule_rounded,
      ),
      (
        PhotoRelationNodeType.location,
        l10n.photosGraphKindLocation,
        Icons.place_outlined,
      ),
      (
        PhotoRelationNodeType.album,
        l10n.photosGraphKindAlbum,
        Icons.photo_album_outlined,
      ),
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final (type, label, icon) in sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
            child: Row(
              children: [
                Icon(icon, size: 15, color: colors.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          for (final entity in relationEntitiesForDimension(
            relation: state.relationGraph,
            dimension: type,
            albums: state.albums,
          ))
            _EntityTile(
              entity: entity,
              selected:
                  selected != null &&
                  selected!.type == entity.type &&
                  selected!.key == entity.key,
              onTap: () => onSelect(entity),
            ),
          if (relationEntitiesOverflow(
                relation: state.relationGraph,
                dimension: type,
              ) >
              0)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(
                l10n.photosRelOthers(
                  relationEntitiesOverflow(
                    relation: state.relationGraph,
                    dimension: type,
                  ),
                ),
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ),
        ],
      ],
    );
  }
}

class _EntityTile extends StatelessWidget {
  const _EntityTile({
    required this.entity,
    required this.selected,
    required this.onTap,
  });

  final RelationEntity entity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.photosColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color:
            selected
                ? colors.primaryContainer.withValues(alpha: 0.24)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entity.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${entity.weight}',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopRelationLayout extends StatelessWidget {
  const _DesktopRelationLayout({
    required this.state,
    required this.selected,
    required this.onSelect,
    required this.onOpenPhoto,
    required this.onOpenAlbum,
    required this.onOpenInLibrary,
  });

  final PhotoCenterState state;
  final RelationEntity? selected;
  final ValueChanged<RelationEntity> onSelect;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoAlbum>? onOpenAlbum;
  final VoidCallback onOpenInLibrary;

  @override
  Widget build(BuildContext context) {
    final colors = context.photosColors;
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 240,
                child: _DimensionNav(
                  state: state,
                  selected: selected,
                  onSelect: onSelect,
                ),
              ),
              VerticalDivider(width: 1, color: colors.outlineVariant),
              Expanded(
                child:
                    selected == null
                        ? _EmptyHint(
                          message:
                              AppLocalizations.of(context).photosGraphEmpty,
                          isLoading: state.isLoadingRelationGraph,
                        )
                        : _TopologyArea(
                          state: state,
                          selected: selected!,
                          onSelect: onSelect,
                        ),
              ),
              VerticalDivider(width: 1, color: colors.outlineVariant),
              SizedBox(
                width: 300,
                child: _EntityDetailPanel(
                  state: state,
                  selected: selected,
                  onSelect: onSelect,
                  onOpenPhoto: onOpenPhoto,
                  onOpenAlbum: onOpenAlbum,
                  onOpenInLibrary: onOpenInLibrary,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          color: colors.surfaceContainerLow,
          child: Text(
            l10n.photosRelHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _CompactRelationLayout extends StatelessWidget {
  const _CompactRelationLayout({
    required this.state,
    required this.selected,
    required this.onSelect,
    required this.onOpenPhoto,
    required this.onOpenInLibrary,
  });

  final PhotoCenterState state;
  final RelationEntity? selected;
  final ValueChanged<RelationEntity> onSelect;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final VoidCallback onOpenInLibrary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.photosColors;
    final dimensions = [
      PhotoRelationNodeType.time,
      PhotoRelationNodeType.location,
      PhotoRelationNodeType.album,
    ];
    final currentDimension =
        selected?.type ??
        (relationEntitiesForDimension(
              relation: state.relationGraph,
              dimension: PhotoRelationNodeType.time,
            ).isNotEmpty
            ? PhotoRelationNodeType.time
            : relationEntitiesForDimension(
              relation: state.relationGraph,
              dimension: PhotoRelationNodeType.location,
            ).isNotEmpty
            ? PhotoRelationNodeType.location
            : PhotoRelationNodeType.album);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<PhotoRelationNodeType>(
          segments: [
            for (final type in dimensions)
              ButtonSegment(
                value: type,
                label: Text(switch (type) {
                  PhotoRelationNodeType.time => l10n.photosGraphKindTime,
                  PhotoRelationNodeType.location =>
                    l10n.photosGraphKindLocation,
                  PhotoRelationNodeType.album => l10n.photosGraphKindAlbum,
                  _ => '',
                }),
              ),
          ],
          selected: {currentDimension},
          onSelectionChanged: (selection) {
            final entities = relationEntitiesForDimension(
              relation: state.relationGraph,
              dimension: selection.first,
            );
            if (entities.isNotEmpty) onSelect(entities.first);
          },
        ),
        const SizedBox(height: 12),
        for (final entity in relationEntitiesForDimension(
          relation: state.relationGraph,
          dimension: currentDimension,
        ))
          _EntityTile(
            entity: entity,
            selected:
                selected != null &&
                selected!.type == entity.type &&
                selected!.key == entity.key,
            onTap: () => onSelect(entity),
          ),
        if (relationEntitiesOverflow(
              relation: state.relationGraph,
              dimension: currentDimension,
            ) >
            0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              l10n.photosRelOthers(
                relationEntitiesOverflow(
                  relation: state.relationGraph,
                  dimension: currentDimension,
                ),
              ),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ),
        if (selected != null) ...[
          const Divider(height: 24),
          Text(
            l10n.photosRelRelated(selected!.label),
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _SelectedPhotoStrip(
            state: state,
            selected: selected!,
            onOpenPhoto: onOpenPhoto,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onOpenInLibrary,
            icon: const Icon(Icons.filter_list_rounded, size: 16),
            label: Text(l10n.photosViewAll),
          ),
        ],
      ],
    );
  }
}

class _TopologyArea extends StatelessWidget {
  const _TopologyArea({
    required this.state,
    required this.selected,
    required this.onSelect,
  });

  final PhotoCenterState state;
  final RelationEntity selected;
  final ValueChanged<RelationEntity> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.photosColors;
    final related = relatedEntities(
      relation: state.relationGraph,
      selected: selected,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final radius =
            (math.min(constraints.maxWidth, constraints.maxHeight) / 2 - 96)
                .clamp(96.0, 220.0);
        final center = Offset(
          constraints.maxWidth / 2,
          constraints.maxHeight / 2,
        );
        final cardPositions = <Offset>[
          for (var index = 0; index < related.length; index++)
            center +
                Offset.fromDirection(
                  -math.pi / 2 + 2 * math.pi * index / related.length,
                  radius,
                ),
        ];
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RelationEdgePainter(
                  center: center,
                  endpoints: [
                    for (var index = 0; index < related.length; index++)
                      MapEntry(cardPositions[index], related[index].weight),
                  ],
                  maxWeight:
                      related.isEmpty
                          ? 1
                          : related
                              .map((entity) => entity.weight)
                              .reduce(math.max),
                  color: colors.outlineVariant,
                ),
              ),
            ),
            Positioned(
              left: center.dx - 72,
              top: center.dy - 44,
              width: 144,
              child: _EntityCard(
                entity: selected,
                isCenter: true,
                coOccurrence: null,
                onTap: () {},
              ),
            ),
            for (var index = 0; index < related.length; index++)
              Positioned(
                left: cardPositions[index].dx - 66,
                top: cardPositions[index].dy - 44,
                width: 132,
                child: _EntityCard(
                  entity: related[index],
                  isCenter: false,
                  coOccurrence: related[index].weight,
                  onTap: () => onSelect(related[index]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RelationEdgePainter extends CustomPainter {
  const _RelationEdgePainter({
    required this.center,
    required this.endpoints,
    required this.maxWeight,
    required this.color,
  });

  final Offset center;
  final List<MapEntry<Offset, int>> endpoints;
  final int maxWeight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    for (final entry in endpoints) {
      final strength = maxWeight <= 0 ? 0.0 : entry.value / maxWeight;
      paint.strokeWidth = 1.2 + strength * 4;
      paint.color = color.withValues(alpha: 0.35 + strength * 0.4);
      canvas.drawLine(center, entry.key, paint);
    }
  }

  @override
  bool shouldRepaint(_RelationEdgePainter oldDelegate) =>
      oldDelegate.center != center ||
      oldDelegate.maxWeight != maxWeight ||
      oldDelegate.endpoints.length != endpoints.length ||
      oldDelegate.color != color;
}

class _EntityCard extends StatelessWidget {
  const _EntityCard({
    required this.entity,
    required this.isCenter,
    required this.coOccurrence,
    required this.onTap,
  });

  final RelationEntity entity;
  final bool isCenter;
  final int? coOccurrence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.photosColors;
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message:
          coOccurrence == null
              ? entity.label
              : l10n.photosRelCooccur(coOccurrence!),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCenter ? colors.primaryContainer : colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isCenter
                      ? colors.primaryContainer
                      : colors.outlineVariant.withValues(alpha: 0.5),
              width: isCenter ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entity.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      isCenter ? colors.onPrimaryContainer : colors.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                coOccurrence == null
                    ? '${entity.weight}'
                    : l10n.photosRelCooccur(coOccurrence!),
                style: TextStyle(
                  color:
                      isCenter
                          ? colors.onPrimaryContainer.withValues(alpha: 0.8)
                          : colors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntityDetailPanel extends ConsumerWidget {
  const _EntityDetailPanel({
    required this.state,
    required this.selected,
    required this.onSelect,
    required this.onOpenPhoto,
    required this.onOpenAlbum,
    required this.onOpenInLibrary,
  });

  final PhotoCenterState state;
  final RelationEntity? selected;
  final ValueChanged<RelationEntity> onSelect;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoAlbum>? onOpenAlbum;
  final VoidCallback onOpenInLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.photosColors;
    final l10n = AppLocalizations.of(context);
    if (selected == null) {
      return const SizedBox.shrink();
    }
    final photosAsync = ref.watch(entityPhotosProvider(selected!));
    final related = relatedEntities(
      relation: state.relationGraph,
      selected: selected!,
    );
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          selected!.label,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.photosAlbumPhotoCount(selected!.weight),
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.photosRelCooccurTitle,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entity in related)
              ActionChip(
                label: Text(entity.label),
                onPressed: () => onSelect(entity),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onOpenInLibrary,
          icon: const Icon(Icons.filter_list_rounded, size: 16),
          label: Text(l10n.photosViewAll),
        ),
        const SizedBox(height: 8),
        photosAsync.when(
          data:
              (photos) => Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final photo in photos.take(9))
                    GestureDetector(
                      onTap: () => onOpenPhoto(photo),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 84,
                          height: 84,
                          child:
                              photo.coverUrl?.isNotEmpty == true
                                  ? Image.network(
                                    photo.coverUrl!,
                                    fit: BoxFit.cover,
                                  )
                                  : ColoredBox(
                                    color: colors.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.photo_outlined,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                ],
              ),
          loading:
              () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          error:
              (error, _) => Text(
                describeUserFacingError(error).displayMessage,
                style: TextStyle(color: colors.danger, fontSize: 12),
              ),
        ),
      ],
    );
  }
}

final entityPhotosProvider = FutureProvider.autoDispose
    .family<List<PhotoItem>, RelationEntity>((ref, entity) async {
      final controller = ref.read(photoCenterControllerProvider.notifier);
      switch (entity.type) {
        case PhotoRelationNodeType.album:
          final detail = await ref.read(
            photoAlbumDetailProvider(entity.key).future,
          );
          return detail.photos;
        case PhotoRelationNodeType.time:
          await controller.loadGroups(GroupBy.date, force: true);
        case PhotoRelationNodeType.location:
          await controller.loadGroups(GroupBy.location, force: true);
        case PhotoRelationNodeType.person:
          return const <PhotoItem>[];
      }
      final state = ref.read(photoCenterControllerProvider).asData?.value;
      return state?.groups
              ?.where((group) => group.groupKey == entity.key)
              .expand((group) => group.photos)
              .toList(growable: false) ??
          const <PhotoItem>[];
    });

class _SelectedPhotoStrip extends ConsumerWidget {
  const _SelectedPhotoStrip({
    required this.state,
    required this.selected,
    required this.onOpenPhoto,
  });

  final PhotoCenterState state;
  final RelationEntity selected;
  final ValueChanged<PhotoItem> onOpenPhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(entityPhotosProvider(selected));
    return SizedBox(
      height: 120,
      child: photosAsync.when(
        data:
            (photos) => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final photo = photos[index];
                return GestureDetector(
                  onTap: () => onOpenPhoto(photo),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 120,
                      child:
                          photo.coverUrl?.isNotEmpty == true
                              ? Image.network(
                                photo.coverUrl!,
                                fit: BoxFit.cover,
                              )
                              : ColoredBox(
                                color:
                                    context
                                        .photosColors
                                        .surfaceContainerHighest,
                                child: Icon(
                                  Icons.photo_outlined,
                                  color: context.photosColors.onSurfaceVariant,
                                ),
                              ),
                    ),
                  ),
                );
              },
            ),
        loading:
            () => const Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        error:
            (error, _) => Center(
              child: Text(describeUserFacingError(error).displayMessage),
            ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.message, required this.isLoading});

  final String message;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(child: Text(message, textAlign: TextAlign.center));
  }
}
