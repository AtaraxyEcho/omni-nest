import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';

class MovieDetailBackButton extends StatelessWidget {
  const MovieDetailBackButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const Key('movieDetailBackButton'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: context.videoColors.onSurface,
        backgroundColor: context.videoColors.surfaceContainerHigh.withValues(
          alpha: 0.72,
        ),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: Text(AppLocalizations.of(context).videoBackToLibrary),
    );
  }
}

class MovieSectionHeading extends StatelessWidget {
  const MovieSectionHeading({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.videoColors.onSurface,
                  fontSize: 24,
                  height: 32 / 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.videoColors.onSurfaceVariant,
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MovieNoticePanel extends StatelessWidget {
  const MovieNoticePanel({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.videoColors.primaryContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.videoColors.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.videoColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.videoColors.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: context.videoColors.onSurfaceVariant,
                    fontSize: 13,
                    height: 18 / 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyMovieState extends StatelessWidget {
  const EmptyMovieState({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(42),
      decoration: BoxDecoration(
        color: context.videoColors.surfaceContainerHigh.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.videoColors.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.movie_creation_outlined,
            color: context.videoColors.primary,
            size: 42,
          ),
          SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: context.videoColors.onSurfaceVariant,
              fontSize: 14,
              height: 20 / 14,
            ),
          ),
        ],
      ),
    );
  }
}

class MovieInlinePanel extends StatelessWidget {
  const MovieInlinePanel({
    required this.message,
    this.isError = false,
    this.loading = false,
    super.key,
  });

  final String message;
  final bool isError;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final color =
        isError
            ? Theme.of(context).colorScheme.error
            : context.videoColors.primary;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.videoColors.surfaceContainerHighest.withValues(
          alpha: 0.36,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          if (loading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (!isError)
            Icon(Icons.info_outline_rounded, color: color, size: 18)
          else
            Icon(Icons.error_outline_rounded, color: color, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? color : context.videoColors.onSurfaceVariant,
                fontSize: 13,
                height: 18 / 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 竖版海报在宽幅 Hero 中的展示：以模糊放大的同图打底，海报等比完整展示。
/// 直接用 BoxFit.cover 会把竖版海报放大裁切到只剩中部一条。
class PosterHeroImage extends StatelessWidget {
  const PosterHeroImage({required this.url, this.errorFallback, super.key});

  final String url;

  /// 图片加载失败时的占位；不传则显示空层。
  final Widget? errorFallback;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = errorFallback ?? const SizedBox.expand();
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: Transform.scale(
            scale: 1.2,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
            ),
          ),
        ),
        const ColoredBox(color: Color(0x4D000000)),
        Image.network(
          url,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          cacheWidth: 800,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      ],
    );
  }
}

class DetailBackdropFallback extends StatelessWidget {
  const DetailBackdropFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.videoColors.surfaceContainerHigh,
            context.videoColors.surfaceContainer,
            context.videoColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class DetailPosterPlaceholder extends StatelessWidget {
  const DetailPosterPlaceholder({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.videoColors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          icon,
          color: context.videoColors.onSurfaceVariant,
          size: 42,
        ),
      ),
    );
  }
}

class DetailHeroPoster extends StatelessWidget {
  const DetailHeroPoster({
    required this.posterUrl,
    required this.screenWidth,
    required this.placeholderIcon,
  });

  final String? posterUrl;

  /// 占位图标：电影/剧集各自传入。
  final IconData placeholderIcon;
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
    return Container(
      width: posterWidth,
      height: posterHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child:
          posterUrl != null
              ? CachedNetworkImage(
                imageUrl: posterUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 400,
                errorWidget:
                    (context, url, error) =>
                        DetailPosterPlaceholder(icon: placeholderIcon),
              )
              : DetailPosterPlaceholder(icon: placeholderIcon),
    );
  }
}

class DetailHeroPill extends StatelessWidget {
  const DetailHeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.videoColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c.onSurface,
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class DetailGenreChip extends StatelessWidget {
  const DetailGenreChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.videoColors.surfaceContainerHighest.withValues(
          alpha: 0.50,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: context.videoColors.outlineVariant.withValues(alpha: 0.20),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.videoColors.onSurfaceVariant,
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 通用状态色点：任务、来源等状态的圆形指示。
class StatusDot extends StatelessWidget {
  const StatusDot({required this.color, this.size = 8, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
