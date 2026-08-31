import 'package:cached_network_image/cached_network_image.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:flutter/material.dart';
import 'package:omninest/features/video/domain/movie_models.dart';
import 'package:omninest/features/video/presentation/widgets/movie_common_widgets.dart';
import 'package:omninest/features/video/presentation/widgets/movie_shell.dart';

/// 剧集详情页 Hero 区域 — 与 MovieDetailHero 视觉风格一致
class SeriesDetailHero extends StatelessWidget {
  const SeriesDetailHero({
    required this.series,
    required this.width,
    super.key,
  });

  final MovieSeries series;
  final double width;

  @override
  Widget build(BuildContext context) {
    final posterUrl = series.posterImageUrl;
    final backdropUrl = series.backdropImageUrl;
    final w = width;
    if (w < 600) {
      return _MobileSeriesDetailHero(
        series: series,
        backdropUrl: backdropUrl,
        width: w,
      );
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
            // 暗色遮罩 + 底部渐变（仅深色主题）
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
                  series: series,
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

/// 移动端剧集详情使用横向剧照和紧凑信息区。
class _MobileSeriesDetailHero extends StatelessWidget {
  const _MobileSeriesDetailHero({
    required this.series,
    required this.backdropUrl,
    required this.width,
  });

  final MovieSeries series;
  final String? backdropUrl;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child:
                backdropUrl != null
                    ? CachedNetworkImage(
                      imageUrl: backdropUrl!,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      memCacheWidth: 960,
                      errorWidget:
                          (context, url, error) =>
                              const DetailBackdropFallback(),
                    )
                    : const DetailBackdropFallback(),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _HeroInfo(series: series, width: width),
        ),
      ],
    );
  }
}

class _HeroContentRow extends StatelessWidget {
  const _HeroContentRow({
    required this.series,
    required this.posterUrl,
    required this.screenWidth,
  });

  final MovieSeries series;
  final String? posterUrl;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    final posterWidth =
        screenWidth >= 1920
            ? 200.0
            : screenWidth >= 1280
            ? 160.0
            : screenWidth >= 720
            ? 140.0
            : 120.0;
    final posterHeight = posterWidth * 1.4375;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        DetailHeroPoster(
          posterUrl: posterUrl,
          screenWidth: screenWidth,
          placeholderIcon: Icons.tv_rounded,
        ),
        const SizedBox(width: 24),
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: posterHeight),
            child: SingleChildScrollView(
              child: _HeroInfo(series: series, width: screenWidth),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroInfo extends StatelessWidget {
  const _HeroInfo({required this.series, required this.width});

  final MovieSeries series;
  final double width;

  @override
  Widget build(BuildContext context) {
    final w = width;
    final titleSize = ms(w, 30);
    final originalSize = ms(w, 15);
    final ratingSize = ms(w, 16);
    final voteSize = ms(w, 13);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (series.contentRating != null)
                  DetailHeroPill(label: series.contentRating!),
                DetailHeroPill(
                  label: AppLocalizations.of(context).videoSectionTvShows,
                ),
                DetailHeroPill(label: series.year),
              ],
            ),
          ),
        ),
        SizedBox(height: 14),
        Text(
          series.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.videoColors.onSurface,
            fontSize: titleSize,
            height: 36 / 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (series.originalTitle != null &&
            series.originalTitle!.isNotEmpty &&
            series.originalTitle != series.title) ...[
          SizedBox(height: 6),
          Text(
            series.originalTitle!,
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
        if (series.genres.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final genre in series.genres) DetailGenreChip(label: genre),
            ],
          ),
        ],
        if (series.rating != null) ...[
          SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 20),
              SizedBox(width: 4),
              Text(
                series.rating!.toStringAsFixed(1),
                style: TextStyle(
                  color: context.videoColors.onSurface,
                  fontSize: ratingSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (series.voteCount != null) ...[
                SizedBox(width: 6),
                Text(
                  '(${series.voteCount})',
                  style: TextStyle(
                    color: context.videoColors.onSurfaceVariant.withValues(
                      alpha: 0.62,
                    ),
                    fontSize: voteSize,
                  ),
                ),
              ],
              if (series.firstAirDate != null) ...[
                SizedBox(width: 10),
                Text(
                  _formatDate(series.firstAirDate!),
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
      ],
    );
  }

  static String _formatDate(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }
}
