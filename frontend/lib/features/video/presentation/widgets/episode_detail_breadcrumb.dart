import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:go_router/go_router.dart';

class EpisodeBreadcrumb extends StatelessWidget {
  const EpisodeBreadcrumb({
    required this.seriesId,
    required this.seriesTitle,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.episodeTitle,
    super.key,
  });

  final String seriesId;
  final String seriesTitle;
  final int? seasonNumber;
  final int? episodeNumber;
  final String episodeTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.videoColors.surfaceContainerHigh.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.videoColors.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/video'),
            child: Text(
              AppLocalizations.of(context).videoMediaCenter,
              style: TextStyle(
                color: context.videoColors.onSurfaceVariant.withValues(
                  alpha: 0.62,
                ),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _BreadcrumbSeparator(),
          GestureDetector(
            onTap: () => context.go('/video/series/$seriesId'),
            child: Text(
              seriesTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.videoColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (seasonNumber != null) ...[
            _BreadcrumbSeparator(),
            Text(
              AppLocalizations.of(context).videoSeasonLabel(seasonNumber!),
              style: TextStyle(
                color: context.videoColors.onSurfaceVariant.withValues(
                  alpha: 0.72,
                ),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (episodeNumber != null) ...[
            _BreadcrumbSeparator(),
            Text(
              AppLocalizations.of(context).videoEpisodeLabel(episodeNumber!),
              style: TextStyle(
                color: context.videoColors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BreadcrumbSeparator extends StatelessWidget {
  const _BreadcrumbSeparator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 16,
        color: context.videoColors.onSurfaceVariant.withValues(alpha: 0.42),
      ),
    );
  }
}
