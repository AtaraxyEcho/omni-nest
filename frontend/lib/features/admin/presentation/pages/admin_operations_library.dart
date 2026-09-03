part of 'admin_operations_pages.dart';

// ── 媒体库管理段区 ──────────────────────────────────────────────────────

/// 视频库源分区：建立在已启用存储位置上的影视库源。
class _LibrarySourcesSection extends ConsumerStatefulWidget {
  const _LibrarySourcesSection({required this.canManage});

  final bool canManage;

  @override
  ConsumerState<_LibrarySourcesSection> createState() =>
      _LibrarySourcesSectionState();
}

class _LibrarySourcesSectionState
    extends ConsumerState<_LibrarySourcesSection> {
  /// 正在执行"发现更新"扫描的库源，用于行内按钮转圈与禁用。
  String? _scanningSourceId;

  bool get canManage => widget.canManage;

  Widget _buildAddButton(
    BuildContext context,
    AppLocalizations l10n,
    bool canAdd,
    List<VideoStorageLocation> locations,
  ) {
    final button = FilledButton.tonalIcon(
      onPressed:
          canAdd
              ? () => showDialog<void>(
                context: context,
                builder:
                    (dialogContext) => VideoLibrarySourceDialog(
                      source: null,
                      locations: locations,
                    ),
              )
              : null,
      icon: const Icon(Icons.add_rounded),
      label: Text(l10n.adminLibrarySourceAdd),
    );
    if (canAdd) {
      return button;
    }
    return Tooltip(
      message: l10n.videoNoAvailableStorageLocationHint,
      child: button,
    );
  }

  /// 触发库源"发现更新"扫描：入队后由后台任务继续展示真实进度。
  Future<void> _discoverUpdates(VideoLibrarySource source) async {
    if (_scanningSourceId != null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _scanningSourceId = source.id);
    try {
      final task = await ref
          .read(videoLibrarySourceActionsProvider)
          .scan(source.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(task.message)));
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminLoadFailed(error.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _scanningSourceId = null);
      }
    }
  }

  Future<void> _deleteSource(VideoLibrarySource source) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.adminLibraryDeleteSourceTitle),
            content: Text(l10n.adminLibraryDeleteSourceBody(source.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.adminCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.adminStorageDeleteAction),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(videoLibrarySourceActionsProvider).delete(source.id);
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminLoadFailed(error.toString()))),
        );
      }
    }
  }

  void _editSource(
    VideoLibrarySource source,
    List<VideoStorageLocation> locations,
  ) {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) =>
              VideoLibrarySourceDialog(source: source, locations: locations),
    );
  }

  /// 打开访问管理弹窗：可见性与授权用户。
  void _openAccessDialog(VideoLibrarySource source) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.adminLibraryAccessTitle),
            content: SizedBox(
              width: 420,
              child: MediaLibraryAccessPanel(source: source),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.coreClose),
              ),
            ],
          ),
    );
  }

  /// 打开审阅窗口：库源扫描候选的审阅工作台。
  void _openReviewWindow(VideoLibrarySource source) {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => Dialog(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 920,
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${AppLocalizations.of(context).videoSectionLibraryScan} · ${source.name}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: AppLocalizations.of(context).coreClose,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(child: MediaLibraryReviewWorkspace(source: source)),
                ],
              ),
            ),
          ),
    );
  }

  String _lastScanSummary(VideoLibrarySource source) {
    if (source.scanStatus == 'NEVER_SCANNED' ||
        (source.lastScannedCount == 0 &&
            source.lastCreatedCount == 0 &&
            source.lastCandidateCount == 0 &&
            source.lastMissingCount == 0)) {
      return '—';
    }
    return AppLocalizations.of(context).adminLibraryLastScanSummary(
      source.lastCandidateCount,
      source.lastCreatedCount,
      source.lastMissingCount,
    );
  }

  String _scanStatusLabel(AppLocalizations l10n, String status) {
    return switch (status) {
      'READY' => l10n.statusScanReady,
      'QUEUED' => l10n.statusScanQueued,
      'DISCOVERING' || 'SCANNING' => l10n.statusScanDiscovering,
      'FAILED' => l10n.statusScanFailed,
      'CANCELLED' => l10n.statusScanCancelled,
      'PAUSED' => l10n.statusScanPaused,
      'NEVER_SCANNED' => l10n.adminLibraryScanNever,
      _ => status,
    };
  }

  AdminTagTone _scanStatusTone(String status) {
    return switch (status) {
      'READY' => AdminTagTone.success,
      'DISCOVERING' || 'SCANNING' || 'QUEUED' => AdminTagTone.info,
      'FAILED' => AdminTagTone.error,
      'PAUSED' => AdminTagTone.warning,
      _ => AdminTagTone.neutral,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sourcesAsync = ref.watch(videoLibrarySourcesProvider);
    final locationsAsync = ref.watch(videoStorageLocationsProvider);
    final locations =
        locationsAsync.asData?.value ?? const <VideoStorageLocation>[];
    final sources = sourcesAsync.asData?.value ?? const <VideoLibrarySource>[];
    final canAdd = locations.any((location) => location.available);
    final query = ref.watch(adminSearchProvider).toLowerCase();
    final filtered =
        query.isEmpty
            ? sources
            : sources
                .where(
                  (source) =>
                      source.name.toLowerCase().contains(query) ||
                      source.relativeRoot.toLowerCase().contains(query),
                )
                .toList();
    String locationName(VideoLibrarySource source) =>
        locations
            .where((item) => item.id == source.storageLocationId)
            .firstOrNull
            ?.name ??
        source.storageLocationId;

    return AdminTableSection(
      title: l10n.adminLibrarySourcesSection,
      subtitle: l10n.adminLibrarySourcesSubtitle,
      trailing: [
        if (canManage) _buildAddButton(context, l10n, canAdd, locations),
      ],
      children: [
        AdminDataTable(
          showIndex: true,
          minTableWidth: 1080,
          rowCount: filtered.length,
          onRowTap: (index) => _openReviewWindow(filtered[index]),
          emptyState: AdminListEmptyState(
            message:
                query.isEmpty
                    ? l10n.adminLibrarySourcesEmpty
                    : l10n.adminNoMatch,
          ),
          columns: [
            AdminListColumn(key: 'name', label: l10n.adminUsername, flex: 2),
            AdminListColumn(
              key: 'location',
              label: l10n.adminLibraryColumnLocation,
              flex: 2,
            ),
            AdminListColumn(
              key: 'type',
              label: l10n.videoLibraryType,
              minWidth: 100,
            ),
            AdminListColumn(
              key: 'scanStatus',
              label: l10n.adminLibraryColumnScanStatus,
              minWidth: 110,
            ),
            AdminListColumn(
              key: 'lastScan',
              label: l10n.adminLibraryColumnLastScan,
              minWidth: 200,
            ),
            AdminListColumn(
              key: 'status',
              label: l10n.adminFilterStatus,
              minWidth: 90,
            ),
          ],
          rowCellsBuilder: (context, index) {
            final source = filtered[index];
            return [
              Text(
                source.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${locationName(source)} · ${source.relativeRoot}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                _libraryTypeLabel(l10n, source.libraryType),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              AdminStatusTag(
                label: _scanStatusLabel(l10n, source.scanStatus),
                tone: _scanStatusTone(source.scanStatus),
              ),
              Text(
                _lastScanSummary(source),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              AdminStatusTag(
                label:
                    source.enabled
                        ? l10n.adminStatusEnabled
                        : l10n.adminStatusDisabled,
                tone:
                    source.enabled
                        ? AdminTagTone.success
                        : AdminTagTone.neutral,
              ),
            ];
          },
          actionsBuilder: (context, index) {
            final source = filtered[index];
            final scanning = _scanningSourceId == source.id;
            return [
              IconButton(
                tooltip: l10n.adminLibraryDiscoverUpdates,
                icon:
                    scanning
                        ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.manage_search_rounded, size: 20),
                onPressed:
                    canManage && source.enabled && !scanning
                        ? () => _discoverUpdates(source)
                        : null,
              ),
              IconButton(
                tooltip: l10n.adminLibraryAccessTitle,
                icon: const Icon(Icons.people_outline_rounded, size: 20),
                onPressed: canManage ? () => _openAccessDialog(source) : null,
              ),
              IconButton(
                tooltip: l10n.videoEditLibrarySource,
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed:
                    canManage ? () => _editSource(source, locations) : null,
              ),
              IconButton(
                tooltip: l10n.adminLibraryDeleteSourceTitle,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                onPressed: canManage ? () => _deleteSource(source) : null,
              ),
            ];
          },
        ),
      ],
    );
  }
}

/// 扫描与审阅分区：选定库源后进入审阅工作区。

/// 库类型展示名。
String _libraryTypeLabel(AppLocalizations l10n, VideoLibraryType libraryType) {
  return switch (libraryType) {
    VideoLibraryType.movie => l10n.videoLibraryTypeMovie,
    VideoLibraryType.tvSeries => l10n.videoLibraryTypeTvSeries,
    VideoLibraryType.anime => l10n.videoLibraryTypeAnime,
    VideoLibraryType.root => l10n.videoLibraryTypeRoot,
  };
}
