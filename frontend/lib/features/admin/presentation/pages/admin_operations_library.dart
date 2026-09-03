part of 'admin_operations_pages.dart';

// ── 媒体库管理段区 ──────────────────────────────────────────────────────

/// 视频库源分区：建立在已启用存储位置上的影视库源。
class _LibrarySourcesSection extends ConsumerStatefulWidget {
  const _LibrarySourcesSection({
    required this.canManage,
    required this.onSourceSelected,
    required this.selectedSourceId,
  });

  final bool canManage;
  final ValueChanged<String> onSourceSelected;
  final String? selectedSourceId;

  @override
  ConsumerState<_LibrarySourcesSection> createState() =>
      _LibrarySourcesSectionState();
}

class _LibrarySourcesSectionState
    extends ConsumerState<_LibrarySourcesSection> {
  /// 正在执行"发现更新"扫描的库源，用于行内按钮转圈与禁用。
  String? _scanningSourceId;

  bool get canManage => widget.canManage;
  String? get selectedSourceId => widget.selectedSourceId;

  void _handleSourceSelected(String id) => widget.onSourceSelected(id);

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sourcesAsync = ref.watch(videoLibrarySourcesProvider);
    final locationsAsync = ref.watch(videoStorageLocationsProvider);
    final locations =
        locationsAsync.asData?.value ?? const <VideoStorageLocation>[];
    final sources = sourcesAsync.asData?.value ?? const <VideoLibrarySource>[];
    final canAdd = locations.any((location) => location.available);

    return AdminInfoPanel(
      title: l10n.adminLibrarySourcesSection,
      subtitle: l10n.adminLibrarySourcesSubtitle,
      trailing:
          canManage ? _buildAddButton(context, l10n, canAdd, locations) : null,
      children: [
        if (sources.isEmpty)
          Row(
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.adminLibrarySourcesEmpty,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          )
        else
          ...sources.map((source) {
            final location =
                locations
                    .where((item) => item.id == source.storageLocationId)
                    .firstOrNull;
            final selected = source.id == selectedSourceId;
            final colors = Theme.of(context).colorScheme;
            final accessPanel =
                selected && canManage
                    ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: MediaLibraryAccessPanel(source: source),
                    )
                    : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () => _handleSourceSelected(source.id),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color:
                          selected
                              ? colors.surfaceContainerHighest
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color:
                              source.enabled
                                  ? Colors.green.shade600
                                  : colors.outline,
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
                          flex: 4,
                          child: Text(
                            '${location?.name ?? source.storageLocationId} · ${source.relativeRoot}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          source.enabled
                              ? l10n.adminStorageStatusHealthy
                              : l10n.adminStorageStatusDisabled,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        if (canManage && source.enabled) ...[
                          const SizedBox(width: 8),
                          _scanningSourceId == source.id
                              ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : IconButton(
                                tooltip: l10n.adminLibraryDiscoverUpdates,
                                icon: const Icon(
                                  Icons.manage_search_rounded,
                                  size: 20,
                                ),
                                onPressed: () => _discoverUpdates(source),
                              ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (accessPanel != null) accessPanel,
              ],
            );
          }),
      ],
    );
  }
}

/// 扫描与审阅分区：选定库源后进入审阅工作区。
class _LibraryReviewSection extends ConsumerWidget {
  const _LibraryReviewSection({
    required this.sources,
    required this.selectedSourceId,
    required this.onSelectSource,
  });

  final List<VideoLibrarySource> sources;
  final String? selectedSourceId;
  final ValueChanged<String> onSelectSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected =
        sources.where((source) => source.id == selectedSourceId).firstOrNull;
    final validSelection =
        selectedSourceId != null &&
        sources.any((source) => source.id == selectedSourceId);
    return AdminInfoPanel(
      title: l10n.videoSectionLibraryScan,
      subtitle: l10n.adminLibraryReviewSubtitle,
      children: [
        if (sources.isEmpty)
          Row(
            children: [
              Icon(
                Icons.manage_search_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.adminLibrarySourcesEmpty,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          )
        else ...[
          SizedBox(
            width: 320,
            child: AppDropdown<String>(
              value: validSelection ? selectedSourceId! : '',
              label: l10n.videoSelectLibrarySource,
              items: [
                for (final source in sources)
                  AppDropdownItem(value: source.id, label: source.name),
              ],
              onChanged: (value) {
                if (value != null) {
                  onSelectSource(value);
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          if (selected != null) MediaLibraryReviewWorkspace(source: selected),
        ],
      ],
    );
  }
}
