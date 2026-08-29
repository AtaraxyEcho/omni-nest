import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/core/widgets/app_error_view.dart';
import 'package:omninest/core/widgets/app_loading.dart';
import 'package:omninest/features/video/application/movie_controller.dart';
import 'package:omninest/features/video/domain/movie_models.dart';
import 'package:omninest/features/video/presentation/widgets/movie_detail_cast.dart';
import 'package:omninest/features/video/presentation/widgets/movie_detail_overview.dart';
import 'package:omninest/features/video/presentation/widgets/movie_feedback.dart';
import 'package:omninest/features/video/presentation/widgets/movie_common_widgets.dart';
import 'package:omninest/features/video/presentation/widgets/movie_detail_page_frame.dart';
import 'package:omninest/features/video/presentation/widgets/movie_styles.dart';
import 'package:omninest/features/video/presentation/widgets/series_detail_hero.dart';
import 'package:omninest/features/video/presentation/widgets/series_detail_seasons.dart';

class SeriesDetailPage extends ConsumerWidget {
  const SeriesDetailPage({required this.seriesId, super.key});

  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(movieSeriesDetailProvider(seriesId));
    return detailAsync.when(
      data: (detail) {
        final section =
            detail.series.seriesType == 'ANIME'
                ? MovieSection.anime
                : MovieSection.tvShows;
        void backToLibrary() {
          ref
              .read(movieCenterControllerProvider.notifier)
              .selectSection(section);
          context.go('/video');
        }

        return MovieDetailPageFrame(
          child: _SeriesDetailContent(
            seriesId: seriesId,
            detail: detail,
            onBack: backToLibrary,
          ),
        );
      },
      error:
          (error, _) => Scaffold(
            body: AppErrorView(
              message: movieErrorMessage(error),
              onRetry:
                  () => ref.invalidate(movieSeriesDetailProvider(seriesId)),
            ),
          ),
      loading: () => const Scaffold(body: AppLoading.detail()),
    );
  }
}

class _SeriesDetailContent extends StatelessWidget {
  const _SeriesDetailContent({
    required this.seriesId,
    required this.detail,
    required this.onBack,
  });

  final String seriesId;
  final MovieSeriesDetail detail;
  final VoidCallback onBack;

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
            SeriesDetailHero(series: detail.series, width: w),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _SeriesActionBar(
                seriesId: seriesId,
                series: detail.series,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: MovieDetailOverview(
                overview: detail.series.overview,
                width: w,
              ),
            ),
            if (detail.cast.isNotEmpty || detail.crew.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: CastCrewSection(
                  cast: detail.cast,
                  crew: detail.crew,
                  width: w,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: SeasonListSection(
                seriesId: seriesId,
                seasons: detail.seasons,
              ),
            ),
            const SizedBox(height: 48),
          ],
        );
      },
    );
  }
}

class _SeriesActionBar extends ConsumerWidget {
  const _SeriesActionBar({required this.seriesId, required this.series});

  final String seriesId;
  final MovieSeries series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteAsync = ref.watch(seriesFavoriteProvider(seriesId));
    final isFavorite = favoriteAsync.asData?.value ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await ref
                    .read(movieCenterControllerProvider.notifier)
                    .toggleSeriesFavorite(seriesId);
                if (!context.mounted) {
                  return;
                }
                ref.invalidate(seriesFavoriteProvider(seriesId));
              } catch (error) {
                if (context.mounted) {
                  showMovieFeedback(
                    context,
                    movieErrorMessage(error),
                    isError: true,
                  );
                }
              }
            },
            icon: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
            ),
            label: Text(
              isFavorite
                  ? AppLocalizations.of(context).videoFavorited
                  : AppLocalizations.of(context).videoFavorite,
            ),
            style: movieOutlinedButtonStyle(context),
          ),
        ],
      ),
    );
  }
}
