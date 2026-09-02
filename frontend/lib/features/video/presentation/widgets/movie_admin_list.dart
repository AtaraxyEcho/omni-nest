part of 'movie_management.dart';

/// 影片管理工作区：序号列表、状态筛选、行内操作与任务进度弹窗。
class MovieAdminSection extends ConsumerStatefulWidget {
  const MovieAdminSection({super.key});

  @override
  ConsumerState<MovieAdminSection> createState() => _MovieAdminSectionState();
}

class _MovieAdminSectionState extends ConsumerState<MovieAdminSection> {
  static const int _pageSize = 20;

  int _page = 0;
  String? _runningAction;

  MovieCenterController get _controller =>
      ref.read(movieCenterControllerProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(movieCenterControllerProvider).asData?.value;
    if (state == null) {
      return const SizedBox.shrink();
    }
    final entries = _buildEntries(state.filteredMovies);
    final pageCount = (entries.length / _pageSize).ceil().clamp(1, 1 << 30);
    final safePage = _page.clamp(0, pageCount - 1);
    final pageEntries = entries
        .skip(safePage * _pageSize)
        .take(_pageSize)
        .toList(growable: false);
    final activeTaskCount =
        state.tasks
            .where(
              (task) =>
                  task.status.toUpperCase() == 'RUNNING' ||
                  task.status.toUpperCase() == 'QUEUED',
            )
            .length;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MovieSectionHeading(
                    title: l10n.videoSectionMovieAdmin,
                    subtitle: l10n.videoMovieAdminSubtitle,
                  ),
                ),
                const SizedBox(width: 16),
                _buildHeaderActions(context, l10n, activeTaskCount),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          sliver: SliverToBoxAdapter(
            child: _buildFilterChips(context, l10n, state.filter),
          ),
        ),
        if (pageEntries.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            sliver: SliverToBoxAdapter(
              child: EmptyMovieState(message: l10n.videoMovieAdminEmpty),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            sliver: SliverList.builder(
              itemCount: pageEntries.length,
              itemBuilder: (context, index) {
                return _buildRow(
                  context,
                  l10n,
                  entry: pageEntries[index],
                  rowNumber: safePage * _pageSize + index + 1,
                );
              },
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          sliver: SliverToBoxAdapter(
            child: _buildPager(context, l10n, safePage, pageCount),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderActions(
    BuildContext context,
    AppLocalizations l10n,
    int activeTaskCount,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () => context.go('/admin/storage'),
          icon: const Icon(Icons.dns_outlined, size: 18),
          label: Text(l10n.videoAdminLibrarySources),
        ),
        _TaskProgressButton(
          activeCount: activeTaskCount,
          onOpen: _showTaskProgressDialog,
        ),
        IconButton(
          tooltip: l10n.videoRefreshTooltip,
          onPressed: () => _controller.refresh(),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    AppLocalizations l10n,
    MovieLibraryFilter currentFilter,
  ) {
    final chips = <MovieLibraryFilter, String>{
      MovieLibraryFilter.all: l10n.videoLibraryFilterAll,
      MovieLibraryFilter.matched: l10n.videoMatched,
      MovieLibraryFilter.pending: l10n.videoPendingScrape,
      MovieLibraryFilter.failed: l10n.videoMatchFailed,
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in chips.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: currentFilter == entry.key,
            onSelected: (_) {
              setState(() => _page = 0);
              _controller.setFilter(entry.key);
            },
          ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    AppLocalizations l10n, {
    required _AdminRowEntry entry,
    required int rowNumber,
  }) {
    final item = entry.item;
    final metaLine =
        entry.episodeCount != null
            ? '${l10n.videoSectionTvShows} · ${l10n.videoSeriesEpisodeCount(entry.episodeCount!)}'
            : '${item.mediaType == 'MOVIE' ? l10n.videoSectionMovies : item.mediaType} · ${item.year}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.videoColors.surfaceContainerHigh.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: context.videoColors.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '$rowNumber',
              style: TextStyle(
                color: context.videoColors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _PosterThumb(item: item),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.videoColors.onSurface,
                    fontSize: 15,
                    height: 20 / 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  metaLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.videoColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _MetadataStatusPill(status: item.metadataStatus),
          const SizedBox(width: 8),
          _NfoStatusPill(status: item.nfoStatus),
          const SizedBox(width: 10),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () => context.go('/video/${item.id}/metadata'),
            child: Text(l10n.videoEdit),
          ),
          const SizedBox(width: 6),
          _buildRowMenu(context, l10n, item),
        ],
      ),
    );
  }

  Widget _buildRowMenu(
    BuildContext context,
    AppLocalizations l10n,
    MovieVideoItem item,
  ) {
    final busy = _runningAction != null;
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz_rounded,
        color: context.videoColors.onSurfaceVariant,
      ),
      onSelected: (action) {
        switch (action) {
          case 'scrape':
            _runAction('scrape', () => _controller.createScrapeTask(item));
          case 'parse':
            _runAction('parse', () => _controller.probeItem(item));
          case 'transcode':
            _runAction(
              'transcode',
              () => _controller.createTranscodeTask(item),
            );
          case 'audio':
            _runAction('audio', () => _controller.createAudioExtractTask(item));
          case 'nfo':
            unawaited(_showNfoPreview(context, item));
        }
      },
      itemBuilder:
          (context) => [
            _menuItem(
              value: 'scrape',
              icon: Icons.manage_search_rounded,
              label: l10n.videoMetadataScrape,
              enabled: !busy || _runningAction == 'scrape',
            ),
            _menuItem(
              value: 'parse',
              icon: Icons.travel_explore_rounded,
              label: l10n.videoParse,
              enabled: !busy || _runningAction == 'parse',
            ),
            _menuItem(
              value: 'nfo',
              icon: Icons.description_outlined,
              label: 'NFO',
              enabled: true,
            ),
            _menuItem(
              value: 'transcode',
              icon: Icons.video_settings_rounded,
              label: l10n.videoTranscode,
              enabled: !busy || _runningAction == 'transcode',
            ),
            _menuItem(
              value: 'audio',
              icon: Icons.audio_file_rounded,
              label: l10n.videoAudioExtract,
              enabled: !busy || _runningAction == 'audio',
            ),
          ],
    );
  }

  PopupMenuItem<String> _menuItem({
    required String value,
    required IconData icon,
    required String label,
    required bool enabled,
  }) {
    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildPager(
    BuildContext context,
    AppLocalizations l10n,
    int safePage,
    int pageCount,
  ) {
    if (pageCount <= 1) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: l10n.videoPreviousPage,
          onPressed:
              safePage > 0 ? () => setState(() => _page = safePage - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        const SizedBox(width: 8),
        Text(
          '${safePage + 1} / $pageCount',
          style: TextStyle(
            color: context.videoColors.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: l10n.videoNextPage,
          onPressed:
              safePage < pageCount - 1
                  ? () => setState(() => _page = safePage + 1)
                  : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  List<_AdminRowEntry> _buildEntries(List<MovieVideoItem> items) {
    final seriesMap = <String, List<MovieVideoItem>>{};
    final standalone = <MovieVideoItem>[];
    for (final item in items) {
      final seriesId = item.seriesId;
      if (seriesId != null && seriesId.isNotEmpty) {
        seriesMap.putIfAbsent(seriesId, () => []).add(item);
      } else {
        standalone.add(item);
      }
    }
    return <_AdminRowEntry>[
      for (final entry in seriesMap.entries)
        _AdminRowEntry(
          item: entry.value.first,
          episodeCount: entry.value.length,
        ),
      for (final item in standalone) _AdminRowEntry(item: item),
    ];
  }

  Future<void> _runAction(
    String actionId,
    Future<void> Function() action,
  ) async {
    if (_runningAction != null) {
      return;
    }
    setState(() => _runningAction = actionId);
    try {
      await action();
      if (mounted) {
        _showSubmittedFeedback();
      }
    } catch (error) {
      if (mounted) {
        showMovieFeedback(context, movieErrorMessage(error), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _runningAction = null);
      }
    }
  }

  void _showSubmittedFeedback() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.videoTaskSubmitted),
          action: SnackBarAction(
            label: l10n.videoSnackViewProgress,
            onPressed: _showTaskProgressDialog,
          ),
        ),
      );
  }

  void _showTaskProgressDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => const _MovieAdminTaskDialog(),
    );
  }
}

class _AdminRowEntry {
  const _AdminRowEntry({required this.item, this.episodeCount});

  final MovieVideoItem item;
  final int? episodeCount;
}

class _PosterThumb extends StatelessWidget {
  const _PosterThumb({required this.item});

  final MovieVideoItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 62,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: context.videoColors.surfaceContainerHighest,
        border: Border.all(
          color: context.videoColors.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child:
          item.posterImageUrl != null
              ? Image.network(
                item.posterImageUrl!,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                errorBuilder:
                    (context, error, stackTrace) => Icon(
                      Icons.movie_rounded,
                      size: 18,
                      color: context.videoColors.onSurfaceVariant,
                    ),
              )
              : Icon(
                Icons.movie_rounded,
                size: 18,
                color: context.videoColors.onSurfaceVariant,
              ),
    );
  }
}

class _MetadataStatusPill extends StatelessWidget {
  const _MetadataStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (status) {
      'MATCHED' => l10n.videoMatched,
      'PENDING' => l10n.videoPendingScrape,
      'FAILED' => l10n.videoMatchFailed,
      'MANUAL' => l10n.videoManualEdit,
      _ => status,
    };
    final color = switch (status) {
      'MATCHED' => Colors.green.shade600,
      'PENDING' => Colors.amber.shade700,
      'FAILED' => Theme.of(context).colorScheme.error,
      _ => context.videoColors.onSurfaceVariant,
    };
    return _StatusPill(label: label, color: color);
  }
}

class _NfoStatusPill extends StatelessWidget {
  const _NfoStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color =
        status.toUpperCase() == 'NONE'
            ? context.videoColors.onSurfaceVariant
            : context.videoColors.primary;
    return _StatusPill(label: 'NFO · $status', color: color);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TaskProgressButton extends StatelessWidget {
  const _TaskProgressButton({required this.activeCount, required this.onOpen});

  final int activeCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FilledButton.tonalIcon(
      onPressed: onOpen,
      icon: const Icon(Icons.task_alt_rounded, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.videoTaskProgressDialog),
          if (activeCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: context.videoColors.primary.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$activeCount',
                style: TextStyle(
                  color: context.videoColors.onPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _showNfoPreview(BuildContext context, MovieVideoItem item) async {
  final container = ProviderScope.containerOf(context);
  final nfoAsync = container.read(movieNfoPreviewProvider(item.id));
  await showDialog<void>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          backgroundColor: context.videoColors.surfaceContainerHigh,
          title: Text(
            AppLocalizations.of(context).videoNfoPreviewTitle(item.title),
          ),
          content: SizedBox(
            width: 600,
            height: 500,
            child: nfoAsync.when(
              data:
                  (nfo) => SingleChildScrollView(
                    child: SelectableText(
                      nfo.content,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: context.videoColors.onSurface,
                      ),
                    ),
                  ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (e, _) => Center(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      ).videoLoadFailedWith(e.toString()),
                    ),
                  ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context).videoClose),
            ),
          ],
        ),
  );
}
