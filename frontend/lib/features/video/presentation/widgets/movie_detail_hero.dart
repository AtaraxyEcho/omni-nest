import 'package:cached_network_image/cached_network_image.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:flutter/material.dart';
import 'package:omninest/features/video/domain/movie_models.dart';
import 'package:omninest/features/video/presentation/widgets/movie_common_widgets.dart';
import 'package:omninest/features/video/presentation/widgets/movie_shell.dart';

class MovieDetailHero extends StatelessWidget {
  const MovieDetailHero({required this.item, required this.width, super.key});

  final MovieVideoItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    final posterUrl = item.posterImageUrl;
    final backdropUrl = item.backdropImageUrl;
    final w = width;
    final isNarrow = w < 600;

    // 移动端：紧凑布局，只展示封面 + 标题/信息，无背景图
    if (isNarrow) {
      return _MobileDetailHero(item: item, backdropUrl: backdropUrl, width: w);
    }

    final heroHeight =
        w >= 3200
            ? 760.0
            : w >= 2560
            ? 720.0
            : w >= 1920
            ? 620.0
            : w >= 1600
            ? 540.0
            : 440.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: heroHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (backdropUrl != null)
              CachedNetworkImage(
                imageUrl: backdropUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                memCacheWidth: 1920,
                errorWidget:
                    (context, url, error) => const DetailBackdropFallback(),
              )
            else
              const DetailBackdropFallback(),
            if (Theme.of(context).brightness == Brightness.dark)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.videoColors.surface.withValues(alpha: 0.25),
                      context.videoColors.surface.withValues(alpha: 0.88),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: _HeroContentRow(
                  item: item,
                  posterUrl: posterUrl,
                  screenWidth: w,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroContentRow extends StatelessWidget {
  const _HeroContentRow({
    required this.item,
    required this.posterUrl,
    required this.screenWidth,
  });

  final MovieVideoItem item;
  final String? posterUrl;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    final isNarrow = screenWidth < 600;
    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: DetailHeroPoster(
              posterUrl: posterUrl,
              screenWidth: screenWidth,
              placeholderIcon: Icons.movie_rounded,
            ),
          ),
          const SizedBox(height: 12),
          _HeroInfo(item: item, width: screenWidth),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        DetailHeroPoster(
          posterUrl: posterUrl,
          screenWidth: screenWidth,
          placeholderIcon: Icons.movie_rounded,
        ),
        const SizedBox(width: 24),
        // 不使用内嵌 SingleChildScrollView：内嵌可滚动区域会抢占页面滚轮事件，
        // 导致鼠标悬停 Hero 时详情页无法滚动。信息区高度低于 Hero 最小高度。
        Expanded(child: _HeroInfo(item: item, width: screenWidth)),
      ],
    );
  }
}

/// 移动端详情页 Hero：长图封面铺满 + 标题/信息堆叠，与下方内容左对齐。
class _MobileDetailHero extends StatelessWidget {
  const _MobileDetailHero({
    required this.item,
    required this.backdropUrl,
    required this.width,
  });

  final MovieVideoItem item;
  final String? backdropUrl;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 长图封面铺满容器宽度
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child:
                backdropUrl != null
                    ? Image.network(
                      backdropUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, _, _) => const DetailBackdropFallback(),
                    )
                    : const DetailBackdropFallback(),
          ),
        ),
        const SizedBox(height: 12),
        // 以下内容与页面 padding 对齐（16px，与 _DetailContent 的 padding 一致）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 类型标签
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (item.contentRating != null)
                    DetailHeroPill(label: item.contentRating!),
                  DetailHeroPill(
                    label:
                        item.mediaType == 'MOVIE'
                            ? AppLocalizations.of(context).videoSectionMovies
                            : AppLocalizations.of(context).videoSectionTvShows,
                  ),
                  DetailHeroPill(label: item.year),
                  if (item.runtimeSeconds != null && item.runtimeSeconds! > 0)
                    DetailHeroPill(label: item.runtimeText),
                ],
              ),
              const SizedBox(height: 10),
              // 标题
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.videoColors.onSurface,
                  fontSize: 20,
                  height: 26 / 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (item.originalTitle != null &&
                  item.originalTitle!.isNotEmpty &&
                  item.originalTitle != item.title) ...[
                const SizedBox(height: 4),
                Text(
                  item.originalTitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.videoColors.onSurfaceVariant.withValues(
                      alpha: 0.72,
                    ),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              // 评分 + 类型标签（合并为一行）
              if (item.rating != null || item.genres.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (item.rating != null) ...[
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFC107),
                        size: 16,
                      ),
                      Text(
                        item.rating!.toStringAsFixed(1),
                        style: TextStyle(
                          color: context.videoColors.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (item.voteCount != null)
                        Text(
                          ' (${item.voteCount})',
                          style: TextStyle(
                            color: context.videoColors.onSurfaceVariant
                                .withValues(alpha: 0.62),
                            fontSize: 12,
                          ),
                        ),
                    ],
                    for (final genre in item.genres)
                      DetailGenreChip(label: genre),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroInfo extends StatelessWidget {
  const _HeroInfo({required this.item, required this.width});

  final MovieVideoItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    final w = width;
    final titleSize = ms(w, 30);
    final originalSize = ms(w, 15);
    final taglineSize = ms(w, 14);
    final ratingSize = ms(w, 16);
    final voteSize = ms(w, 13);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (item.contentRating != null)
              DetailHeroPill(label: item.contentRating!),
            DetailHeroPill(
              label:
                  item.mediaType == 'MOVIE'
                      ? AppLocalizations.of(context).videoSectionMovies
                      : AppLocalizations.of(context).videoSectionTvShows,
            ),
            DetailHeroPill(label: item.year),
            if (item.runtimeSeconds != null && item.runtimeSeconds! > 0)
              DetailHeroPill(label: item.runtimeText),
          ],
        ),
        SizedBox(height: 14),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.videoColors.onSurface,
            fontSize: titleSize,
            height: 36 / 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (item.originalTitle != null &&
            item.originalTitle!.isNotEmpty &&
            item.originalTitle != item.title) ...[
          SizedBox(height: 6),
          Text(
            item.originalTitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.videoColors.onSurfaceVariant.withValues(
                alpha: 0.72,
              ),
              fontSize: originalSize,
              height: 20 / 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (item.tagline != null && item.tagline!.isNotEmpty) ...[
          SizedBox(height: 8),
          Text(
            item.tagline!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.videoColors.primary.withValues(alpha: 0.82),
              fontSize: taglineSize,
              height: 20 / 14,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (item.genres.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final genre in item.genres) DetailGenreChip(label: genre),
            ],
          ),
        ],
        if (item.rating != null) ...[
          SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 20),
              SizedBox(width: 4),
              Text(
                item.rating!.toStringAsFixed(1),
                style: TextStyle(
                  color: context.videoColors.onSurface,
                  fontSize: ratingSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (item.voteCount != null) ...[
                SizedBox(width: 6),
                Text(
                  '(${item.voteCount})',
                  style: TextStyle(
                    color: context.videoColors.onSurfaceVariant.withValues(
                      alpha: 0.62,
                    ),
                    fontSize: voteSize,
                  ),
                ),
              ],
              if (item.releaseDate != null) ...[
                SizedBox(width: 10),
                Text(
                  _formatDate(item.releaseDate!),
                  style: TextStyle(
                    color: context.videoColors.onSurfaceVariant.withValues(
                      alpha: 0.72,
                    ),
                    fontSize: voteSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
        ..._countryPills(item),
        ..._techSnapshot(item, voteSize),
      ],
    );
  }

  List<Widget> _countryPills(MovieVideoItem item) {
    final raw = item.metadata['countries'];
    if (raw is! List || raw.isEmpty) return const [];
    final countries = raw.map((e) => e.toString()).toList();
    return [
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [for (final c in countries) DetailGenreChip(label: c)],
      ),
    ];
  }

  List<Widget> _techSnapshot(MovieVideoItem item, double fontSize) {
    final parts = <String>[];
    if (item.resolutionWidth != null) {
      parts.add('${item.resolutionWidth}p');
    }
    if (item.videoCodec != null) parts.add(item.videoCodec!);
    if (item.audioCodec != null) parts.add(item.audioCodec!);
    if (parts.isEmpty) return [];
    return [
      const SizedBox(height: 10),
      Builder(
        builder:
            (context) => Text(
              parts.join(' · '),
              style: TextStyle(
                color: context.videoColors.onSurfaceVariant.withValues(
                  alpha: 0.58,
                ),
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
      ),
    ];
  }

  static String _formatDate(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }
}
