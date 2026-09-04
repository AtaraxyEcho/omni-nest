import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/photos_colors.dart';
import 'package:omninest/core/errors/error_message.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/domain/photo_album.dart';
import 'package:omninest/features/photos/domain/photo_group.dart';
import 'package:omninest/features/photos/domain/photo_relation.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_graph_models.dart';

part 'photo_graph_nodes.dart';
part 'photo_graph_painter.dart';

/// 关系图谱视图：以力导向图展示相册、时间、地点、人物之间的共现关系。
class PhotoGraphView extends ConsumerStatefulWidget {
  const PhotoGraphView({
    super.key,
    required this.state,
    required this.onOpenPhoto,
    this.onOpenAlbum,
  });

  final PhotoCenterState state;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoAlbum>? onOpenAlbum;

  @override
  ConsumerState<PhotoGraphView> createState() => _PhotoGraphViewState();
}

class _PhotoGraphViewState extends ConsumerState<PhotoGraphView>
    with SingleTickerProviderStateMixin {
  Set<PhotoRelationNodeType> _enabledKinds = {...PhotoRelationNodeType.values};
  String? _selectedNodeId;
  int _loadGeneration = 0;
  PhotoGraphLayout? _layout;
  Ticker? _ticker;
  String? _layoutSignature;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadRelationGraph();
    });
  }

  @override
  void dispose() {
    _loadGeneration++;
    _stopTicker();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PhotoGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mounted) return;
    final data = _currentData();
    if (_selectedNodeId != null &&
        !data.nodes.any((node) => node.id == _selectedNodeId)) {
      _selectedNodeId = null;
    }
    _refreshLayoutIfChanged(data);
  }

  PhotoGraphData _currentData() {
    return buildPhotoGraph(
      relation: widget.state.relationGraph,
      kinds: _enabledKinds,
      query: widget.state.searchQuery,
      albums: widget.state.albums,
    );
  }

  Future<void> _loadRelationGraph() async {
    final generation = ++_loadGeneration;
    await ref.read(photoCenterControllerProvider.notifier).loadRelationGraph();
    if (!mounted || generation != _loadGeneration) return;
    _refreshLayoutIfChanged(_currentData());
  }

  void _refreshLayoutIfChanged(PhotoGraphData data) {
    final signature =
        '${data.nodes.map((node) => '${node.id}:${node.weight}').join('|')}'
        '#${data.edges.length}#${_enabledKinds.length}';
    if (signature == _layoutSignature) return;
    _layoutSignature = signature;
    if (data.nodes.isEmpty) {
      _layout = null;
      _stopTicker();
      return;
    }
    final canvasSize = Size(
      (900.0 + data.nodes.length * 12).clamp(900.0, 2200.0),
      (640.0 + data.nodes.length * 9).clamp(640.0, 1600.0),
    );
    _layout = PhotoGraphLayout(
      nodes: data.nodes,
      edges: data.edges,
      size: canvasSize,
      initialPositions: _layout?.positions ?? const {},
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      _layout!.settle();
      _stopTicker();
    } else {
      _ensureTicker();
    }
    setState(() {});
  }

  void _ensureTicker() {
    if (_ticker != null) return;
    final ticker = createTicker((_) {
      final layout = _layout;
      if (!mounted || layout == null) {
        _stopTicker();
        return;
      }
      final moving = layout.tick();
      setState(() {});
      if (!moving) _stopTicker();
    });
    _ticker = ticker;
    ticker.start();
  }

  void _stopTicker() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
  }

  void _toggleKind(PhotoRelationNodeType type) {
    setState(() {
      if (_enabledKinds.contains(type)) {
        if (_enabledKinds.length == 1) return;
        _enabledKinds = {..._enabledKinds}..remove(type);
      } else {
        _enabledKinds = {..._enabledKinds, type};
      }
      _selectedNodeId = null;
    });
    _refreshLayoutIfChanged(_currentData());
  }

  @override
  Widget build(BuildContext context) {
    final data = _currentData();
    final query = widget.state.searchQuery.trim();
    final selected =
        data.nodes.where((node) => node.id == _selectedNodeId).firstOrNull;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final minHeight =
            constraints.hasBoundedHeight ? constraints.maxHeight : 640.0;
        final slivers =
            selected == null
                ? _buildGraphSlivers(context, data, query, compact)
                : <Widget>[
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 16 : 24,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _GraphDetail(
                        key: ValueKey(selected.id),
                        node: selected,
                        onBack: () {
                          if (mounted) {
                            setState(() => _selectedNodeId = null);
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
            key: const Key('photo-graph-canvas'),
            decoration: BoxDecoration(color: context.photosColors.surface),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                ...slivers,
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildGraphSlivers(
    BuildContext context,
    PhotoGraphData data,
    String query,
    bool compact,
  ) {
    final l10n = AppLocalizations.of(context);
    final colors = context.photosColors;
    final isLoading = widget.state.isLoadingRelationGraph;
    final horizontal = EdgeInsets.symmetric(horizontal: compact ? 16 : 24);

    final result = <Widget>[
      SliverPadding(
        padding: horizontal.copyWith(top: 16),
        sliver: SliverToBoxAdapter(
          child: _GraphFilterBar(
            enabledKinds: _enabledKinds,
            onToggle: _toggleKind,
            isLoading: isLoading,
          ),
        ),
      ),
    ];

    if (widget.state.relationGraphError != null) {
      result.add(
        SliverPadding(
          padding: horizontal.copyWith(top: 10),
          sliver: SliverToBoxAdapter(
            child: Text(
              widget.state.relationGraphError!,
              style: TextStyle(color: colors.danger),
            ),
          ),
        ),
      );
    }

    if (data.truncated) {
      result.add(
        SliverPadding(
          padding: horizontal.copyWith(top: 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              l10n.photosGraphTruncated,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ),
      );
    }

    if (query.isNotEmpty) {
      result.add(
        SliverPadding(
          padding: horizontal.copyWith(top: 10),
          sliver: SliverToBoxAdapter(child: _GraphSearchStatus(query: query)),
        ),
      );
    }

    if (data.nodes.isEmpty) {
      result.add(
        SliverPadding(
          padding: horizontal,
          sliver: SliverToBoxAdapter(
            child: _GraphEmptyState(
              isLoading: isLoading,
              hasSearch: query.isNotEmpty,
              onRetry: isLoading ? null : () => unawaited(_loadRelationGraph()),
            ),
          ),
        ),
      );
      return result;
    }

    result.add(
      SliverPadding(
        padding: horizontal.copyWith(top: 16, bottom: 8),
        sliver: SliverToBoxAdapter(
          child: _buildGraphCanvas(context, data, colors),
        ),
      ),
    );
    return result;
  }

  Widget _buildGraphCanvas(
    BuildContext context,
    PhotoGraphData data,
    PhotosColors colors,
  ) {
    final layout = _layout;
    if (layout == null) {
      return const SizedBox(height: 520);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: SizedBox(
          height: 560,
          child: InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(600),
            minScale: 0.3,
            maxScale: 2.5,
            child: SizedBox(
              width: layout.size.width,
              height: layout.size.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      size: layout.size,
                      painter: _GraphEdgePainter(
                        layout: layout,
                        edges: data.edges,
                        color: colors.outlineVariant,
                      ),
                    ),
                  ),
                  for (final node in data.nodes)
                    _buildNodeWidget(context, layout, node),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNodeWidget(
    BuildContext context,
    PhotoGraphLayout layout,
    PhotoGraphNode node,
  ) {
    final l10n = AppLocalizations.of(context);
    final radius = (30 + math.sqrt(node.weight.toDouble()) * 3).clamp(
      28.0,
      58.0,
    );
    final position = layout.positionOf(node.id);
    return Positioned(
      left: position.dx - radius,
      top: position.dy - radius,
      width: radius * 2 + 24,
      child: _GraphNodeChip(
        node: node,
        radius: radius,
        selected: _selectedNodeId == node.id,
        semanticLabel: '${node.label}, ${_nodeCountLabel(l10n, node)}',
        onTap: () {
          if (mounted) {
            setState(() => _selectedNodeId = node.id);
          }
        },
      ),
    );
  }
}
