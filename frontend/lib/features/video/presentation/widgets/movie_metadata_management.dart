part of 'movie_management.dart';

class ScrapeQueueSection extends ConsumerWidget {
  const ScrapeQueueSection({required this.state, super.key});

  final MovieCenterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(movieCenterControllerProvider.notifier);
    final items =
        state.filteredMovies.isEmpty ? state.movies : state.filteredMovies;
    final movies =
        items.where((i) => i.seriesId == null || i.seriesId!.isEmpty).toList();
    final episodes =
        items
            .where((i) => i.seriesId != null && i.seriesId!.isNotEmpty)
            .toList();
    final groups = _groupEpisodesBySeries(episodes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieSectionHeading(
          title: AppLocalizations.of(context).videoSectionScrapeQueue,
          subtitle: AppLocalizations.of(context).videoScrapeQueueSubtitle,
        ),
        const SizedBox(height: 22),
        if (state.lastTask != null)
          MovieNoticePanel(
            icon: Icons.check_circle_rounded,
            title: AppLocalizations.of(context).videoTaskSubmitted,
            message: '${state.lastTask!.taskId}: ${state.lastTask!.message}',
          ),
        for (final group in groups)
          _ScrapeGroupPanel(
            group: group,
            onScrapeEpisode: (item) => controller.createScrapeTask(item),
          ),
        for (final item in movies.take(12))
          MovieAsyncActionRow(
            icon: Icons.manage_search_rounded,
            title: item.title,
            subtitle: '${item.metadataStatus} · ${item.year}',
            actionLabel: AppLocalizations.of(context).videoRetry,
            loadingLabel: AppLocalizations.of(context).videoSubmitting,
            successMessage:
                AppLocalizations.of(context).videoScrapeTaskSubmitted,
            onPressed: () => controller.createScrapeTask(item),
          ),
        if (items.isEmpty)
          EmptyMovieState(
            message: AppLocalizations.of(context).videoNoScrapeItems,
          ),
      ],
    );
  }

  List<_ScrapeGroup> _groupEpisodesBySeries(List<MovieVideoItem> episodes) {
    final map = <String, List<MovieVideoItem>>{};
    for (final ep in episodes) {
      final key = '${ep.seriesId}_${ep.seasonNumber ?? 0}';
      map.putIfAbsent(key, () => []).add(ep);
    }
    return map.entries.map((e) {
      final items = e.value;
      final first = items.first;
      return _ScrapeGroup(
        seriesId: first.seriesId!,
        seasonNumber: first.seasonNumber,
        title: first.title,
        episodes: items,
      );
    }).toList();
  }
}

class _ScrapeGroup {
  const _ScrapeGroup({
    required this.seriesId,
    required this.title,
    required this.episodes,
    this.seasonNumber,
  });

  final String seriesId;
  final int? seasonNumber;
  final String title;
  final List<MovieVideoItem> episodes;
}

class _ScrapeGroupPanel extends StatelessWidget {
  const _ScrapeGroupPanel({required this.group, required this.onScrapeEpisode});

  final _ScrapeGroup group;
  final ValueChanged<MovieVideoItem> onScrapeEpisode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = group;
    final l10n = AppLocalizations.of(context);
    final seasonText =
        g.seasonNumber != null
            ? l10n.videoSeasonNumber(g.seasonNumber!)
            : l10n.videoSectionTvShows;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.tv_rounded, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$seasonText · ${l10n.videoEpisodesPending(g.episodes.length)}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onScrapeEpisode(g.episodes.first),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                l10n.videoRetry,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MetadataManagementSection extends ConsumerWidget {
  const MetadataManagementSection({required this.items, super.key});

  final List<MovieVideoItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(movieCenterControllerProvider.notifier);
    // 按 seriesId 分组：有 seriesId 的剧集聚合为一行，无 seriesId 的独立显示
    final grouped = _groupBySeries(items);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieSectionHeading(
          title: AppLocalizations.of(context).videoSectionMetadataManagement,
          subtitle: AppLocalizations.of(context).videoMetadataSubtitle,
        ),
        const SizedBox(height: 22),
        for (final entry in grouped.take(14))
          _MetadataRow(
            item: entry.item,
            episodeCount: entry.episodeCount,
            onParse: () => controller.probeItem(entry.item),
          ),
        if (grouped.isEmpty)
          EmptyMovieState(
            message: AppLocalizations.of(context).videoNoMetadata,
          ),
      ],
    );
  }

  List<_MetadataGroupEntry> _groupBySeries(List<MovieVideoItem> items) {
    final seriesMap = <String, List<MovieVideoItem>>{};
    final standalone = <MovieVideoItem>[];
    for (final item in items) {
      final sid = item.seriesId;
      if (sid != null && sid.isNotEmpty) {
        seriesMap.putIfAbsent(sid, () => []).add(item);
      } else {
        standalone.add(item);
      }
    }
    final result = <_MetadataGroupEntry>[];
    for (final entry in seriesMap.entries) {
      final episodes = entry.value;
      // 使用第一集作为代表条目
      result.add(
        _MetadataGroupEntry(
          item: episodes.first,
          episodeCount: episodes.length,
        ),
      );
    }
    for (final item in standalone) {
      result.add(_MetadataGroupEntry(item: item));
    }
    return result;
  }
}

class _MetadataGroupEntry {
  const _MetadataGroupEntry({required this.item, this.episodeCount});
  final MovieVideoItem item;
  final int? episodeCount;
}

class _MetadataRow extends StatefulWidget {
  const _MetadataRow({required this.item, this.episodeCount, this.onParse});

  final MovieVideoItem item;
  final int? episodeCount;
  final Future<void> Function()? onParse;

  @override
  State<_MetadataRow> createState() => _MetadataRowState();
}

class _MetadataRowState extends State<_MetadataRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.videoColors.surfaceContainerHigh.withValues(
            alpha: _hovered ? 0.84 : 0.72,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.videoColors.outlineVariant.withValues(
              alpha: _hovered ? 0.35 : 0.18,
            ),
          ),
        ),
        child: Row(
          children: [
            // 海报缩略图
            Container(
              width: 64,
              height: 90,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: context.videoColors.surfaceContainerHighest,
                border: Border.all(
                  color: context.videoColors.outlineVariant.withValues(
                    alpha: 0.22,
                  ),
                ),
              ),
              child:
                  item.posterImageUrl != null
                      ? Image.network(
                        item.posterImageUrl!,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        errorBuilder:
                            (ctx, err, stack) => Icon(
                              Icons.movie_rounded,
                              color: context.videoColors.onSurfaceVariant,
                              size: 24,
                            ),
                      )
                      : Icon(
                        Icons.movie_rounded,
                        color: context.videoColors.onSurfaceVariant,
                        size: 24,
                      ),
            ),
            SizedBox(width: 14),
            // 文字信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          _hovered
                              ? context.videoColors.primary
                              : context.videoColors.onSurface,
                      fontSize: 15,
                      height: 20 / 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    widget.episodeCount != null
                        ? AppLocalizations.of(context).videoEpisodeStatus(
                          widget.episodeCount!,
                          item.metadataStatus,
                        )
                        : '${item.mediaType} · ${item.metadataStatus} · ${item.nfoStatus}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.videoColors.onSurfaceVariant.withValues(
                        alpha: _hovered ? 0.92 : 0.72,
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // 解析按钮
            if (widget.onParse != null) ...[
              _MetadataActionButton(
                icon: Icons.manage_search_rounded,
                label: AppLocalizations.of(context).videoParse,
                onPressed: widget.onParse!,
              ),
              const SizedBox(width: 8),
            ],
            // 编辑按钮
            _MetadataEditButton(
              onPressed: () => context.go('/video/${item.id}/metadata'),
            ),
            const SizedBox(width: 8),
            // NFO 导出按钮
            _MetadataActionButton(
              icon: Icons.description_outlined,
              label: 'NFO',
              onPressed: () => _showNfoPreview(context, item),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataEditButton extends StatelessWidget {
  const _MetadataEditButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.videoColors.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.videoColors.primary.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit_note_rounded,
              size: 16,
              color: context.videoColors.primary,
            ),
            SizedBox(width: 6),
            Text(
              AppLocalizations.of(context).videoEdit,
              style: TextStyle(
                color: context.videoColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataActionButton extends StatefulWidget {
  const _MetadataActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onPressed;

  @override
  State<_MetadataActionButton> createState() => _MetadataActionButtonState();
}

class _MetadataActionButtonState extends State<_MetadataActionButton> {
  bool _running = false;

  Future<void> _handlePressed() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      await widget.onPressed();
      if (mounted) {
        showMovieFeedback(
          context,
          AppLocalizations.of(context).videoParseComplete,
        );
      }
    } catch (error) {
      if (mounted) {
        showMovieFeedback(context, movieErrorMessage(error), isError: true);
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _running ? null : _handlePressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.videoColors.surfaceContainerHighest.withValues(
            alpha: 0.60,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.videoColors.outlineVariant.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_running)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.videoColors.onSurfaceVariant,
                ),
              )
            else
              Icon(
                widget.icon,
                size: 16,
                color: context.videoColors.onSurfaceVariant,
              ),
            SizedBox(width: 6),
            Text(
              _running
                  ? AppLocalizations.of(context).videoSubmitting
                  : widget.label,
              style: TextStyle(
                color: context.videoColors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
