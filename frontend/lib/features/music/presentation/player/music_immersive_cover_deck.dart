part of 'music_immersive_player.dart';

class MusicImmersiveCoverDeck extends StatefulWidget {
  const MusicImmersiveCoverDeck({
    super.key,
    required this.palette,
    required this.tracks,
    required this.selectedIndex,
    required this.currentTrack,
    required this.expanded,
    required this.scale,
    required this.onSelected,
    required this.onStep,
  });

  final MusicImmersivePalette palette;
  final List<MusicTrack> tracks;
  final int selectedIndex;
  final MusicTrack? currentTrack;
  final bool expanded;
  final double scale;
  final ValueChanged<int> onSelected;
  final ValueChanged<int> onStep;

  @override
  State<MusicImmersiveCoverDeck> createState() =>
      _DigitalImmersiveCoverDeckState();
}

class _DigitalImmersiveCoverDeckState extends State<MusicImmersiveCoverDeck> {
  Offset _activeCardDragOffset = Offset.zero;
  int? _dragPointer;
  Offset? _dragOrigin;
  bool _dragActive = false;
  bool _thresholdFeedbackSent = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) {
          return;
        }
        if (event.scrollDelta.dy > 6) {
          widget.onStep(1);
        } else if (event.scrollDelta.dy < -6) {
          widget.onStep(-1);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: 8 * widget.scale,
            bottom: 8 * widget.scale,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children:
                  widget.tracks.isEmpty
                      ? [
                        _DigitalCoverDeckCard(
                          palette: widget.palette,
                          track: widget.currentTrack,
                          scale: widget.scale,
                          active: true,
                          offset: 0,
                          expanded: widget.expanded,
                          dragging: _dragActive,
                          dragOffset: _activeCardDragOffset,
                          onTap: () {},
                          onPointerDown: _handlePointerDown,
                          onPointerMove: _handlePointerMove,
                          onPointerUp: _handlePointerUp,
                          onPointerCancel: _handlePointerCancel,
                        ),
                      ]
                      : [
                        for (final offset in _deckPaintOrder)
                          _buildStaticDeckCard(offset),
                        _buildActiveDeckCard(),
                      ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticDeckCard(int offset) {
    final index = widget.selectedIndex + offset;
    if (index < 0 || index >= widget.tracks.length) {
      return const SizedBox.shrink();
    }
    final active =
        widget.tracks[index].id == widget.currentTrack?.id ||
        index == widget.selectedIndex;
    return _DigitalCoverDeckCard(
      key: ValueKey('${widget.tracks[index].id}-$offset'),
      palette: widget.palette,
      track: widget.tracks[index],
      scale: widget.scale,
      active: active,
      offset: offset,
      expanded: widget.expanded,
      onTap: () => widget.onSelected(index),
    );
  }

  Widget _buildActiveDeckCard() {
    final index = widget.selectedIndex;
    if (index < 0 || index >= widget.tracks.length) {
      return const SizedBox.shrink();
    }
    return _DigitalCoverDeckCard(
      key: ValueKey('${widget.tracks[index].id}-active'),
      palette: widget.palette,
      track: widget.tracks[index],
      scale: widget.scale,
      active: true,
      offset: 0,
      expanded: widget.expanded,
      dragging: _dragActive,
      dragOffset: _activeCardDragOffset,
      onTap: () => widget.onSelected(index),
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
    );
  }

  static const _deckPaintOrder = <int>[4, 3, 2, 1];

  void _handlePointerDown(PointerDownEvent event) {
    final secondaryMouseDown =
        event.kind == PointerDeviceKind.mouse &&
        event.buttons == kSecondaryMouseButton;
    if (secondaryMouseDown || _dragPointer != null) {
      return;
    }
    _dragPointer = event.pointer;
    _dragOrigin = event.position;
    setState(() {
      _dragActive = true;
      _activeCardDragOffset = Offset.zero;
      _thresholdFeedbackSent = false;
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _dragPointer) {
      return;
    }
    _updateCardDrag(event.position);
  }

  void _updateCardDrag(Offset position) {
    final origin = _dragOrigin;
    if (origin == null) {
      return;
    }
    final maxOffset = (150 * widget.scale).clamp(110.0, 190.0).toDouble();
    final delta = position - origin;
    final nextOffset = Offset(
      delta.dx.clamp(-maxOffset, maxOffset).toDouble(),
      delta.dy.clamp(-maxOffset, maxOffset).toDouble(),
    );
    if (!_thresholdFeedbackSent &&
        _dominantDrag(nextOffset).abs() >= _dragThreshold) {
      _thresholdFeedbackSent = true;
      unawaited(HapticFeedback.selectionClick());
    }
    setState(() => _activeCardDragOffset = nextOffset);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _dragPointer) {
      return;
    }
    final delta = _resolveDragDelta(_activeCardDragOffset);
    final target =
        (widget.selectedIndex + delta)
            .clamp(0, math.max(0, widget.tracks.length - 1))
            .toInt();
    _resetDrag();
    if (delta == 0 || target == widget.selectedIndex) {
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    widget.onSelected(target);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _dragPointer) {
      return;
    }
    _resetDrag();
  }

  void _resetDrag() {
    if (!mounted) {
      return;
    }
    _clearPointerTracking();
    setState(() {
      _dragActive = false;
      _activeCardDragOffset = Offset.zero;
      _thresholdFeedbackSent = false;
    });
  }

  void _clearPointerTracking() {
    _dragPointer = null;
    _dragOrigin = null;
  }

  double _dominantDrag(Offset offset) {
    return offset.dx.abs() >= offset.dy.abs() ? offset.dx : offset.dy;
  }

  int _resolveDragDelta(Offset offset) {
    final drag = _dominantDrag(offset);
    if (drag.abs() < _dragThreshold) {
      return 0;
    }
    return drag.isNegative ? 1 : -1;
  }

  double get _dragThreshold => (46 * widget.scale).clamp(36.0, 62.0).toDouble();
}

class _DigitalCoverDeckCard extends StatelessWidget {
  const _DigitalCoverDeckCard({
    super.key,
    required this.palette,
    required this.track,
    required this.scale,
    required this.active,
    required this.offset,
    required this.expanded,
    this.dragging = false,
    this.dragOffset = Offset.zero,
    required this.onTap,
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onPointerCancel,
  });

  final MusicImmersivePalette palette;
  final MusicTrack? track;
  final double scale;
  final bool active;
  final int offset;
  final bool expanded;
  final bool dragging;
  final Offset dragOffset;
  final VoidCallback onTap;
  final PointerDownEventListener? onPointerDown;
  final PointerMoveEventListener? onPointerMove;
  final PointerUpEventListener? onPointerUp;
  final PointerCancelEventListener? onPointerCancel;

  @override
  Widget build(BuildContext context) {
    final absOffset = offset.abs();
    final depthScale =
        (1 - absOffset * (expanded ? 0.082 : 0.10)).clamp(0.56, 1.0).toDouble();
    final cardSize =
        (expanded ? 250 * scale : 204 * scale).clamp(132.0, 292.0).toDouble();
    final dx = offset * (expanded ? 48 : 30) * scale;
    final dy = offset.abs() * (expanded ? 28 : 22) * scale;
    final yRotation = -0.22 + offset * 0.045;
    final zLift = -absOffset * 34.0;
    return AnimatedPositioned(
      duration: MusicImmersiveMotion.duration(
        context,
        const Duration(milliseconds: 260),
      ),
      curve: Curves.easeOutCubic,
      left: expanded ? 0 : -14 * scale,
      right: 0,
      top: (expanded ? 34 : 42) * scale + dy,
      child: AnimatedContainer(
        duration:
            dragging
                ? Duration.zero
                : MusicImmersiveMotion.duration(
                  context,
                  const Duration(milliseconds: 220),
                ),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(dx, 0, 0),
        transformAlignment: Alignment.center,
        child: Transform.rotate(
          angle: offset * 0.035,
          child: Transform(
            alignment: Alignment.center,
            transform:
                Matrix4.identity()
                  ..setEntry(3, 2, 0.0013)
                  ..translateByDouble(0.0, 0.0, zLift, 1.0)
                  ..rotateY(yRotation),
            child: Transform.scale(
              scale: depthScale,
              child: Center(
                child: _DeckCardPressFeedback(
                  cursor:
                      onPointerDown == null
                          ? SystemMouseCursors.click
                          : dragging
                          ? SystemMouseCursors.grabbing
                          : SystemMouseCursors.grab,
                  onTap: onTap,
                  onPointerDown: onPointerDown,
                  onPointerMove: onPointerMove,
                  onPointerUp: onPointerUp,
                  onPointerCancel: onPointerCancel,
                  child: RepaintBoundary(
                    child: AnimatedContainer(
                      key: ValueKey(
                        '${track?.id ?? 'empty'}-drag-surface-$offset',
                      ),
                      duration:
                          dragging
                              ? Duration.zero
                              : MusicImmersiveMotion.duration(
                                context,
                                const Duration(milliseconds: 180),
                              ),
                      curve: Curves.easeOutCubic,
                      transform: Matrix4.translationValues(
                        dragOffset.dx * 0.62,
                        dragOffset.dy * 0.28,
                        0,
                      ),
                      transformAlignment: Alignment.center,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: active ? 0.36 : 0.28,
                              ),
                              blurRadius: active ? 24 : 14,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            _MusicImmersiveArtwork(
                              imageUrl: track?.coverUrl,
                              width: cardSize,
                              height: cardSize,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(8),
                              cacheWidth: 560,
                              cacheHeight: 560,
                              fallback: Container(
                                width: cardSize,
                                height: cardSize,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color.lerp(
                                        palette.surfaceStrong.withValues(
                                          alpha: 1,
                                        ),
                                        palette.accent.withValues(alpha: 1),
                                        0.28,
                                      )!,
                                      palette.surfaceStrong.withValues(
                                        alpha: 1,
                                      ),
                                      Color.lerp(
                                        palette.surfaceStrong.withValues(
                                          alpha: 1,
                                        ),
                                        palette.accentAlt.withValues(alpha: 1),
                                        0.24,
                                      )!,
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.music_note_rounded,
                                  color: palette.text.withValues(alpha: 0.86),
                                  size: cardSize * 0.26,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          active
                                              ? palette.accentAlt.withValues(
                                                alpha: 0.64,
                                              )
                                              : Colors.white.withValues(
                                                alpha: 0.12,
                                              ),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.14),
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.28),
                                      ],
                                      stops: const [0, 0.44, 1],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeckCardPressFeedback extends StatefulWidget {
  const _DeckCardPressFeedback({
    required this.cursor,
    required this.onTap,
    required this.child,
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onPointerCancel,
  });

  final MouseCursor cursor;
  final VoidCallback onTap;
  final Widget child;
  final PointerDownEventListener? onPointerDown;
  final PointerMoveEventListener? onPointerMove;
  final PointerUpEventListener? onPointerUp;
  final PointerCancelEventListener? onPointerCancel;

  @override
  State<_DeckCardPressFeedback> createState() => _DeckCardPressFeedbackState();
}

class _DeckCardPressFeedbackState extends State<_DeckCardPressFeedback> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (event.kind != PointerDeviceKind.mouse ||
              event.buttons != kSecondaryMouseButton) {
            setState(() => _pressed = true);
          }
          widget.onPointerDown?.call(event);
        },
        onPointerMove: widget.onPointerMove,
        onPointerUp: (event) {
          if (_pressed) {
            setState(() => _pressed = false);
          }
          widget.onPointerUp?.call(event);
        },
        onPointerCancel: (event) {
          if (_pressed) {
            setState(() => _pressed = false);
          }
          widget.onPointerCancel?.call(event);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.965 : 1,
            duration: MusicImmersiveMotion.duration(
              context,
              Duration(milliseconds: _pressed ? 90 : 180),
            ),
            curve: Curves.easeOutCubic,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
