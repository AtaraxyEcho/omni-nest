part of 'admin_operations_pages.dart';

// ── 媒体库管理段区 ──────────────────────────────────────────────────────

/// 视频库源分区：建立在已启用存储位置上的影视库源。
/// 上次扫描摘要：从未扫描或全零时显示占位符。
String _lastScanSummary(AppLocalizations l10n, VideoLibrarySource source) {
  if (source.scanStatus == 'NEVER_SCANNED' ||
      (source.lastScannedCount == 0 &&
          source.lastCreatedCount == 0 &&
          source.lastCandidateCount == 0 &&
          source.lastMissingCount == 0)) {
    return '—';
  }
  return l10n.adminLibraryLastScanSummary(
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

  /// 当前展开的库源（父子嵌套列表的单开语义）。
  String? _expandedSourceId;

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
        if (filtered.isEmpty)
          AdminListEmptyState(
            message:
                query.isEmpty
                    ? l10n.adminLibrarySourcesEmpty
                    : l10n.adminNoMatch,
          )
        else
          for (final source in filtered)
            _LibrarySourceBlock(
              source: source,
              locationName: locationName(source),
              expanded: _expandedSourceId == source.id,
              scanning: _scanningSourceId == source.id,
              canManage: canManage,
              onToggle:
                  () => setState(() {
                    _expandedSourceId =
                        _expandedSourceId == source.id ? null : source.id;
                  }),
              onDiscover: () => _discoverUpdates(source),
              onAccess: () => _openAccessDialog(source),
              onEdit: () => _editSource(source, locations),
              onDelete: () => _deleteSource(source),
            ),
      ],
    );
  }
}

/// 库源父子嵌套块：父行为摘要行，点击展开嵌套的审阅工作区与操作区。
class _LibrarySourceBlock extends StatelessWidget {
  const _LibrarySourceBlock({
    required this.source,
    required this.locationName,
    required this.expanded,
    required this.scanning,
    required this.canManage,
    required this.onToggle,
    required this.onDiscover,
    required this.onAccess,
    required this.onEdit,
    required this.onDelete,
  });

  final VideoLibrarySource source;
  final String locationName;
  final bool expanded;
  final bool scanning;
  final bool canManage;
  final VoidCallback onToggle;
  final VoidCallback onDiscover;
  final VoidCallback onAccess;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      source.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AdminStatusTag(
                    label: _scanStatusLabel(l10n, source.scanStatus),
                    tone: _scanStatusTone(source.scanStatus),
                  ),
                  const SizedBox(width: 10),
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
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(40, 12, 16, 16),
              color: colors.surfaceContainerLow.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.videoLibraryType}：${_libraryTypeLabel(l10n, source.libraryType)} · $locationName · ${source.relativeRoot}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _lastScanSummary(l10n, source),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      scanning
                          ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : FilledButton.tonalIcon(
                            onPressed: source.enabled ? onDiscover : null,
                            icon: const Icon(
                              Icons.manage_search_rounded,
                              size: 18,
                            ),
                            label: Text(l10n.adminLibraryDiscoverUpdates),
                          ),
                      OutlinedButton.icon(
                        onPressed: onAccess,
                        icon: const Icon(
                          Icons.people_outline_rounded,
                          size: 18,
                        ),
                        label: Text(l10n.adminLibraryAccessTitle),
                      ),
                      OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(l10n.videoEditLibrarySource),
                      ),
                      IconButton(
                        tooltip: l10n.adminLibraryDeleteSourceTitle,
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  MediaLibraryReviewWorkspace(source: source),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 库类型展示名。
String _libraryTypeLabel(AppLocalizations l10n, VideoLibraryType libraryType) {
  return switch (libraryType) {
    VideoLibraryType.movie => l10n.videoLibraryTypeMovie,
    VideoLibraryType.tvSeries => l10n.videoLibraryTypeTvSeries,
    VideoLibraryType.anime => l10n.videoLibraryTypeAnime,
    VideoLibraryType.root => l10n.videoLibraryTypeRoot,
  };
}
