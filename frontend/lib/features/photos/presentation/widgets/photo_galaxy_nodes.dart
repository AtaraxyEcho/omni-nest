part of 'photo_galaxy_view.dart';

class _GalaxyNode extends StatelessWidget {
  const _GalaxyNode({
    super.key,
    required this.cluster,
    required this.fallbackTitle,
    required this.countLabel,
    required this.featured,
    required this.onTap,
  });

  final PhotoGalaxyCluster cluster;
  final String fallbackTitle;
  final String countLabel;
  final bool featured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = cluster.title.trim().isEmpty ? fallbackTitle : cluster.title;
    final colors = context.photosColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
    final favorite = cluster.photos.any((photo) => photo.favorite);
    final orbColor = favorite ? colors.tertiary : colors.primaryContainer;
    final imageUrls = <String>[
      if (cluster.coverUrl?.isNotEmpty == true) cluster.coverUrl!,
      ...cluster.photos
          .map((photo) => photo.coverUrl)
          .whereType<String>()
          .where((url) => url.isNotEmpty),
    ].take(4).toList(growable: false);

    return Semantics(
      button: true,
      label: '$title, $countLabel',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          focusColor: colors.galaxyLine.withValues(alpha: 0.5),
          hoverColor: colors.galaxyLine.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final orbSize = featured ? 98.0 : 74.0;
                return Column(
                  children: [
                    SizedBox(
                      height: featured ? 148 : 126,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _OrbitPainter(
                                color: colors.galaxyGlow.withValues(
                                  alpha: featured ? 0.7 : 0.45,
                                ),
                              ),
                            ),
                          ),
                          for (
                            var index = 1;
                            index < imageUrls.length && index < 4;
                            index++
                          )
                            Positioned(
                              left:
                                  (width * 0.5 - 14 + (index - 2) * 32)
                                      .clamp(0.0, width - 28)
                                      .toDouble(),
                              top:
                                  featured
                                      ? (index.isEven ? 22 : 104)
                                      : (index.isEven ? 18 : 88),
                              child: _GalaxyOrb(
                                url: imageUrls[index],
                                size: featured ? 32 : 24,
                                accent: false,
                                accentColor: orbColor,
                              ),
                            ),
                          _GalaxyOrb(
                            url: imageUrls.firstOrNull,
                            size: orbSize,
                            accent: true,
                            accentColor: orbColor,
                            favorite: favorite,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.galaxyOnCanvas,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedOpacity(
                      duration: duration,
                      opacity: 0.78,
                      child: Text(
                        countLabel,
                        style: TextStyle(
                          color: colors.galaxyMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GalaxyPlanet extends StatelessWidget {
  const _GalaxyPlanet({
    required this.photo,
    required this.size,
    required this.focused,
    required this.onFocus,
    required this.onOpen,
  });

  final PhotoItem photo;
  final double size;
  final bool focused;
  final VoidCallback onFocus;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.photosColors;
    final duration =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220);
    return Semantics(
      button: true,
      label: photo.title,
      child: Tooltip(
        message: photo.title,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(size / 2),
            focusColor: colors.galaxyLine,
            onTap: focused ? onOpen : onFocus,
            child: AnimatedScale(
              scale: focused ? 1.08 : 1,
              duration: duration,
              child: _GalaxyOrb(
                url: photo.coverUrl,
                size: size,
                accent: focused || photo.favorite,
                favorite: photo.favorite,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GalaxyOrb extends StatelessWidget {
  const _GalaxyOrb({
    required this.url,
    required this.size,
    required this.accent,
    this.favorite = false,
    this.accentColor,
  });

  final String? url;
  final double size;
  final bool accent;
  final bool favorite;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.photosColors;
    final borderColor =
        accentColor ?? (favorite ? colors.tertiary : colors.galaxyGlow);
    final child =
        url?.isNotEmpty == true
            ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              width: size,
              height: size,
              memCacheWidth: 180,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              errorWidget: (_, _, _) => _orbPlaceholder(colors, borderColor),
              placeholder: (_, _) => _orbPlaceholder(colors, borderColor),
            )
            : _orbPlaceholder(colors, borderColor);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor.withValues(alpha: accent ? 0.9 : 0.6),
          width: accent ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: accent ? 0.28 : 0.12),
            blurRadius: accent ? 16 : 7,
            spreadRadius: accent ? 1 : 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _orbPlaceholder(PhotosColors colors, Color color) {
    return ColoredBox(
      color: colors.galaxyPlaceholder,
      child: Center(
        child: Icon(
          Icons.photo_outlined,
          color: color.withValues(alpha: 0.7),
          size: size * 0.32,
        ),
      ),
    );
  }
}
