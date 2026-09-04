import 'dart:math' as math;
import 'dart:ui';

import 'package:omninest/features/photos/domain/photo_album.dart';
import 'package:omninest/features/photos/domain/photo_relation.dart';

/// 图谱节点渲染数量上限：超出后按权重截断，保证布局模拟的交互性能。
const maxPhotoGraphNodes = 120;

/// 图谱边渲染数量上限。
const maxPhotoGraphEdges = 260;

/// 图谱数据：节点与边均为已解析展示信息的视图模型。
class PhotoGraphData {
  const PhotoGraphData({
    required this.nodes,
    required this.edges,
    required this.truncated,
  });

  final List<PhotoGraphNode> nodes;
  final List<PhotoGraphEdge> edges;
  final bool truncated;
}

/// 图谱节点视图模型。
class PhotoGraphNode {
  const PhotoGraphNode({
    required this.id,
    required this.type,
    required this.key,
    required this.label,
    required this.weight,
    this.coverUrl,
  });

  final String id;
  final PhotoRelationNodeType type;
  final String key;

  /// 展示名；相册为空时由界面回退到「未命名相册」。
  final String label;
  final int weight;
  final String? coverUrl;
}

/// 图谱边视图模型，端点为 [PhotoGraphNode.id]。
class PhotoGraphEdge {
  const PhotoGraphEdge({
    required this.sourceId,
    required this.targetId,
    required this.weight,
  });

  final String sourceId;
  final String targetId;
  final int weight;
}

/// 将关系端点数据构建为可渲染图谱。
///
/// 纯函数：类型筛选、搜索过滤与数量截断都在此完成，便于测试。
/// 人物维度已随人物页下线，后端返回的 PERSON 节点与相关边在此被过滤。
PhotoGraphData buildPhotoGraph({
  required PhotoRelationGraph relation,
  required Set<PhotoRelationNodeType> kinds,
  required String query,
  Iterable<PhotoAlbum> albums = const [],
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final albumCovers = {for (final album in albums) album.id: album.coverUrl};

  final allNodes =
      relation.nodes
          .where((node) => node.type != PhotoRelationNodeType.person)
          .where((node) => kinds.contains(node.type))
          .map((node) {
            final label = switch (node.type) {
              PhotoRelationNodeType.time ||
              PhotoRelationNodeType.location => node.label ?? node.key,
              PhotoRelationNodeType.album ||
              PhotoRelationNodeType.person => node.label ?? '',
            };
            final coverUrl = switch (node.type) {
              PhotoRelationNodeType.album => albumCovers[node.key],
              PhotoRelationNodeType.time ||
              PhotoRelationNodeType.location => null,
              PhotoRelationNodeType.person => null,
            };
            return PhotoGraphNode(
              id: '${node.type.value}:${node.key}',
              type: node.type,
              key: node.key,
              label: label,
              weight: node.weight,
              coverUrl: coverUrl,
            );
          })
          .where((node) {
            if (normalizedQuery.isEmpty) return true;
            return node.label.toLowerCase().contains(normalizedQuery);
          })
          .toList()
        ..sort((left, right) {
          final byWeight = right.weight.compareTo(left.weight);
          return byWeight != 0 ? byWeight : left.id.compareTo(right.id);
        });

  final truncatedByNodes = allNodes.length > maxPhotoGraphNodes;
  final nodes =
      truncatedByNodes ? allNodes.take(maxPhotoGraphNodes).toList() : allNodes;
  final nodeIds = nodes.map((node) => node.id).toSet();

  final allEdges =
      relation.edges
          .map(
            (edge) => PhotoGraphEdge(
              sourceId: '${edge.sourceType.value}:${edge.sourceKey}',
              targetId: '${edge.targetType.value}:${edge.targetKey}',
              weight: edge.weight,
            ),
          )
          .where(
            (edge) =>
                nodeIds.contains(edge.sourceId) &&
                nodeIds.contains(edge.targetId),
          )
          .toList()
        ..sort((left, right) {
          final byWeight = right.weight.compareTo(left.weight);
          return byWeight != 0
              ? byWeight
              : left.sourceId.compareTo(right.sourceId);
        });

  final truncatedByEdges = allEdges.length > maxPhotoGraphEdges;
  final edges =
      truncatedByEdges ? allEdges.take(maxPhotoGraphEdges).toList() : allEdges;

  return PhotoGraphData(
    nodes: nodes,
    edges: edges,
    truncated: relation.truncated || truncatedByNodes || truncatedByEdges,
  );
}

/// 力导向布局：斥力 + 弹簧 + 向心力，确定性初始化（按类型同心圆分布）。
class PhotoGraphLayout {
  PhotoGraphLayout({
    required List<PhotoGraphNode> nodes,
    required List<PhotoGraphEdge> edges,
    required this.size,
    Map<String, Offset> initialPositions = const {},
  }) : edges = List.unmodifiable(edges) {
    positions = <String, Offset>{};
    final byKind = <PhotoRelationNodeType, List<PhotoGraphNode>>{};
    for (final node in nodes) {
      byKind.putIfAbsent(node.type, () => []).add(node);
    }
    final center = Offset(size.width / 2, size.height / 2);
    final kinds =
        byKind.keys.toList()..sort((a, b) => a.value.compareTo(b.value));
    for (var kindIndex = 0; kindIndex < kinds.length; kindIndex++) {
      final kindNodes = byKind[kinds[kindIndex]]!;
      final ringRadius = baseRingRadius + kindIndex * ringGap;
      for (var index = 0; index < kindNodes.length; index++) {
        final node = kindNodes[index];
        final existing = initialPositions[node.id];
        positions[node.id] =
            existing ??
            center +
                Offset.fromDirection(
                  _angleFor(index, kindNodes.length),
                  ringRadius,
                );
      }
    }
    for (final node in nodes) {
      positions.putIfAbsent(node.id, () => center);
    }
    velocities = {for (final id in positions.keys) id: Offset.zero};
  }

  static const baseRingRadius = 180.0;
  static const ringGap = 140.0;

  /// 虚拟画布尺寸。
  final Size size;

  /// 边（端点为节点 ID）。
  final List<PhotoGraphEdge> edges;

  late final Map<String, Offset> positions;
  late final Map<String, Offset> velocities;
  double _kinetic = double.maxFinite;

  /// 最近一次 tick 后的总动能，低于阈值视为布局稳定。
  double get kineticEnergy => _kinetic;

  Offset positionOf(String id) =>
      positions[id] ?? Offset(size.width / 2, size.height / 2);

  /// 推进一步模拟；返回是否仍有明显运动。
  bool tick() {
    if (positions.isEmpty) return false;
    final center = Offset(size.width / 2, size.height / 2);
    final ids = positions.keys.toList(growable: false);
    final forces = <String, Offset>{for (final id in ids) id: Offset.zero};

    // 节点间斥力。
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final delta = positions[ids[i]]! - positions[ids[j]]!;
        var distance = delta.distance;
        if (distance < 1) {
          distance = 1;
        }
        final strength = repulsion / (distance * distance);
        final unit = delta / distance;
        forces[ids[i]] = forces[ids[i]]! + unit * strength;
        forces[ids[j]] = forces[ids[j]]! - unit * strength;
      }
    }

    // 边弹簧。
    for (final edge in edges) {
      final source = positions[edge.sourceId];
      final target = positions[edge.targetId];
      if (source == null || target == null) continue;
      final delta = target - source;
      final distance = math.max(delta.distance, 1.0);
      final strength = (distance - restLength) * spring;
      final unit = delta / distance;
      forces[edge.sourceId] = forces[edge.sourceId]! + unit * strength;
      forces[edge.targetId] = forces[edge.targetId]! - unit * strength;
    }

    // 向心力。
    for (final id in ids) {
      forces[id] = forces[id]! + (center - positions[id]!) * gravity;
    }

    var kinetic = 0.0;
    for (final id in ids) {
      var velocity = (velocities[id]! + forces[id]!) * damping;
      final speed = velocity.distance;
      if (speed > maxSpeed) {
        velocity = velocity / speed * maxSpeed;
      }
      velocities[id] = velocity;
      final next = positions[id]! + velocity;
      // 边界钳制：节点中心保留 160px 边距，避免节点标签被画布边缘裁切。
      positions[id] = Offset(
        next.dx.clamp(edgeInset, size.width - edgeInset),
        next.dy.clamp(edgeInset, size.height - edgeInset),
      );
      kinetic += velocity.distanceSquared;
    }
    _kinetic = kinetic;
    return kinetic > settleThreshold;
  }

  /// 不播放动画时直接迭代到稳定或达到上限。
  void settle({int maxTicks = 300}) {
    var ticks = 0;
    while (ticks < maxTicks && tick()) {
      ticks++;
    }
  }

  static double _angleFor(int index, int total) {
    if (total <= 1) return 0;
    return 2 * math.pi * index / total;
  }

  static const repulsion = 220000.0;
  static const restLength = 170.0;
  static const spring = 0.035;
  static const gravity = 0.03;
  static const damping = 0.82;
  static const maxSpeed = 26.0;
  static const settleThreshold = 0.4;
  static const edgeInset = 160.0;
}
