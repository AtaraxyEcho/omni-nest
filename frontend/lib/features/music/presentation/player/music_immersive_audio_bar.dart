part of 'music_immersive_player.dart';

class _MusicImmersiveAudioBar extends StatelessWidget {
  const _MusicImmersiveAudioBar({
    required this.palette,
    required this.spectrum,
    required this.settings,
    required this.style,
  });

  final MusicImmersivePalette palette;
  final ValueListenable<MusicSpectrumFrame> spectrum;
  final PortalSpectrumVisualSettings settings;
  final MusicAudioBarStyle style;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _MusicImmersiveAudioBarPainter(
            palette: palette,
            spectrum: spectrum,
            settings: settings,
            style: style,
          ),
        ),
      ),
    );
  }
}

class _MusicImmersiveAudioBarPainter extends CustomPainter {
  _MusicImmersiveAudioBarPainter({
    required this.palette,
    required this.spectrum,
    required this.settings,
    required this.style,
  }) : super(repaint: spectrum);

  final MusicImmersivePalette palette;
  final ValueListenable<MusicSpectrumFrame> spectrum;
  final PortalSpectrumVisualSettings settings;
  final MusicAudioBarStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final frame = spectrum.value;
    final bands = frame.bands;
    final active = frame.active && bands.isNotEmpty;
    switch (style) {
      case MusicAudioBarStyle.spectrumBars:
        _paintSpectrumBars(canvas, size, bands, active);
        return;
      case MusicAudioBarStyle.lineWave:
        _paintLineWave(canvas, size, bands, active);
        return;
      case MusicAudioBarStyle.pulseDots:
        _paintPulseDots(canvas, size, bands, active);
        return;
    }
  }

  void _paintSpectrumBars(
    Canvas canvas,
    Size size,
    List<double> bands,
    bool active,
  ) {
    final barCount = (size.width / 14).floor().clamp(24, 52);
    final gap = (size.width / barCount * 0.34).clamp(2.0, 4.0);
    final barWidth = ((size.width - gap * (barCount - 1)) / barCount).clamp(
      2.0,
      8.0,
    );
    final usedWidth = barWidth * barCount + gap * (barCount - 1);
    final startX = (size.width - usedWidth) / 2;
    final centerY = size.height * 0.58;
    final upperExtent = math.max(4.0, centerY - 3);
    final lowerExtent = math.max(3.0, size.height - centerY - 3);

    final railPaint =
        Paint()
          ..strokeWidth = 1
          ..color = palette.text.withValues(alpha: active ? 0.12 : 0.07);
    canvas.drawLine(
      Offset(startX, centerY),
      Offset(startX + usedWidth, centerY),
      railPaint,
    );

    for (var index = 0; index < barCount; index++) {
      final progress = barCount <= 1 ? 0.0 : index / (barCount - 1);
      final raw = active ? _sampleBand(bands, progress) : 0.018;
      final amplitude = _amplitude(raw, progress);
      final upperHeight = 2.5 + amplitude * (upperExtent - 2.5);
      final lowerHeight = 1.5 + amplitude * (lowerExtent - 1.5) * 0.62;
      final color = _frequencyColor(progress);
      final alpha = active ? 0.48 + amplitude * 0.46 : 0.12;
      final paint = Paint()..color = color.withValues(alpha: alpha);
      final x = startX + index * (barWidth + gap);
      final radius = Radius.circular(math.min(3.0, barWidth / 2));
      final upperRect = Rect.fromLTWH(
        x,
        centerY - upperHeight,
        barWidth,
        upperHeight,
      );
      final lowerRect = Rect.fromLTWH(x, centerY + 1, barWidth, lowerHeight);
      canvas.drawRRect(RRect.fromRectAndRadius(upperRect, radius), paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(lowerRect, radius),
        paint..color = color.withValues(alpha: alpha * 0.44),
      );
    }
  }

  void _paintLineWave(
    Canvas canvas,
    Size size,
    List<double> bands,
    bool active,
  ) {
    final count = (size.width / 9).floor().clamp(40, 96);
    final centerY = size.height * 0.58;
    final extent = math.max(4.0, size.height * 0.48);
    final path = Path();
    for (var index = 0; index < count; index++) {
      final progress = index / (count - 1);
      final raw = active ? _sampleBand(bands, progress) : 0.018;
      final point = Offset(
        progress * size.width,
        centerY - _amplitude(raw, progress) * extent,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    final bounds = Offset.zero & size;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = palette.glow.withValues(alpha: active ? 0.24 : 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [palette.accentAlt, palette.accent, palette.text],
        ).createShader(bounds),
    );
  }

  void _paintPulseDots(
    Canvas canvas,
    Size size,
    List<double> bands,
    bool active,
  ) {
    final count = (size.width / 18).floor().clamp(24, 52);
    final centerY = size.height / 2;
    final extent = math.max(3.0, size.height * 0.34);
    final spacing = size.width / count;
    for (var index = 0; index < count; index++) {
      final progress = count <= 1 ? 0.0 : index / (count - 1);
      final raw = active ? _sampleBand(bands, progress) : 0.018;
      final amplitude = _amplitude(raw, progress);
      final radius = 1.5 + amplitude * 3.8;
      final offset = 1.5 + amplitude * extent;
      final paint =
          Paint()
            ..color = _frequencyColor(
              progress,
            ).withValues(alpha: active ? 0.42 + amplitude * 0.5 : 0.12);
      final x = spacing * (index + 0.5);
      canvas.drawCircle(Offset(x, centerY - offset), radius, paint);
      canvas.drawCircle(
        Offset(x, centerY + offset * 0.64),
        radius * 0.62,
        paint..color = paint.color.withValues(alpha: paint.color.a * 0.42),
      );
    }
  }

  double _amplitude(double raw, double progress) {
    final response =
        progress < 0.32
            ? settings.lowResponse
            : progress < 0.68
            ? settings.midResponse
            : settings.highResponse;
    return (math.pow(raw, 0.62).toDouble() * response)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _sampleBand(List<double> bands, double progress) {
    if (bands.length == 1) {
      return bands.first.clamp(0.0, 1.0);
    }
    final position = progress * (bands.length - 1);
    final lower = position.floor();
    final upper = math.min(lower + 1, bands.length - 1);
    final fraction = position - lower;
    return (bands[lower] + (bands[upper] - bands[lower]) * fraction).clamp(
      0.0,
      1.0,
    );
  }

  Color _frequencyColor(double progress) {
    if (progress < 0.30) {
      return Color.lerp(palette.accentAlt, palette.accent, progress / 0.30)!;
    }
    if (progress < 0.72) {
      return palette.accent;
    }
    return Color.lerp(
      palette.accent,
      palette.text,
      ((progress - 0.72) / 0.28) * 0.48,
    )!;
  }

  @override
  bool shouldRepaint(covariant _MusicImmersiveAudioBarPainter oldDelegate) {
    return oldDelegate.palette != palette ||
        oldDelegate.spectrum != spectrum ||
        oldDelegate.settings != settings ||
        oldDelegate.style != style;
  }
}
