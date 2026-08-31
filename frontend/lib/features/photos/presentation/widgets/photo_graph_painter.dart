part of 'photo_graph_view.dart';

/// 关系边绘制器：连线透明度按共现照片数衰减，避免稠密边淹没画布。
class _GraphEdgePainter extends CustomPainter {
  const _GraphEdgePainter({
    required this.layout,
    required this.edges,
    required this.color,
  });

  final PhotoGraphLayout layout;
  final List<PhotoGraphEdge> edges;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    for (final edge in edges) {
      final source = layout.positionOf(edge.sourceId);
      final target = layout.positionOf(edge.targetId);
      final alpha = 0.14 + 0.3 * (1.0 - (1.0 / (1.0 + edge.weight * 0.4)));
      paint.color = color.withValues(alpha: alpha);
      canvas.drawLine(source, target, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphEdgePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.edges != edges ||
        oldDelegate.layout != layout;
  }
}
