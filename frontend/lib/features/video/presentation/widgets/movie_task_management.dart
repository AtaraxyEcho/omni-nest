part of 'movie_management.dart';

class TranscodeTasksSection extends ConsumerWidget {
  const TranscodeTasksSection({required this.state, super.key});

  final MovieCenterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(movieCenterControllerProvider.notifier);
    final videoItems =
        state.filteredMovies.isEmpty ? state.movies : state.filteredMovies;
    final transcodeTasks =
        state.tasks
            .where((task) => task.taskType == 'VIDEO_TRANSCODE')
            .toList();
    final audioTasks =
        state.tasks.where((task) => task.taskType == 'AUDIO_EXTRACT').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieSectionHeading(
          title: AppLocalizations.of(context).videoSectionTranscodeTasks,
          subtitle: AppLocalizations.of(context).videoTranscodeSubtitle,
        ),
        const SizedBox(height: 22),
        if (state.lastTask != null)
          MovieNoticePanel(
            icon: Icons.check_circle_rounded,
            title: AppLocalizations.of(context).videoTaskSubmitted,
            message: '${state.lastTask!.taskId}: ${state.lastTask!.message}',
          ),
        for (final item in videoItems.take(8))
          _TranscodeActionRow(
            item: item,
            onCreateTranscode: () => controller.createTranscodeTask(item),
            onCreateAudioExtract: () => controller.createAudioExtractTask(item),
          ),
        if (videoItems.isEmpty)
          EmptyMovieState(
            message: AppLocalizations.of(context).videoNoTranscodeMedia,
          ),
        const SizedBox(height: 24),
        TaskBoardSection(
          title: AppLocalizations.of(context).videoAudioExtractRecords,
          subtitle: AppLocalizations.of(context).videoAudioExtractSubtitle,
          tasks: audioTasks,
        ),
        const SizedBox(height: 24),
        TaskBoardSection(
          title: AppLocalizations.of(context).videoTranscodeRecords,
          subtitle: AppLocalizations.of(context).videoTranscodeRecordsSubtitle,
          tasks: transcodeTasks,
        ),
      ],
    );
  }
}

class _TranscodeActionRow extends StatefulWidget {
  const _TranscodeActionRow({
    required this.item,
    required this.onCreateTranscode,
    required this.onCreateAudioExtract,
  });

  final MovieVideoItem item;
  final Future<void> Function() onCreateTranscode;
  final Future<void> Function() onCreateAudioExtract;

  @override
  State<_TranscodeActionRow> createState() => _TranscodeActionRowState();
}

class _TranscodeActionRowState extends State<_TranscodeActionRow> {
  bool _hovered = false;
  String? _transcodeLoading;
  String? _audioLoading;
  String? _errorMessage;

  Future<void> _handleTranscode() async {
    if (_transcodeLoading != null) return;
    setState(() {
      _transcodeLoading = AppLocalizations.of(context).videoSubmitting;
      _errorMessage = null;
    });
    try {
      await widget.onCreateTranscode();
      if (mounted) {
        showMovieFeedback(
          context,
          AppLocalizations.of(context).videoTranscodeSubmitted,
        );
      }
    } catch (error) {
      final message = movieErrorMessage(error);
      if (mounted) {
        setState(() => _errorMessage = message);
        showMovieFeedback(context, message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _transcodeLoading = null);
    }
  }

  Future<void> _handleAudioExtract() async {
    if (_audioLoading != null) return;
    setState(() {
      _audioLoading = AppLocalizations.of(context).videoSubmitting;
      _errorMessage = null;
    });
    try {
      await widget.onCreateAudioExtract();
      if (mounted) {
        showMovieFeedback(
          context,
          AppLocalizations.of(context).videoAudioExtractSubmitted,
        );
      }
    } catch (error) {
      final message = movieErrorMessage(error);
      if (mounted) {
        setState(() => _errorMessage = message);
        showMovieFeedback(context, message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _audioLoading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.videoColors.surfaceContainerHigh.withValues(
            alpha: _hovered ? 0.84 : 0.72,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                _hovered
                    ? context.videoColors.primary.withValues(alpha: 0.20)
                    : context.videoColors.outlineVariant.withValues(
                      alpha: 0.22,
                    ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.movie_rounded, color: context.videoColors.primary),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.videoColors.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${widget.item.mediaType} · ${widget.item.runtimeText} · ${widget.item.year}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.videoColors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _ActionButton(
                  icon: Icons.video_settings_rounded,
                  label:
                      _transcodeLoading ??
                      AppLocalizations.of(context).videoTranscode,
                  loading: _transcodeLoading != null,
                  onPressed: _handleTranscode,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.audio_file_rounded,
                  label:
                      _audioLoading ??
                      AppLocalizations.of(context).videoAudioExtract,
                  loading: _audioLoading != null,
                  onPressed: _handleAudioExtract,
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool loading;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: loading ? null : () => onPressed(),
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon:
          loading
              ? SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.videoColors.primary,
                ),
              )
              : Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class TaskBoardSection extends StatelessWidget {
  const TaskBoardSection({
    required this.title,
    required this.subtitle,
    required this.tasks,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<MovieTask> tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieSectionHeading(title: title, subtitle: subtitle),
        SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.videoColors.surfaceContainerHigh.withValues(
              alpha: 0.78,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.videoColors.outlineVariant.withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tasks.isEmpty)
                EmptyMovieState(
                  message: AppLocalizations.of(context).videoNoTasks,
                )
              else
                for (final task in tasks.take(16)) TaskRow(task: task),
            ],
          ),
        ),
      ],
    );
  }
}

class LibraryScanSection extends ConsumerWidget {
  const LibraryScanSection({required this.state, super.key});

  final MovieCenterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanTasks =
        state.tasks
            .where(
              (task) => const {
                'MEDIA_SCAN',
                'LOCAL_VIDEO_LIBRARY_DISCOVERY',
                'LOCAL_VIDEO_LIBRARY_APPLY',
              }.contains(task.taskType),
            )
            .toList();
    final sourcesAsync = ref.watch(videoLibrarySourcesProvider);
    final sources = sourcesAsync.asData?.value ?? const <VideoLibrarySource>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final workbench =
            constraints.maxWidth >= 960 && constraints.maxHeight >= 520;
        // 只读概览：库源配置已收敛至 Admin 媒体库管理页
        final overview = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sources.isEmpty)
                Text(
                  AppLocalizations.of(context).adminLibrarySourcesEmpty,
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                ...sources.map(
                  (source) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color:
                              source.enabled
                                  ? Colors.green.shade600
                                  : Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: Text(
                            source.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            AppLocalizations.of(context).videoSourceScanStatus(
                              scanStatusLabel(
                                AppLocalizations.of(context),
                                source.scanStatus,
                              ),
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).videoSourceScannedCount(source.lastScannedCount),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
        if (!workbench) {
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: MovieSectionHeading(
                    title: AppLocalizations.of(context).videoSectionLibraryScan,
                    subtitle:
                        AppLocalizations.of(context).videoLibraryScanSubtitle,
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(top: 20)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: overview,
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(top: 24)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: TaskBoardSection(
                    title: AppLocalizations.of(context).videoRecentScanRecords,
                    subtitle:
                        AppLocalizations.of(context).videoRecentScanSubtitle,
                    tasks: scanTasks,
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: MovieSectionHeading(
                      title:
                          AppLocalizations.of(context).videoSectionLibraryScan,
                      subtitle:
                          AppLocalizations.of(context).videoLibraryScanSubtitle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.invalidate(videoStorageLocationsProvider);
                      ref.invalidate(videoLibrarySourcesProvider);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      AppLocalizations.of(context).videoRefreshSources,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              overview,
              const SizedBox(height: 24),
              TaskBoardSection(
                title: AppLocalizations.of(context).videoRecentScanRecords,
                subtitle: AppLocalizations.of(context).videoRecentScanSubtitle,
                tasks: scanTasks,
              ),
            ],
          ),
        );
      },
    );
  }
}

class TaskRow extends StatelessWidget {
  const TaskRow({required this.task, super.key});

  final MovieTask task;

  @override
  Widget build(BuildContext context) {
    final failed = task.status.toUpperCase() == 'FAILED';
    final completed = task.status.toUpperCase() == 'COMPLETED';
    final running =
        task.status.toUpperCase() == 'RUNNING' ||
        task.status.toUpperCase() == 'QUEUED';
    final statusColor =
        failed
            ? Theme.of(context).colorScheme.error
            : completed
            ? context.videoColors.primary
            : running
            ? context.videoColors.primary
            : context.videoColors.onSurfaceVariant;
    final l10n = AppLocalizations.of(context);
    final taskLabel = switch (task.taskType) {
      'AUDIO_EXTRACT' => l10n.videoAudioExtract,
      'VIDEO_TRANSCODE' => l10n.videoTranscode,
      'MEDIA_SCRAPE' => l10n.videoMetadataScrape,
      'MEDIA_SCAN' => l10n.videoMediaScan,
      'LOCAL_VIDEO_LIBRARY_DISCOVERY' => l10n.videoLocalDiscoveryTask,
      'LOCAL_VIDEO_LIBRARY_APPLY' => l10n.videoLocalImportTask,
      _ => task.taskType,
    };
    final statusLabel = switch (task.status.toUpperCase()) {
      'QUEUED' => l10n.videoQueued,
      'RUNNING' => l10n.videoRunning,
      'COMPLETED' => l10n.videoCompleted,
      'FAILED' => l10n.videoFailed,
      'CANCELLED' => l10n.videoCancelled,
      'DLQ' => l10n.videoDeadLetterQueue,
      _ => task.status,
    };
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.videoColors.surfaceContainerHighest.withValues(
          alpha: 0.46,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusDot(color: statusColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$taskLabel · $statusLabel',
                  style: TextStyle(
                    color: context.videoColors.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${task.progress}%',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: task.progress / 100.0,
              minHeight: 4,
              backgroundColor: context.videoColors.surfaceContainerHighest
                  .withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation<Color>(
                failed
                    ? Theme.of(context).colorScheme.error
                    : completed
                    ? context.videoColors.primary.withValues(alpha: 0.7)
                    : context.videoColors.primary,
              ),
            ),
          ),
          if (task.errorSummary != null && task.errorSummary!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              task.errorSummary!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
