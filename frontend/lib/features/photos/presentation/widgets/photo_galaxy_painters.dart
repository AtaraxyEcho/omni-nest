part of 'photo_galaxy_view.dart';

String _formatGalaxyDate(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatMediumDate(date.toLocal());
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.18);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 0.72,
        height: size.height * 0.34,
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _GalaxyBackdropPainter extends CustomPainter {
  const _GalaxyBackdropPainter({required this.colors});

  final PhotosColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final starPaint =
        Paint()..color = colors.galaxyOnCanvas.withValues(alpha: 0.24);
    final brightStarPaint =
        Paint()..color = colors.galaxyGlow.withValues(alpha: 0.52);
    final crossPaint =
        Paint()..color = colors.galaxyGlow.withValues(alpha: 0.26);
    final linePaint =
        Paint()
          ..color = colors.galaxyLine.withValues(alpha: 0.46)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    const points = <Offset>[
      Offset(0.08, 0.16),
      Offset(0.16, 0.44),
      Offset(0.22, 0.72),
      Offset(0.31, 0.11),
      Offset(0.38, 0.28),
      Offset(0.46, 0.58),
      Offset(0.55, 0.82),
      Offset(0.63, 0.39),
      Offset(0.71, 0.18),
      Offset(0.78, 0.88),
      Offset(0.86, 0.64),
      Offset(0.94, 0.27),
    ];
    for (var index = 0; index < points.length; index++) {
      final point = Offset(
        size.width * points[index].dx,
        size.height * points[index].dy,
      );
      final isBright = index % 4 == 0;
      canvas.drawCircle(
        point,
        isBright ? 1.4 : 0.75,
        isBright ? brightStarPaint : starPaint,
      );
      if (isBright) {
        canvas.drawLine(
          point.translate(-3.5, 0),
          point.translate(3.5, 0),
          crossPaint,
        );
        canvas.drawLine(
          point.translate(0, -3.5),
          point.translate(0, 3.5),
          crossPaint,
        );
      }
    }
    const links = <List<int>>[
      [0, 3, 4],
      [2, 5, 7],
      [6, 8, 9],
    ];
    for (final link in links) {
      final path = Path();
      for (var index = 0; index < link.length; index++) {
        final point = points[link[index]];
        final scaled = Offset(size.width * point.dx, size.height * point.dy);
        if (index == 0) {
          path.moveTo(scaled.dx, scaled.dy);
        } else {
          path.lineTo(scaled.dx, scaled.dy);
        }
      }
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GalaxyBackdropPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}
