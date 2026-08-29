import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/core/auth/auth_controller.dart';
import 'package:omninest/core/widgets/app_error_view.dart';
import 'package:omninest/core/widgets/app_loading.dart';
import 'package:omninest/features/video/application/movie_controller.dart';
import 'package:omninest/features/video/domain/movie_models.dart';
import 'package:omninest/features/video/presentation/widgets/episode_detail_breadcrumb.dart';
import 'package:omninest/features/video/presentation/widgets/episode_detail_nav.dart';
import 'package:omninest/features/video/presentation/widgets/movie_detail_actions.dart';
import 'package:omninest/features/video/presentation/widgets/movie_detail_cast.dart';
import 'package:omninest/features/video/presentation/widgets/movie_detail_gallery.dart';
import 'package:omninest/features/video/presentation/widgets/movie_detail_hero.dart';
import 'package:omninest/features/video/presentation/widgets/movie_detail_meta.dart';
import 'package:omninest/features/video/presentation/widgets/movie_detail_overview.dart';
import 'package:omninest/features/video/presentation/widgets/movie_detail_recommendations.dart';
import 'package:omninest/features/video/presentation/widgets/movie_detail_user_data.dart';
import 'package:omninest/features/video/presentation/widgets/movie_feedback.dart';
import 'package:omninest/features/video/presentation/widgets/movie_common_widgets.dart';
import 'package:omninest/features/video/presentation/widgets/movie_detail_page_frame.dart';

class MovieDetailPage extends ConsumerWidget {
  const MovieDetailPage({required this.videoItemId, super.key});

  final String videoItemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(movieDetailProvider(videoItemId));
    final user = ref.watch(authSessionProvider).asData?.value.user;
    final canManage =
        user?.permissions.contains('media:library:manage') ?? false;
    final allMovies =
        ref.watch(movieCenterControllerProvider).asData?.value.movies ??
        const <MovieVideoItem>[];
    return detail.when(
      data: (item) {
        void backToLibrary() {
          ref
              .read(movieCenterControllerProvider.notifier)
              .selectSection(MovieSection.movies);
          context.go('/video');
        }

        return MovieDetailPageFrame(
          child: _DetailContent(
            item: item,
            canManage: canManage,
            allMovies: allMovies,
            onBack: backToLibrary,
          ),
        );
      },
      error:
          (error, stackTrace) => Scaffold(
            body: AppErrorView(
              message: movieErrorMessage(error),
              onRetry: () => ref.invalidate(movieDetailProvider(videoItemId)),
            ),
          ),
      loading: () => const Scaffold(body: AppLoading.detail()),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.item,
    required this.canManage,
    required this.allMovies,
    required this.onBack,
  });

  final MovieVideoItem item;
  final bool canManage;
  final List<MovieVideoItem> allMovies;
  final VoidCallback onBack;

  bool get isEpisode => item.seriesId != null && item.seriesId!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MovieDetailBackButton(onPressed: onBack),
            const SizedBox(height: 16),
            if (isEpisode) ...[
              _EpisodeBreadcrumbWrapper(item: item),
              const SizedBox(height: 16),
            ],
            MovieDetailHero(item: item, width: w),
            // hero → actions: 紧凑
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _VersionSelectorWrapper(videoItemId: item.id),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: MovieDetailActionBar(item: item, canManage: canManage),
            ),
            // actions → overview: 中等
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: MovieDetailOverview(overview: item.overview, width: w),
            ),
            if (item.castMembers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: CastCrewSection(
                  cast: item.castMembers,
                  crew: item.crewMembers,
                  width: w,
                ),
              ),
            if (isEpisode)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: _EpisodeNavWrapper(item: item),
              ),
            // 各内容段之间: 适中
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: MediaGallerySection(itemId: item.id, width: w),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: MovieDetailUserData(videoItemId: item.id, width: w),
            ),
            // 技术信息与上方拉开
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: TechnicalMetadataSection(item: item, width: w),
            ),
            if (allMovies.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: MovieRecommendations(
                  recommended: recommendItems(allMovies, item.id),
                  width: w,
                ),
              ),
            const SizedBox(height: 48),
          ],
        );
      },
    );
  }
}

/// Wrapper that loads series data for the breadcrumb.
class _EpisodeBreadcrumbWrapper extends ConsumerWidget {
  const _EpisodeBreadcrumbWrapper({required this.item});

  final MovieVideoItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesId = item.seriesId!;
    final seriesAsync = ref.watch(movieSeriesDetailProvider(seriesId));
    return seriesAsync.when(
      data: (detail) {
        final seriesTitle = detail.series.title;
        return EpisodeBreadcrumb(
          seriesId: seriesId,
          seriesTitle: seriesTitle,
          seasonNumber: item.seasonNumber,
          episodeNumber: item.episodeNumber,
          episodeTitle: item.title,
        );
      },
      error: (_, _) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }
}

/// Wrapper that loads season data for prev/next navigation.
class _EpisodeNavWrapper extends ConsumerWidget {
  const _EpisodeNavWrapper({required this.item});

  final MovieVideoItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesId = item.seriesId!;
    final seasonNumber = item.seasonNumber;
    if (seasonNumber == null) return const SizedBox.shrink();
    final key = SeasonKey(seriesId: seriesId, seasonNumber: seasonNumber);
    final seasonAsync = ref.watch(movieSeasonDetailProvider(key));
    return seasonAsync.when(
      data: (detail) {
        final episodes = detail.episodes;
        final currentIndex = episodes.indexWhere((e) => e.id == item.id);
        final prev = currentIndex > 0 ? episodes[currentIndex - 1] : null;
        final next =
            currentIndex < episodes.length - 1
                ? episodes[currentIndex + 1]
                : null;
        final progressText = AppLocalizations.of(
          context,
        ).videoSeasonProgress(seasonNumber, currentIndex + 1, episodes.length);
        return EpisodeNavigation(
          prevEpisode: prev,
          nextEpisode: next,
          seasonProgress: progressText,
        );
      },
      error: (_, _) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }
}

/// Wrapper that loads version list and shows a version selector when multiple
/// versions of the same movie/episode exist.
class _VersionSelectorWrapper extends ConsumerWidget {
  const _VersionSelectorWrapper({required this.videoItemId});

  final String videoItemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionsAsync = ref.watch(movieVersionsProvider(videoItemId));
    return versionsAsync.when(
      data: (versions) {
        if (versions.length <= 1) return const SizedBox.shrink();
        final current = versions.firstWhere(
          (v) => v.id == videoItemId,
          orElse: () => versions.first,
        );
        return _VersionChipBar(
          versions: versions,
          currentVersion: current,
          onVersionSelected: (selected) {
            if (selected.id != videoItemId) {
              context.go('/video/items/${selected.id}');
            }
          },
        );
      },
      error: (_, _) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }
}

class _VersionChipBar extends StatelessWidget {
  const _VersionChipBar({
    required this.versions,
    required this.currentVersion,
    required this.onVersionSelected,
  });

  final List<MovieVideoItem> versions;
  final MovieVideoItem currentVersion;
  final ValueChanged<MovieVideoItem> onVersionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label =
        currentVersion.versionLabel ??
        AppLocalizations.of(context).videoDefaultVersion;
    final resolution = _resolutionLabel(currentVersion);
    return GestureDetector(
      onTap: () => _showVersionSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.layers_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              resolution.isNotEmpty ? '$label · $resolution' : label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _showVersionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  AppLocalizations.of(context).videoSelectVersion,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              ...versions.map(
                (v) => ListTile(
                  leading: Icon(
                    v.id == currentVersion.id
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color:
                        v.id == currentVersion.id
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    v.versionLabel ??
                        AppLocalizations.of(context).videoDefaultVersion,
                  ),
                  subtitle: Text(_resolutionLabel(v)),
                  onTap: () {
                    Navigator.pop(context);
                    onVersionSelected(v);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _resolutionLabel(MovieVideoItem v) {
    final w = v.resolutionWidth;
    final h = v.resolutionHeight;
    if (w == null || h == null) return '';
    if (h >= 2160) return '4K';
    if (h >= 1080) return '1080p';
    if (h >= 720) return '720p';
    return '${h}p';
  }
}
