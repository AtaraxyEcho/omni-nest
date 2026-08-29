part of 'movie_management.dart';

class LocalLibrarySourcesPanel extends ConsumerStatefulWidget {
  const LocalLibrarySourcesPanel({super.key});

  @override
  ConsumerState<LocalLibrarySourcesPanel> createState() =>
      _LocalLibrarySourcesPanelState();
}

class _LocalLibrarySourcesPanelState
    extends ConsumerState<LocalLibrarySourcesPanel> {
  String? _selectedSourceId;
  String? _scanningSourceId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locations = ref.watch(videoStorageLocationsProvider);
    final sources = ref.watch(videoLibrarySourcesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MediaLibraryCommandBar(
          canAdd:
              locations.asData?.value.any((location) => location.available) ==
              true,
          onRefresh: () {
            ref.invalidate(videoStorageLocationsProvider);
            ref.invalidate(videoLibrarySourcesProvider);
          },
          onAdd:
              () => showDialog<void>(
                context: context,
                builder:
                    (context) => _VideoLibrarySourceDialog(
                      locations: locations.requireValue,
                    ),
              ),
        ),
        const SizedBox(height: 12),
        locations.when(
          loading: () => const LinearProgressIndicator(),
          error:
              (error, _) => MovieNoticePanel(
                icon: Icons.warning_amber_rounded,
                title: l10n.videoStorageLocationUnavailable,
                message: movieErrorMessage(error),
              ),
          data: (items) {
            if (items.where((item) => item.available).isEmpty) {
              return MovieNoticePanel(
                icon: Icons.admin_panel_settings_outlined,
                title: l10n.videoNoStorageLocation,
                message: l10n.videoNoStorageLocationHint,
              );
            }
            return sources.when(
              loading: () => const LinearProgressIndicator(),
              error:
                  (error, _) => MovieNoticePanel(
                    icon: Icons.error_outline_rounded,
                    title: l10n.videoLoadSourcesFailed,
                    message: movieErrorMessage(error),
                  ),
              data: (sourceItems) {
                if (sourceItems.isEmpty) {
                  return _MediaLibraryEmptyState(
                    onAdd:
                        () => showDialog<void>(
                          context: context,
                          builder:
                              (context) =>
                                  _VideoLibrarySourceDialog(locations: items),
                        ),
                  );
                }
                final selectedSource = sourceItems.firstWhere(
                  (source) => source.id == _selectedSourceId,
                  orElse: () => sourceItems.first,
                );
                return _buildWorkspace(
                  context,
                  items,
                  sourceItems,
                  selectedSource,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildWorkspace(
    BuildContext context,
    List<VideoStorageLocation> locations,
    List<VideoLibrarySource> sources,
    VideoLibrarySource selectedSource,
  ) {
    final latestRun = ref.watch(latestMediaScanRunProvider(selectedSource.id));
    final backendScanning = latestRun.maybeWhen(
      data: (run) => run?.active == true,
      orElse: () => false,
    );
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final split = constraints.maxWidth >= 960;
            final navigator = _MediaLibrarySourceNavigator(
              sources: sources,
              selectedSourceId: selectedSource.id,
              bounded: split,
              onSelected:
                  (source) => setState(() => _selectedSourceId = source.id),
            );
            final workspace = _MediaLibrarySourceWorkspace(
              source: selectedSource,
              locations: locations,
              bounded: split,
              scanning:
                  _scanningSourceId == selectedSource.id || backendScanning,
              onEdit:
                  () => showDialog<void>(
                    context: context,
                    builder:
                        (context) => _VideoLibrarySourceDialog(
                          locations: locations,
                          source: selectedSource,
                        ),
                  ),
              onScan: () => _scan(selectedSource),
              onDelete: () => _delete(selectedSource),
            );
            if (!split) {
              return Column(
                key: const Key('mediaLibraryMobileStack'),
                children: [navigator, const SizedBox(height: 12), workspace],
              );
            }
            return SizedBox(
              key: const Key('mediaLibraryDesktopSplit'),
              height: 650,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 320, child: navigator),
                  const SizedBox(width: 12),
                  Expanded(child: workspace),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        const _UnavailableLocalMediaPanel(),
      ],
    );
  }

  Future<void> _scan(VideoLibrarySource source) async {
    setState(() => _scanningSourceId = source.id);
    try {
      final task = await ref
          .read(videoLibrarySourceActionsProvider)
          .scan(source.id);
      if (mounted) {
        showMovieFeedback(context, task.message);
      }
    } on Exception catch (error) {
      if (mounted) {
        showMovieFeedback(context, movieErrorMessage(error), isError: true);
      }
    } finally {
      // 入队后由来源 scanStatus 和 latestMediaScanRunProvider 继续展示真实后台状态。
      if (mounted && _scanningSourceId == source.id) {
        setState(() => _scanningSourceId = null);
      }
    }
  }

  Future<void> _delete(VideoLibrarySource source) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.videoDeleteLibrarySource),
            content: Text(l10n.videoDeleteLibrarySourceConfirm(source.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.videoCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.filesDelete),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _scanningSourceId = source.id);
    try {
      await ref.read(videoLibrarySourceActionsProvider).delete(source.id);
      if (mounted) {
        setState(() {
          _scanningSourceId = null;
          if (_selectedSourceId == source.id) _selectedSourceId = null;
        });
        showMovieFeedback(context, l10n.videoDeleteLibrarySourceDone);
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _scanningSourceId = null);
        showMovieFeedback(context, movieErrorMessage(error), isError: true);
      }
    }
  }
}

class _MediaLibraryCommandBar extends StatelessWidget {
  const _MediaLibraryCommandBar({
    required this.canAdd,
    required this.onRefresh,
    required this.onAdd,
  });

  final bool canAdd;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.videoColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.videoColors.outlineVariant.withValues(alpha: 0.36),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final heading = Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.videoColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.video_library_outlined,
                  color: context.videoColors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.videoLocalLibrarySources,
                      style: TextStyle(
                        color: context.videoColors.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.videoLocalLibrarySourcesSubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.videoColors.onSurfaceVariant,
                        fontSize: 12,
                        height: 16 / 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onRefresh,
                tooltip: l10n.videoRefreshSources,
                icon: const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: canAdd ? onAdd : null,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.videoAddLibrarySource),
              ),
            ],
          );
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: actions,
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: heading),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _MediaLibraryEmptyState extends StatelessWidget {
  const _MediaLibraryEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      decoration: BoxDecoration(
        color: context.videoColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.videoColors.outlineVariant.withValues(alpha: 0.36),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.create_new_folder_outlined,
            size: 42,
            color: context.videoColors.primary,
          ),
          const SizedBox(height: 14),
          Text(
            l10n.videoNoLibrarySources,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.videoColors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              l10n.videoLocalLibrarySourcesSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.videoColors.onSurfaceVariant,
                height: 20 / 14,
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.videoAddLibrarySource),
          ),
        ],
      ),
    );
  }
}

class _MediaLibrarySourceNavigator extends StatelessWidget {
  const _MediaLibrarySourceNavigator({
    required this.sources,
    required this.selectedSourceId,
    required this.bounded,
    required this.onSelected,
  });

  final List<VideoLibrarySource> sources;
  final String selectedSourceId;
  final bool bounded;
  final ValueChanged<VideoLibrarySource> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final list = ListView.separated(
      key: const Key('mediaLibrarySourceNavigator'),
      shrinkWrap: !bounded,
      physics: bounded ? null : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: sources.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final source = sources[index];
        return _MediaLibrarySourceItem(
          source: source,
          selected: source.id == selectedSourceId,
          onTap: () => onSelected(source),
        );
      },
    );
    return Container(
      decoration: BoxDecoration(
        color: context.videoColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.videoColors.outlineVariant.withValues(alpha: 0.36),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.videoLibrarySourcesTitle,
                    style: TextStyle(
                      color: context.videoColors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  l10n.videoLibrarySourceCount(sources.length),
                  style: TextStyle(
                    color: context.videoColors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (bounded) Expanded(child: list) else list,
        ],
      ),
    );
  }
}

class _MediaLibrarySourceItem extends StatelessWidget {
  const _MediaLibrarySourceItem({
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final VideoLibrarySource source;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final offline = !source.enabled || source.healthStatus == 'OFFLINE';
    final issue = source.scanStatus == 'FAILED' || source.lastMissingCount > 0;
    final statusColor =
        offline || issue ? colorScheme.error : context.videoColors.primary;
    return Material(
      color:
          selected ? context.videoColors.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: Key('mediaLibrarySource-${source.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  offline
                      ? Icons.folder_off_outlined
                      : _libraryTypeIcon(source.libraryType),
                  size: 19,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            selected
                                ? context.videoColors.onPrimaryContainer
                                : context.videoColors.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _libraryTypeLabel(l10n, source.libraryType),
                      style: TextStyle(
                        color:
                            selected
                                ? context.videoColors.onPrimaryContainer
                                    .withValues(alpha: 0.78)
                                : context.videoColors.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _visibilityLabel(l10n, source.visibility),
                      style: TextStyle(
                        color:
                            selected
                                ? context.videoColors.onPrimaryContainer
                                    .withValues(alpha: 0.78)
                                : context.videoColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.videoSourceScanSummary(
                        source.lastScannedCount,
                        source.lastCandidateCount,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            selected
                                ? context.videoColors.onPrimaryContainer
                                    .withValues(alpha: 0.72)
                                : context.videoColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color:
                    selected
                        ? context.videoColors.onPrimaryContainer
                        : context.videoColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaLibrarySourceWorkspace extends StatelessWidget {
  const _MediaLibrarySourceWorkspace({
    required this.source,
    required this.locations,
    required this.bounded,
    required this.scanning,
    required this.onEdit,
    required this.onScan,
    required this.onDelete,
  });

  final VideoLibrarySource source;
  final List<VideoStorageLocation> locations;
  final bool bounded;
  final bool scanning;
  final VoidCallback onEdit;
  final VoidCallback onScan;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final duration =
        MediaQuery.maybeOf(context)?.disableAnimations == true
            ? Duration.zero
            : const Duration(milliseconds: 180);
    final body = _MediaLibraryWorkspaceBody(
      source: source,
      locations: locations,
      bounded: bounded,
    );
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: Material(
        key: ValueKey(source.id),
        color: context.videoColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: context.videoColors.outlineVariant.withValues(alpha: 0.36),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MediaLibrarySourceHeader(
              source: source,
              locations: locations,
              scanning: scanning,
              onEdit: onEdit,
              onScan: onScan,
              onDelete: onDelete,
            ),
            Divider(
              height: 1,
              color: context.videoColors.outlineVariant.withValues(alpha: 0.28),
            ),
            if (bounded) Expanded(child: body) else body,
          ],
        ),
      ),
    );
  }
}

class _MediaLibrarySourceHeader extends StatelessWidget {
  const _MediaLibrarySourceHeader({
    required this.source,
    required this.locations,
    required this.scanning,
    required this.onEdit,
    required this.onScan,
    required this.onDelete,
  });

  final VideoLibrarySource source;
  final List<VideoStorageLocation> locations;
  final bool scanning;
  final VoidCallback onEdit;
  final VoidCallback onScan;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final location = locations.cast<VideoStorageLocation?>().firstWhere(
      (item) => item?.id == source.storageLocationId,
      orElse: () => null,
    );
    final active =
        scanning ||
        const {'QUEUED', 'DISCOVERING', 'APPLYING'}.contains(source.scanStatus);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              source.name,
              style: TextStyle(
                color: context.videoColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            _SourceStatusBadge(source: source),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '${location?.name ?? l10n.videoUnknownStorageLocation} · ${source.relativeRoot}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.videoColors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _SourceMeta(
              icon: Icons.movie_filter_outlined,
              label: l10n.videoSourceScanSummary(
                source.lastScannedCount,
                source.lastCandidateCount,
              ),
            ),
            _SourceMeta(
              icon: Icons.group_outlined,
              label: _visibilityLabel(l10n, source.visibility),
            ),
            if (source.lastMissingCount > 0)
              _SourceMeta(
                icon: Icons.link_off_rounded,
                label: l10n.videoSourceMissingCount(source.lastMissingCount),
                issue: true,
              ),
          ],
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        IconButton(
          onPressed: scanning ? null : onDelete,
          tooltip: l10n.videoDeleteLibrarySource,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: Text(l10n.videoEditLibrarySource),
        ),
        FilledButton.icon(
          onPressed: source.enabled && !active ? onScan : null,
          icon:
              active
                  ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.manage_search_rounded),
          label: Text(l10n.videoScanThisSource),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [title, const SizedBox(height: 14), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _MediaLibraryWorkspaceBody extends StatefulWidget {
  const _MediaLibraryWorkspaceBody({
    required this.source,
    required this.locations,
    required this.bounded,
  });

  final VideoLibrarySource source;
  final List<VideoStorageLocation> locations;
  final bool bounded;

  @override
  State<_MediaLibraryWorkspaceBody> createState() =>
      _MediaLibraryWorkspaceBodyState();
}

class _MediaLibraryWorkspaceBodyState
    extends State<_MediaLibraryWorkspaceBody> {
  int _section = 0;

  @override
  void didUpdateWidget(covariant _MediaLibraryWorkspaceBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.id != widget.source.id) {
      _section = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selector = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: SegmentedButton<int>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment<int>(
            value: 0,
            icon: const Icon(Icons.info_outline_rounded),
            label: Text(l10n.videoLibraryOverviewTab),
          ),
          ButtonSegment<int>(
            value: 1,
            icon: const Icon(Icons.account_tree_outlined),
            label: Text(l10n.videoLibraryScanReviewTab),
          ),
          ButtonSegment<int>(
            value: 2,
            icon: const Icon(Icons.manage_accounts_outlined),
            label: Text(l10n.videoLibraryAccessTab),
          ),
        ],
        selected: {_section},
        onSelectionChanged: (value) => setState(() => _section = value.first),
      ),
    );
    final content = switch (_section) {
      0 => _MediaLibraryOverviewPanel(
        source: widget.source,
        locations: widget.locations,
      ),
      1 => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _MediaLibraryReviewWorkspace(source: widget.source),
      ),
      _ => _MediaLibraryAccessPanel(source: widget.source),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        selector,
        Divider(
          height: 1,
          color: context.videoColors.outlineVariant.withValues(alpha: 0.28),
        ),
        if (widget.bounded) Expanded(child: content) else content,
      ],
    );
  }
}

class _MediaLibraryOverviewPanel extends StatelessWidget {
  const _MediaLibraryOverviewPanel({
    required this.source,
    required this.locations,
  });

  final VideoLibrarySource source;
  final List<VideoStorageLocation> locations;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final location = locations.cast<VideoStorageLocation?>().firstWhere(
      (item) => item?.id == source.storageLocationId,
      orElse: () => null,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _OverviewRow(
            icon: Icons.storage_outlined,
            label: l10n.videoLibrarySourceLocationLabel,
            value: location?.name ?? l10n.videoUnknownStorageLocation,
          ),
          _OverviewRow(
            icon: Icons.folder_outlined,
            label: l10n.videoLibrarySourcePathLabel,
            value: source.relativeRoot,
          ),
          _OverviewRow(
            icon: _libraryTypeIcon(source.libraryType),
            label: l10n.videoLibrarySourceTypeLabel,
            value: _libraryTypeLabel(l10n, source.libraryType),
          ),
          _OverviewRow(
            icon: Icons.group_outlined,
            label: l10n.videoLibrarySourceVisibilityLabel,
            value: _visibilityLabel(l10n, source.visibility),
          ),
          _OverviewRow(
            icon: Icons.analytics_outlined,
            label: l10n.videoLibraryScanReviewTab,
            value: l10n.videoSourceScanSummary(
              source.lastScannedCount,
              source.lastCandidateCount,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: context.videoColors.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(
                color: context.videoColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(color: context.videoColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceMeta extends StatelessWidget {
  const _SourceMeta({
    required this.icon,
    required this.label,
    this.issue = false,
  });

  final IconData icon;
  final String label;
  final bool issue;

  @override
  Widget build(BuildContext context) {
    final color =
        issue
            ? Theme.of(context).colorScheme.error
            : context.videoColors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }
}

class _SourceStatusBadge extends StatelessWidget {
  const _SourceStatusBadge({required this.source});

  final VideoLibrarySource source;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final offline = !source.enabled || source.healthStatus == 'OFFLINE';
    final failed = source.scanStatus == 'FAILED';
    final foreground =
        offline || failed
            ? colorScheme.onErrorContainer
            : source.scanStatus == 'READY'
            ? colorScheme.onTertiaryContainer
            : colorScheme.onPrimaryContainer;
    final background =
        offline || failed
            ? colorScheme.errorContainer
            : source.scanStatus == 'READY'
            ? colorScheme.tertiaryContainer
            : colorScheme.primaryContainer;
    final label =
        offline
            ? source.enabled
                ? l10n.videoSourceOffline
                : l10n.videoSourceDisabled
            : _sourceStatusLabel(l10n, source.scanStatus);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

IconData _libraryTypeIcon(VideoLibraryType type) {
  return switch (type) {
    VideoLibraryType.movie => Icons.movie_outlined,
    VideoLibraryType.tvSeries => Icons.tv_outlined,
    VideoLibraryType.anime => Icons.animation_outlined,
    VideoLibraryType.root => Icons.account_tree_outlined,
  };
}

String _visibilityLabel(
  AppLocalizations l10n,
  MediaLibraryVisibility visibility,
) {
  return switch (visibility) {
    MediaLibraryVisibility.private => l10n.videoLibraryVisibilityPrivate,
    MediaLibraryVisibility.selectedUsers => l10n.videoLibraryVisibilitySelected,
    MediaLibraryVisibility.allMembers => l10n.videoLibraryVisibilityMembers,
  };
}

String _visibilityHint(
  AppLocalizations l10n,
  MediaLibraryVisibility visibility,
) {
  return switch (visibility) {
    MediaLibraryVisibility.private => l10n.videoLibraryVisibilityPrivateHint,
    MediaLibraryVisibility.selectedUsers =>
      l10n.videoLibraryVisibilitySelectedHint,
    MediaLibraryVisibility.allMembers => l10n.videoLibraryVisibilityMembersHint,
  };
}
