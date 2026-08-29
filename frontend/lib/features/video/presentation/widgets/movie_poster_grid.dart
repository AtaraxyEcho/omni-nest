import 'package:cached_network_image/cached_network_image.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:omninest/app/theme/mobile_layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/features/video/domain/movie_models.dart';
import 'package:omninest/features/video/presentation/widgets/movie_common_widgets.dart';
import 'package:omninest/features/video/presentation/widgets/movie_responsive_layout.dart';

class MoviePosterGridSection extends StatelessWidget {
  const MoviePosterGridSection({
    required this.title,
    required this.subtitle,
    required this.items,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<MovieVideoItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieSectionHeading(title: title, subtitle: subtitle),
        const SizedBox(height: 22),
        if (items.isEmpty)
          EmptyMovieState(
            message: AppLocalizations.of(context).videoNoMediaItems,
          )
        else
          MoviePosterGrid(items: items),
      ],
    );
  }
}

class MoviePosterGrid extends StatelessWidget {
  const MoviePosterGrid({required this.items, super.key});

  final List<MovieVideoItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyMovieState(
        message: AppLocalizations.of(context).videoNoMediaItems,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = MoviePosterGridMetrics.resolve(constraints.maxWidth);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: metrics.columns,
            crossAxisSpacing: metrics.crossAxisSpacing,
            mainAxisSpacing: metrics.mainAxisSpacing,
            childAspectRatio: metrics.childAspectRatio,
          ),
          itemBuilder:
              (context, index) =>
                  MoviePosterCard(item: items[index], compact: metrics.compact),
        );
      },
    );
  }
}

class MoviePosterSliverGrid extends StatelessWidget {
  const MoviePosterSliverGrid({required this.items, super.key});

  final List<MovieVideoItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyMovieState(
          message: AppLocalizations.of(context).videoNoMediaItems,
        ),
      );
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final metrics = MoviePosterGridMetrics.resolve(
          constraints.crossAxisExtent,
        );
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: metrics.columns,
            crossAxisSpacing: metrics.crossAxisSpacing,
            mainAxisSpacing: metrics.mainAxisSpacing,
            childAspectRatio: metrics.childAspectRatio,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) =>
                MoviePosterCard(item: items[index], compact: metrics.compact),
            childCount: items.length,
          ),
        );
      },
    );
  }
}

class MovieListSliver extends StatelessWidget {
  const MovieListSliver({required this.items, super.key});

  final List<MovieVideoItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyMovieState(
          message: AppLocalizations.of(context).videoNoMediaItems,
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => MovieListRow(item: items[index]),
        childCount: items.length,
      ),
    );
  }
}

class MoviePosterCard extends StatefulWidget {
  const MoviePosterCard({required this.item, this.compact = false, super.key});

  final MovieVideoItem item;
  final bool compact;

  @override
  State<MoviePosterCard> createState() => _MoviePosterCardState();
}

class _MoviePosterCardState extends State<MoviePosterCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final compact = widget.compact;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: _hovered ? 1.018 : 1.0,
        child: Transform.translate(
          offset: Offset(0, _hovered ? -6.0 : 0.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              boxShadow:
                  compact
                      ? const []
                      : [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: _hovered ? 0.42 : 0.18,
                          ),
                          blurRadius: _hovered ? 30 : 18,
                          offset: Offset(0, _hovered ? 16 : 10),
                        ),
                      ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(MobileLayoutTokens.radius),
                onTap: () {
                  if (item.mediaType == 'TV') {
                    context.push('/video/series/${item.id}');
                  } else {
                    context.push('/video/${item.id}');
                  }
                },
                splashColor: context.videoColors.primary.withValues(
                  alpha: 0.10,
                ),
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: PosterArt(
                        item: item,
                        hovered: _hovered,
                        compact: compact,
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 12),
                    AnimatedDefaultTextStyle(
                      duration: Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        color:
                            _hovered
                                ? context.videoColors.primary
                                : context.videoColors.onSurface,
                        fontSize: compact ? 12 : 14,
                        height: compact ? 16 / 12 : 20 / 14,
                        fontWeight: FontWeight.w800,
                      ),
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${item.year} · ${item.runtimeText}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.videoColors.onSurfaceVariant.withValues(
                          alpha: _hovered ? 0.92 : 0.72,
                        ),
                        fontSize: compact ? 10 : 12,
                        height: compact ? 13 / 10 : 16 / 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PosterArt extends StatelessWidget {
  const PosterArt({
    required this.item,
    required this.hovered,
    this.compact = false,
    super.key,
  });

  final MovieVideoItem item;
  final bool hovered;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final posterUrl = item.posterImageUrl;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MobileLayoutTokens.radius),
        border: Border.all(
          color: context.videoColors.outlineVariant.withValues(alpha: 0.25),
        ),
        gradient: LinearGradient(
          colors: [
            context.videoColors.primaryContainer.withValues(alpha: 0.50),
            context.videoColors.surfaceContainerHigh,
            context.videoColors.surfaceContainerLow,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow:
            compact
                ? const []
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 24,
                    offset: const Offset(0, 16),
                  ),
                ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (posterUrl != null)
            Positioned.fill(
              child: Image.network(
                posterUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
                cacheWidth: 300,
                errorBuilder: (context, error, stackTrace) => SizedBox.shrink(),
              ),
            ),
          Positioned(
            top: compact ? 8 : 12,
            right: compact ? 8 : 12,
            child: AnimatedScale(
              duration: Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              scale: hovered ? 1.08 : 1.0,
              child: Icon(
                item.mediaType == 'MOVIE'
                    ? Icons.movie_rounded
                    : Icons.tv_rounded,
                size: compact ? 17 : 24,
                color:
                    hovered
                        ? context.videoColors.primary.withValues(alpha: 0.92)
                        : context.videoColors.onSurface.withValues(alpha: 0.74),
              ),
            ),
          ),
          if (!item.available)
            Positioned(
              left: compact ? 8 : 12,
              bottom: compact ? 8 : 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.link_off_rounded,
                      size: 13,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppLocalizations.of(context).videoFileUnavailable,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (hovered && item.available)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    size: compact ? 38 : 52,
                    color: Color(0xE6FFFFFF),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 列表视图容器
class MovieListColumn extends StatelessWidget {
  const MovieListColumn({required this.items, super.key});

  final List<MovieVideoItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyMovieState(
        message: AppLocalizations.of(context).videoNoMediaItems,
      );
    }
    return Column(
      children: [for (final item in items) MovieListRow(item: item)],
    );
  }
}

/// 列表视图模式 — 横向行卡片
class MovieListRow extends StatefulWidget {
  const MovieListRow({required this.item, super.key});

  final MovieVideoItem item;

  @override
  State<MovieListRow> createState() => _MovieListRowState();
}

class _MovieListRowState extends State<MovieListRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        margin: EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color:
              _hovered
                  ? context.videoColors.surfaceContainerHigh
                  : context.videoColors.surfaceContainerHigh.withValues(
                    alpha: 0.50,
                  ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.videoColors.outlineVariant.withValues(
              alpha: _hovered ? 0.35 : 0.18,
            ),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              if (item.mediaType == 'TV') {
                context.push('/video/series/${item.id}');
              } else {
                context.push('/video/${item.id}');
              }
            },
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  // 缩略图
                  Container(
                    width: 100,
                    height: 56,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: context.videoColors.surfaceContainerHighest,
                    ),
                    child:
                        item.posterImageUrl != null
                            ? CachedNetworkImage(
                              imageUrl: item.posterImageUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 200,
                              errorWidget:
                                  (ctx, url, err) => Icon(
                                    Icons.movie_rounded,
                                    color: context.videoColors.onSurfaceVariant,
                                    size: 24,
                                  ),
                            )
                            : Icon(
                              Icons.movie_rounded,
                              color: context.videoColors.onSurfaceVariant,
                              size: 24,
                            ),
                  ),
                  SizedBox(width: 16),
                  // 信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                _hovered
                                    ? context.videoColors.primary
                                    : context.videoColors.onSurface,
                            fontSize: 15,
                            height: 20 / 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${item.year} · ${item.runtimeText}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.videoColors.onSurfaceVariant
                                .withValues(alpha: 0.72),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 类型标签
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.videoColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.mediaType == 'MOVIE'
                          ? AppLocalizations.of(context).videoSectionMovies
                          : AppLocalizations.of(context).videoSectionTvShows,
                      style: TextStyle(
                        color: context.videoColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  // 评分
                  if (item.rating != null) ...[
                    Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: context.videoColors.tertiary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      item.rating!.toStringAsFixed(1),
                      style: TextStyle(
                        color: context.videoColors.tertiary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  SizedBox(width: 16),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.videoColors.onSurfaceVariant.withValues(
                      alpha: 0.50,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
