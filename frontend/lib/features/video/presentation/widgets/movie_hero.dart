import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:omninest/features/video/domain/movie_models.dart';

List<MovieVideoItem> movieHeroItems(List<MovieVideoItem> items) {
  final withImage = [
    for (final item in items)
      if (item.heroImageUrl != null) item,
  ];
  final source = withImage.isEmpty ? items : withImage;
  final sorted = List<MovieVideoItem>.from(source)..sort((a, b) {
    final aDate = a.releaseDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = b.releaseDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bDate.compareTo(aDate);
  });
  return sorted.take(9).toList(growable: false);
}

double movieHeroHeight(double width) {
  if (width >= 3200) return 780;
  if (width >= 2560) return 720;
  if (width >= 1920) return 620;
  if (width >= 1600) return 540;
  if (width >= 1280) return 460;
  if (width >= 960) return 380;
  if (width >= 720) return 320;
  if (width >= 480) return 240;
  return 200;
}

class MovieHeroCarousel extends StatefulWidget {
  const MovieHeroCarousel({required this.items, super.key});

  final List<MovieVideoItem> items;

  @override
  State<MovieHeroCarousel> createState() => _MovieHeroCarouselState();
}

class _MovieHeroCarouselState extends State<MovieHeroCarousel>
    with SingleTickerProviderStateMixin {
  static const _switchInterval = Duration(seconds: 30);
  static const _crossfadeDuration = Duration(milliseconds: 500);
  static const _cardFraction = 0.52;
  static const _centerScale = 1.05;
  static const _sideScale = 0.80;
  static const _sideAngle = 0.42;
  static const _perspective = 0.0012;
  static const _sideShiftFraction = 0.32;

  late final AnimationController _animCtrl;
  Timer? _timer;
  int _index = 0;
  bool _hovering = false;

  List<MovieVideoItem> get _items => widget.items;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: _crossfadeDuration);
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant MovieHeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_items.length != oldWidget.items.length) {
      _index = 0;
      _animCtrl.reset();
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_items.length < 2) return;
    _timer = Timer.periodic(_switchInterval, (_) {
      if (!mounted || _hovering || _items.length < 2) return;
      _animateTo(1);
    });
  }

  void _restartTimer() => _startTimer();

  void _animateTo(int delta) {
    if (_items.length < 2 || _animCtrl.isAnimating) return;
    _animCtrl.reset();
    _animCtrl.forward().then((_) {
      if (!mounted || _items.length < 2) return;
      setState(() {
        _index = (_index + delta) % _items.length;
        if (_index < 0) _index += _items.length;
      });
    });
  }

  void _goToPage(int target) {
    if (_items.length < 2 || _animCtrl.isAnimating) return;
    final delta = target - _index;
    if (delta == 0) return;
    _animateTo(delta);
  }

  int _sideIndex(int offset) {
    final raw = (_index + offset) % _items.length;
    return raw < 0 ? raw + _items.length : raw;
  }

  @override
  Widget build(BuildContext context) {
    final item = _items.isEmpty ? null : _items[_index % _items.length];
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight = movieHeroHeight(constraints.maxWidth);
        final w = constraints.maxWidth;
        final isNarrow = w < 600;
        return MouseRegion(
          cursor: SystemMouseCursors.basic,
          onEnter: (_) => _hovering = true,
          onExit: (_) => _hovering = false,
          child: Container(
            height: heroHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.videoColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    Theme.of(context).brightness == Brightness.light
                        ? context.videoColors.outlineVariant.withValues(
                          alpha: 0.40,
                        )
                        : context.videoColors.outlineVariant.withValues(
                          alpha: 0.18,
                        ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 32,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: _buildHeroStack(context, item, heroHeight, w, isNarrow),
          ),
        );
      },
    );
  }

  Widget _buildHeroStack(
    BuildContext context,
    MovieVideoItem? item,
    double heroHeight,
    double w,
    bool isNarrow,
  ) {
    if (_items.isEmpty) {
      return const Stack(
        fit: StackFit.expand,
        children: [Positioned.fill(child: _HeroPlaceholder())],
      );
    }

    if (isNarrow) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap:
                  item == null || item.id.isEmpty
                      ? null
                      : () => context.push('/video/${item.id}'),
              child: _HeroCardImage(url: _items[_index].heroImageUrl),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _MovieHeroOverlay(item: item),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: _CarouselIndicators(
              count: _items.length,
              current: _index % _items.length,
              onTap: _goToPage,
            ),
          ),
        ],
      );
    }

    // 桌面端：3D 轮播
    final cardWidth = w * _cardFraction;
    final centerLeft = (w - cardWidth * _centerScale) / 2;
    final sideShift = cardWidth * _sideShiftFraction;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_items.length >= 2)
          _build3DCard(
            left: centerLeft - sideShift,
            cardWidth: cardWidth,
            heroHeight: heroHeight,
            angle: _sideAngle,
            scale: _sideScale,
            url: _items[_sideIndex(-1)].heroImageUrl,
            onTap: () => _animateTo(-1),
          ),
        if (_items.length >= 2)
          _build3DCard(
            left: centerLeft + sideShift,
            cardWidth: cardWidth,
            heroHeight: heroHeight,
            angle: -_sideAngle,
            scale: _sideScale,
            url: _items[_sideIndex(1)].heroImageUrl,
            onTap: () => _animateTo(1),
          ),
        _build3DCard(
          left: centerLeft,
          cardWidth: cardWidth,
          heroHeight: heroHeight,
          angle: 0,
          scale: _centerScale,
          url: _items[_index].heroImageUrl,
          key: ValueKey(_index),
          onTap:
              item == null || item.id.isEmpty
                  ? null
                  : () => context.push('/video/${item.id}'),
        ),
        Positioned(
          left: centerLeft + 24,
          right: w - (centerLeft + cardWidth * _centerScale) + 24,
          bottom: 28,
          child: _MovieHeroOverlay(item: item),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 14,
          child: _CarouselIndicators(
            count: _items.length,
            current: _index % _items.length,
            onTap: _goToPage,
          ),
        ),
        if (_hovering && _items.length >= 2) ...[
          Positioned(
            left: 16,
            top: 0,
            bottom: 0,
            child: _CarouselArrow(
              icon: Icons.chevron_left_rounded,
              onTap: () => _animateTo(-1),
            ),
          ),
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: _CarouselArrow(
              icon: Icons.chevron_right_rounded,
              onTap: () => _animateTo(1),
            ),
          ),
        ],
      ],
    );
  }

  Widget _build3DCard({
    required double left,
    required double cardWidth,
    required double heroHeight,
    required double angle,
    required double scale,
    required String? url,
    VoidCallback? onTap,
    Key? key,
  }) {
    final scaledW = cardWidth * scale;
    final scaledH = heroHeight * scale;
    return Positioned(
      left: left,
      top: (heroHeight - scaledH) / 2,
      width: scaledW,
      height: scaledH,
      child: Transform(
        alignment: Alignment.center,
        transform:
            Matrix4.identity()
              ..setEntry(3, 2, _perspective)
              ..rotateY(angle),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            key: key,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: angle == 0 ? 0.18 : 0.10),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: angle == 0 ? 0.40 : 0.22,
                  ),
                  blurRadius: angle == 0 ? 32 : 18,
                  offset: Offset(0, angle == 0 ? 16 : 8),
                ),
              ],
            ),
            child: _HeroCardImage(url: url),
          ),
        ),
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      key: ValueKey('movie-hero-placeholder'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF201F3B), Color(0xFF35213B), Color(0xFF1A1825)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
    );
  }
}

class _HeroCardImage extends StatelessWidget {
  const _HeroCardImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) return const _CardFallback();
    return Image.network(
      url!,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      cacheWidth: 800,
      errorBuilder: (context, error, stackTrace) => const _CardFallback(),
    );
  }
}

class _CardFallback extends StatelessWidget {
  const _CardFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF201F3B), Color(0xFF35213B)],
        ),
      ),
    );
  }
}

class _CarouselIndicators extends StatelessWidget {
  const _CarouselIndicators({
    required this.count,
    required this.current,
    required this.onTap,
  });

  final int count;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < count; i++)
          GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: i == current ? 24 : 8,
              height: 8,
              margin: EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color:
                    i == current
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.36),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
      ],
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.40),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

class _MovieHeroOverlay extends StatelessWidget {
  const _MovieHeroOverlay({required this.item});

  final MovieVideoItem? item;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final current = item;
    return AnimatedSwitcher(
      duration:
          disableAnimations ? Duration.zero : const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child:
          current == null
              ? const _HeroContentFallback(key: ValueKey('movie-hero-empty'))
              : _HeroContent(key: ValueKey(current.id), item: current),
    );
  }
}

class _HeroContentFallback extends StatelessWidget {
  const _HeroContentFallback({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeroPill(label: l10n.videoHeroFeatured),
        SizedBox(height: 12),
        Text(
          l10n.videoHeroCenterTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            height: 38 / 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: 8),
        Text(
          l10n.videoHeroCenterSubtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 15,
            height: 22 / 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({super.key, required this.item});

  final MovieVideoItem item;

  static const _textShadow = Shadow(
    color: Color(0x99000000),
    blurRadius: 12,
    offset: Offset(0, 2),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 600;
    final titleFontSize = isNarrow ? 18.0 : 40.0;
    final titleHeight = isNarrow ? 24.0 / 18.0 : 46.0 / 40.0;
    final descFontSize = isNarrow ? 11.0 : 15.0;
    final descHeight = isNarrow ? 15.0 / 11.0 : 22.0 / 15.0;
    final descMaxLines = isNarrow ? 1 : 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _HeroPill(label: l10n.videoHeroFeatured),
            _HeroPill(
              label:
                  item.mediaType == 'MOVIE'
                      ? l10n.videoHeroMovie
                      : l10n.videoHeroTv,
            ),
            _HeroPill(label: item.year),
          ],
        ),
        SizedBox(height: isNarrow ? 8 : 14),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: titleFontSize,
            height: titleHeight,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            shadows: [_textShadow],
          ),
        ),
        SizedBox(height: isNarrow ? 6 : 10),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isNarrow ? screenWidth - 40 : 520,
          ),
          child: Text(
            item.overview ?? l10n.videoHeroFallbackOverview,
            maxLines: descMaxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: descFontSize,
              height: descHeight,
              fontWeight: FontWeight.w500,
              shadows: const [_textShadow],
            ),
          ),
        ),
        SizedBox(height: isNarrow ? 6 : 18),
        FilledButton.icon(
          onPressed:
              item.id.isEmpty
                  ? null
                  : () => context.go('/video/${item.id}/play'),
          icon: Icon(Icons.play_arrow_rounded, size: isNarrow ? 16 : 18),
          label: Text(l10n.videoHeroWatchNow),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF171717),
            padding:
                isNarrow
                    ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
                    : const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            textStyle: TextStyle(
              fontSize: isNarrow ? 11 : 14,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
