import 'package:cached_network_image/cached_network_image.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/features/video/application/movie_controller.dart';
import 'package:omninest/features/video/domain/movie_models.dart';
import 'package:omninest/features/video/presentation/widgets/movie_feedback.dart';

class SeasonListSection extends StatefulWidget {
  const SeasonListSection({
    required this.seriesId,
    required this.seasons,
    super.key,
  });

  final String seriesId;
  final List<MovieSeason> seasons;

  @override
  State<SeasonListSection> createState() => _SeasonListSectionState();
}

class _SeasonListSectionState extends State<SeasonListSection> {
  int _selectedIndex = 0;

  @override
  void didUpdateWidget(covariant SeasonListSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seasons.length != oldWidget.seasons.length &&
        _selectedIndex >= widget.seasons.length) {
      _selectedIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seasons.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.videoColors.surfaceContainerHigh.withValues(
            alpha: 0.70,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.videoColors.outlineVariant.withValues(alpha: 0.22),
          ),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              AppLocalizations.of(context).videoNoSeasonInfo,
              style: TextStyle(
                color: context.videoColors.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    final selectedSeason = widget.seasons[_selectedIndex];
    final seasonKey = SeasonKey(
      seriesId: widget.seriesId,
      seasonNumber: selectedSeason.seasonNumber,
    );

    return Container(
      width: double.infinity,
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
          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              AppLocalizations.of(context).videoEpisodeList,
              style: TextStyle(
                color: context.videoColors.onSurface,
                fontSize: 18,
                height: 24 / 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.seasons.length,
              itemBuilder: (context, index) {
                final season = widget.seasons[index];
                return _SeasonTab(
                  seasonNumber: season.seasonNumber,
                  episodeCount: season.episodeCount,
                  isSelected: index == _selectedIndex,
                  onTap: () {
                    if (index != _selectedIndex) {
                      setState(() => _selectedIndex = index);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _EpisodeGrid(
            key: ValueKey(seasonKey),
            seasonKey: seasonKey,
            seriesId: widget.seriesId,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SeasonTab extends StatelessWidget {
  const _SeasonTab({
    required this.seasonNumber,
    required this.isSelected,
    required this.onTap,
    this.episodeCount,
  });

  final int seasonNumber;
  final int? episodeCount;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? context.videoColors.primaryContainer.withValues(alpha: 0.28)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected
                    ? context.videoColors.primary.withValues(alpha: 0.56)
                    : context.videoColors.outlineVariant.withValues(
                      alpha: 0.28,
                    ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context).videoSeasonTab(seasonNumber),
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color:
                    isSelected
                        ? context.videoColors.primary
                        : context.videoColors.onSurfaceVariant,
              ),
            ),
            if (episodeCount != null && episodeCount! > 0) ...[
              SizedBox(width: 5),
              Text(
                '$episodeCount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color:
                      isSelected
                          ? context.videoColors.primary.withValues(alpha: 0.72)
                          : context.videoColors.onSurfaceVariant.withValues(
                            alpha: 0.56,
                          ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EpisodeGrid extends ConsumerWidget {
  const _EpisodeGrid({
    required this.seasonKey,
    required this.seriesId,
    super.key,
  });

  final SeasonKey seasonKey;
  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(movieSeasonDetailProvider(seasonKey));
    return detailAsync.when(
      data: (detail) {
        if (detail.episodes.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: Text(
                AppLocalizations.of(context).videoNoEpisodesInSeason,
                style: TextStyle(
                  color: context.videoColors.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }
        return _buildGrid(context, detail.episodes);
      },
      loading:
          () => Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: context.videoColors.primary,
                ),
              ),
            ),
          ),
      error:
          (error, _) => Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Center(
              child: Text(
                movieErrorMessage(error),
                style: TextStyle(
                  color: context.videoColors.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildGrid(BuildContext context, List<MovieVideoItem> episodes) {
    final width = MediaQuery.sizeOf(context).width;
    final int crossAxisCount;
    if (width > 1200) {
      crossAxisCount = 6;
    } else if (width > 900) {
      crossAxisCount = 5;
    } else if (width > 600) {
      crossAxisCount = 4;
    } else if (width > 420) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 2;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
            crossAxisCount;
        final itemHeight = itemWidth / 16 * 9 + 64;
        final aspectRatio = itemWidth / itemHeight;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: aspectRatio,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: episodes.length,
            itemBuilder: (context, index) {
              return _EpisodeCard(episode: episodes[index]);
            },
          ),
        );
      },
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({required this.episode});

  final MovieVideoItem episode;

  @override
  Widget build(BuildContext context) {
    final seasonNum = episode.seasonNumber ?? 0;
    final episodeNum = episode.episodeNumber ?? 0;
    final code =
        'S${seasonNum.toString().padLeft(2, '0')}'
        'E${episodeNum.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => context.push('/video/${episode.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: context.videoColors.surfaceContainerHighest),
                  if (episode.posterImageUrl != null)
                    CachedNetworkImage(
                      imageUrl: episode.posterImageUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 320,
                      errorWidget:
                          (_, _, _) => Center(
                            child: Icon(
                              Icons.play_circle_outline_rounded,
                              color: context.videoColors.onSurfaceVariant,
                              size: 28,
                            ),
                          ),
                    )
                  else
                    Center(
                      child: Icon(
                        Icons.play_circle_outline_rounded,
                        color: context.videoColors.onSurfaceVariant,
                        size: 28,
                      ),
                    ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              episode.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.videoColors.onSurface,
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 2, left: 2, right: 2),
            child: Text(
              episode.runtimeText,
              style: TextStyle(
                color: context.videoColors.onSurfaceVariant.withValues(
                  alpha: 0.72,
                ),
                fontSize: 11,
                height: 14 / 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
