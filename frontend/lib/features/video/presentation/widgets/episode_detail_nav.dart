import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/features/video/domain/movie_models.dart';

class EpisodeNavigation extends StatelessWidget {
  const EpisodeNavigation({
    required this.prevEpisode,
    required this.nextEpisode,
    required this.seasonProgress,
    super.key,
  });

  final MovieVideoItem? prevEpisode;
  final MovieVideoItem? nextEpisode;
  final String? seasonProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.videoColors.surfaceContainerHigh.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.videoColors.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (seasonProgress != null) ...[
            Text(
              seasonProgress!,
              style: TextStyle(
                color: context.videoColors.onSurfaceVariant.withValues(
                  alpha: 0.72,
                ),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              if (prevEpisode != null)
                Expanded(
                  child: _NavButton(
                    episode: prevEpisode!,
                    icon: Icons.skip_previous_rounded,
                    label: AppLocalizations.of(context).videoPreviousEpisode,
                    alignment: Alignment.centerLeft,
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 12),
              if (nextEpisode != null)
                Expanded(
                  child: _NavButton(
                    episode: nextEpisode!,
                    icon: Icons.skip_next_rounded,
                    label: AppLocalizations.of(context).videoNextEpisode,
                    alignment: Alignment.centerRight,
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.episode,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final MovieVideoItem episode;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.push('/video/${episode.id}'),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.videoColors.surfaceContainerHighest.withValues(
            alpha: 0.40,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: context.videoColors.outlineVariant.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alignment == Alignment.centerLeft) ...[
              Icon(icon, color: context.videoColors.primary, size: 18),
              SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment:
                    alignment == Alignment.centerLeft
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: context.videoColors.onSurfaceVariant.withValues(
                        alpha: 0.62,
                      ),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    episode.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.videoColors.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (alignment == Alignment.centerRight) ...[
              SizedBox(width: 8),
              Icon(icon, color: context.videoColors.primary, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
