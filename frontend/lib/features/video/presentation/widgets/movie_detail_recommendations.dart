import 'package:cached_network_image/cached_network_image.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/features/video/domain/movie_models.dart';

List<MovieVideoItem> recommendItems(
  List<MovieVideoItem> all,
  String excludeId,
) {
  final candidates = all
      .where((item) => item.id != excludeId)
      .toList(growable: false);
  final withPoster = [
    for (final item in candidates)
      if (item.posterImageUrl != null || item.backdropImageUrl != null) item,
  ];
  final source = withPoster.isEmpty ? candidates : withPoster;
  final sorted = List<MovieVideoItem>.from(source)..sort((a, b) {
    final aDate = a.releaseDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = b.releaseDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bDate.compareTo(aDate);
  });
  return sorted.take(18).toList(growable: false);
}

class MovieRecommendations extends StatelessWidget {
  const MovieRecommendations({
    required this.recommended,
    this.width,
    super.key,
  });

  final List<MovieVideoItem> recommended;
  final double? width;

  @override
  Widget build(BuildContext context) {
    if (recommended.isEmpty) return SizedBox.shrink();
    final w = width ?? MediaQuery.sizeOf(context).width;
    final compact = w < 600;
    final titleSize = w >= 1280 ? 17.0 : 15.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).videoRecommendations,
          style: TextStyle(
            color: context.videoColors.onSurface,
            fontSize: titleSize,
            height: 24 / 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: compact ? 205 : 250,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: recommended.length,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder:
                  (context, index) => _RecommendationCard(
                    item: recommended[index],
                    compact: compact,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatefulWidget {
  const _RecommendationCard({required this.item, required this.compact});

  final MovieVideoItem item;
  final bool compact;

  @override
  State<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<_RecommendationCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final imageUrl = item.posterImageUrl ?? item.backdropImageUrl;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          if (item.mediaType == 'TV') {
            context.push('/video/series/${item.id}');
          } else {
            context.push('/video/${item.id}');
          }
        },
        child: AnimatedScale(
          duration: Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: _hovered ? 1.03 : 1.0,
          child: SizedBox(
            width: widget.compact ? 118 : 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: context.videoColors.outlineVariant.withValues(
                          alpha: 0.25,
                        ),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          context.videoColors.primaryContainer.withValues(
                            alpha: 0.84,
                          ),
                          Color(0xFF252337),
                          context.videoColors.surfaceContainerLow,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageUrl != null)
                          Positioned.fill(
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 400,
                              errorWidget: (_, _, _) => SizedBox.shrink(),
                            ),
                          ),
                        if (_hovered)
                          const Positioned.fill(
                            child: IgnorePointer(
                              child: Center(
                                child: Icon(
                                  Icons.play_circle_fill_rounded,
                                  size: 44,
                                  color: Color(0xE6FFFFFF),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        _hovered
                            ? context.videoColors.primary
                            : context.videoColors.onSurface,
                    fontSize: widget.compact ? 12 : 13,
                    height: widget.compact ? 16 / 12 : 18 / 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.year} · ${item.mediaType == 'MOVIE' ? AppLocalizations.of(context).videoSectionMovies : AppLocalizations.of(context).videoSectionTvShows}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.videoColors.onSurfaceVariant.withValues(
                      alpha: _hovered ? 0.92 : 0.72,
                    ),
                    fontSize: widget.compact ? 10 : 12,
                    height: widget.compact ? 13 / 10 : 16 / 12,
                    fontWeight: FontWeight.w600,
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
