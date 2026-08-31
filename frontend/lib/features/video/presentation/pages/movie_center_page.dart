import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/core/auth/auth_controller.dart';
import 'package:omninest/core/errors/error_message.dart';
import 'package:omninest/core/widgets/app_error_view.dart';
import 'package:omninest/core/widgets/app_loading.dart';
import 'package:omninest/features/video/application/movie_controller.dart';
import 'package:omninest/features/video/presentation/widgets/movie_category_bars.dart';
import 'package:omninest/features/video/presentation/widgets/movie_collections.dart';
import 'package:omninest/features/video/presentation/widgets/movie_common_widgets.dart';
import 'package:omninest/features/video/presentation/widgets/movie_continue.dart';
import 'package:omninest/features/video/presentation/widgets/movie_filters.dart';
import 'package:omninest/features/video/presentation/widgets/movie_hero.dart';
import 'package:omninest/features/video/presentation/widgets/movie_history.dart';
import 'package:omninest/features/video/presentation/widgets/movie_management.dart';
import 'package:omninest/features/video/presentation/widgets/movie_poster_grid.dart';
import 'package:omninest/features/video/presentation/widgets/movie_series.dart';
import 'package:omninest/features/video/presentation/widgets/movie_shell.dart';
import 'package:omninest/features/video/presentation/widgets/movie_responsive_layout.dart';

class MovieCenterPage extends ConsumerWidget {
  const MovieCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(movieCenterControllerProvider);
    return state.when(
      data: (data) {
        // 管理分区不再静默回退到电影：无权限时由内容区显示明确提示，
        // 避免用户点击「媒体库管理」等管理项后被悄悄带回电影页。
        final visibleState = data;
        return Column(
          children: [
            if (data.errorMessage != null)
              MaterialBanner(
                content: Text(data.errorMessage!),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                actions: [
                  TextButton(
                    onPressed:
                        () =>
                            ref
                                .read(movieCenterControllerProvider.notifier)
                                .clearError(),
                    child: Text(AppLocalizations.of(context).videoClose),
                  ),
                ],
              ),
            Expanded(
              child: MovieShell(
                section: visibleState.section,
                childOwnsScroll:
                    visibleState.section == MovieSection.movies ||
                    visibleState.section == MovieSection.recent ||
                    visibleState.section == MovieSection.libraryScan,
                onSectionSelected:
                    ref
                        .read(movieCenterControllerProvider.notifier)
                        .selectSection,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: _MovieSearchField(state: visibleState)),
                  ],
                ),
                onRefresh: () async {
                  await ref
                      .read(movieCenterControllerProvider.notifier)
                      .refresh();
                },
                child: _MovieContent(state: visibleState),
              ),
            ),
          ],
        );
      },
      error:
          (error, stackTrace) => Scaffold(
            backgroundColor: context.videoColors.surface,
            body: AppErrorView(
              message: describeUserFacingError(error).displayMessage,
              onRetry: () => ref.invalidate(movieCenterControllerProvider),
            ),
          ),
      loading:
          () => Scaffold(
            backgroundColor: context.videoColors.surface,
            body: AppLoading.grid(gridAspectRatio: 0.68),
          ),
    );
  }
}

class _MovieSearchField extends ConsumerWidget {
  const _MovieSearchField({required this.state});

  final MovieCenterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: TextField(
        onChanged:
            ref.read(movieCenterControllerProvider.notifier).setSearchQuery,
        style: TextStyle(
          color: context.videoColors.onSurface,
          fontSize: 13,
          height: 18 / 13,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: context.videoColors.surfaceContainerHighest.withValues(
            alpha: 0.40,
          ),
          hintText: AppLocalizations.of(context).videoSearchLibraryHint,
          hintStyle: TextStyle(
            color: context.videoColors.onSurfaceVariant.withValues(alpha: 0.6),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: context.videoColors.onSurfaceVariant.withValues(alpha: 0.8),
            size: 20,
          ),
          prefixIconConstraints: BoxConstraints(minWidth: 40),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide(
              color: context.videoColors.primary.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

class _MovieContent extends ConsumerWidget {
  const _MovieContent({required this.state});

  final MovieCenterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredItems = state.filteredMovies;
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authSessionProvider).asData?.value.user;
    final canManage =
        user?.permissions.contains('media:library:manage') ?? false;
    if (state.section.requiresManagementRole && !canManage) {
      return _ManagementAccessDenied(l10n: l10n);
    }
    if (state.loadingSections.contains(state.section) &&
        !state.loadedSections.contains(state.section)) {
      return AppLoading.grid(gridAspectRatio: 0.68);
    }
    return switch (state.section) {
      MovieSection.movies => _MovieLibrarySection(
        title: l10n.videoMovieLibrary,
        subtitle: l10n.videoMovieLibrarySubtitle,
        state: state,
      ),
      MovieSection.tvShows => SeriesSection(
        allSeries: state.filteredSeries,
        series: state.filteredSeries,
        episodes: filteredItems,
        categoryFilter:
            (item) =>
                item.mediaType != 'MOVIE' &&
                (item.seriesId == null ||
                    !state.animeSeries.any((s) => s.id == item.seriesId)),
      ),
      MovieSection.anime => SeriesSection(
        allSeries: state.animeSeries,
        series: state.filteredAnimeSeries,
        episodes: filteredItems,
        title: l10n.videoAnimeLibrary,
        subtitle: l10n.videoAnimeLibrarySubtitle,
        variant: SeriesCatalogVariant.anime,
        categoryFilter:
            (item) =>
                item.mediaType == 'EPISODE' &&
                item.seriesId != null &&
                state.animeSeries.any((s) => s.id == item.seriesId),
      ),
      MovieSection.collections => CollectionsSection(
        totalCount: state.movies.length,
        collections: state.collections,
      ),
      MovieSection.recent => _MovieLibrarySection(
        title: l10n.videoSectionRecent,
        subtitle: l10n.videoRecentSubtitle,
        state: state,
      ),
      MovieSection.continueWatching => ContinueSection(
        items: state.continueWatching,
      ),
      MovieSection.favorites => MoviePosterGridSection(
        title: l10n.videoSectionFavorites,
        subtitle: l10n.videoFavoritesSubtitle,
        items: state.favoriteItems,
      ),
      MovieSection.history => HistorySection(
        items: state.watchHistory,
        onDelete:
            (entry) => ref
                .read(movieCenterControllerProvider.notifier)
                .deleteHistoryItem(entry),
        onClearAll:
            () =>
                ref.read(movieCenterControllerProvider.notifier).clearHistory(),
      ),
      MovieSection.scrapeQueue => ScrapeQueueSection(state: state),
      MovieSection.metadataManagement => MetadataManagementSection(
        items: state.movies,
      ),
      MovieSection.transcodeTasks => TranscodeTasksSection(state: state),
      MovieSection.libraryScan => LibraryScanSection(state: state),
    };
  }
}

class _ManagementAccessDenied extends StatelessWidget {
  const _ManagementAccessDenied({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.admin_panel_settings_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              l10n.videoManageAdminOnly,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovieLibrarySection extends ConsumerStatefulWidget {
  const _MovieLibrarySection({
    required this.title,
    required this.subtitle,
    required this.state,
  });

  final String title;
  final String subtitle;
  final MovieCenterState state;

  @override
  ConsumerState<_MovieLibrarySection> createState() =>
      _MovieLibrarySectionState();
}

class _MovieLibrarySectionState extends ConsumerState<_MovieLibrarySection> {
  final ScrollController _scrollController = ScrollController();
  bool _requestingNextPage = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _requestingNextPage) {
      return;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels > 720) {
      return;
    }
    final state = widget.state;
    if (state.section != MovieSection.movies ||
        !state.movieHasMore ||
        state.movieLoadingMore) {
      return;
    }
    _requestingNextPage = true;
    unawaited(_loadNextPage());
  }

  Future<void> _loadNextPage() async {
    try {
      await ref
          .read(movieCenterControllerProvider.notifier)
          .loadNextLibraryPage();
    } finally {
      _requestingNextPage = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final filteredItems = state.filteredMovies;
    final heroItems = movieHeroItems(filteredItems);
    final allMovies =
        state.movies.where((item) => item.mediaType == 'MOVIE').toList();
    final controller = ref.read(movieCenterControllerProvider.notifier);
    return LayoutBuilder(
      builder: (context, constraints) {
        final basePadding = constraints.maxWidth < 700 ? 16.0 : 32.0;
        final availableWidth = constraints.maxWidth - basePadding * 2;
        final contentWidth =
            availableWidth.clamp(0.0, movieDesktopContentMaxWidth).toDouble();
        final horizontalPadding = ((constraints.maxWidth - contentWidth) / 2)
            .clamp(basePadding, double.infinity);
        final horizontal = horizontalPadding.toDouble();
        return CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 32, horizontal, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MovieHeroCarousel(items: heroItems),
                    const SizedBox(height: 24),
                    MovieSectionHeading(
                      title: widget.title,
                      subtitle: widget.subtitle,
                    ),
                    const SizedBox(height: 22),
                    const MovieFilterBar(),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              sliver:
                  state.viewMode == MovieViewMode.list
                      ? MovieListSliver(items: filteredItems)
                      : MoviePosterSliverGrid(items: filteredItems),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 48),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    if (state.movieLoadingMore)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    MovieCategoryBars(
                      items: allMovies,
                      viewMode: state.viewMode,
                      onViewMore: controller.toggleGenre,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
