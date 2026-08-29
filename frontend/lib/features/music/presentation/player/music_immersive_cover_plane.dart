part of 'music_immersive_player.dart';

class _DigitalImmersiveCoverPlane extends StatelessWidget {
  const _DigitalImmersiveCoverPlane({
    required this.palette,
    required this.track,
    required this.spectrum,
    required this.visual,
    required this.size,
    required this.center,
    required this.scale,
  });

  final MusicImmersivePalette palette;
  final MusicTrack? track;
  final ValueListenable<MusicSpectrumFrame> spectrum;
  final PortalMusicVisualizerSettings visual;
  final double size;
  final Offset center;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final planeSize =
        (size * visual.coverElements.sizeScale * 0.84)
            .clamp(size * 0.62, size * 0.92)
            .toDouble();
    final coverOpacity = visual.coverElements.opacity.clamp(0.0, 1.0);
    final tiltRadians = visual.coverElements.tiltDegrees * math.pi / 180;
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            if (visual.coverElements.originalCoverEnabled)
              Positioned(
                left: center.dx - planeSize / 2,
                top: center.dy - planeSize / 2,
                width: planeSize,
                height: planeSize,
                child: Transform.rotate(
                  angle: tiltRadians,
                  child: Opacity(
                    opacity: coverOpacity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        visual.coverElements.cornerRadius,
                      ),
                      child: _MusicImmersiveArtwork(
                        imageUrl: track?.coverUrl,
                        width: planeSize,
                        height: planeSize,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(
                          visual.coverElements.cornerRadius,
                        ),
                        cacheWidth: 960,
                        cacheHeight: 960,
                        fallback: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                palette.accent.withValues(alpha: 0.22),
                                palette.surfaceStrong.withValues(alpha: 0.40),
                                palette.accentAlt.withValues(alpha: 0.20),
                              ],
                            ),
                          ),
                          child: SizedBox.square(
                            dimension: planeSize,
                            child: Icon(
                              Icons.music_note_rounded,
                              color: palette.text.withValues(alpha: 0.58),
                              size: planeSize * 0.18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (visual.coverElements.borderEnabled)
              Positioned.fill(
                child: CustomPaint(
                  painter: _DigitalCoverGlassRimPainter(
                    palette: palette,
                    spectrum: spectrum,
                    planeSize: planeSize,
                    planeCenter: center,
                    scale: scale,
                    radius: visual.coverElements.cornerRadius,
                    tiltRadians: tiltRadians,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DigitalCoverGlassRimPainter extends CustomPainter {
  _DigitalCoverGlassRimPainter({
    required this.palette,
    required this.spectrum,
    required this.planeSize,
    required this.planeCenter,
    required this.scale,
    required this.radius,
    required this.tiltRadians,
  }) : super(repaint: spectrum);

  final MusicImmersivePalette palette;
  final ValueListenable<MusicSpectrumFrame> spectrum;
  final double planeSize;
  final Offset planeCenter;
  final double scale;
  final double radius;
  final double tiltRadians;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final frame = spectrum.value;
    final active = frame.active;
    final beat = active ? frame.beat : 0.0;
    final energy = active ? frame.energy : 0.06;
    final rect = Rect.fromCenter(
      center: planeCenter,
      width: planeSize,
      height: planeSize,
    );
    final borderPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (0.80 + beat * 0.22) * scale
          ..color = Colors.white.withValues(alpha: 0.07 + energy * 0.05);
    canvas.save();
    canvas.translate(planeCenter.dx, planeCenter.dy);
    canvas.rotate(tiltRadians);
    canvas.translate(-planeCenter.dx, -planeCenter.dy);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      borderPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DigitalCoverGlassRimPainter oldDelegate) {
    return oldDelegate.palette != palette ||
        oldDelegate.spectrum != spectrum ||
        oldDelegate.planeSize != planeSize ||
        oldDelegate.planeCenter != planeCenter ||
        oldDelegate.scale != scale ||
        oldDelegate.radius != radius ||
        oldDelegate.tiltRadians != tiltRadians;
  }
}
