part of 'admin_operations_pages.dart';

// ── 媒体库管理段区 ──────────────────────────────────────────────────────

/// 视频库源分区：建立在已启用存储位置上的影视库源。
class _LibrarySourcesSection extends ConsumerWidget {
  const _LibrarySourcesSection({
    required this.canManage,
    required this.onSourceSelected,
    required this.selectedSourceId,
  });

  final bool canManage;
  final ValueChanged<String> onSourceSelected;
  final String? selectedSourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sourcesAsync = ref.watch(videoLibrarySourcesProvider);
    final locationsAsync = ref.watch(videoStorageLocationsProvider);
    final locations =
        locationsAsync.asData?.value ?? const <VideoStorageLocation>[];
    final sources = sourcesAsync.asData?.value ?? const <VideoLibrarySource>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.adminLibrarySourcesSection,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (canManage)
              FilledButton.tonalIcon(
                onPressed:
                    () => showDialog<void>(
                      context: context,
                      builder:
                          (dialogContext) => VideoLibrarySourceDialog(
                            source: null,
                            locations: locations,
                          ),
                    ),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.adminLibrarySourceAdd),
              ),
          ],
        ),
        const SizedBox(height: 12),
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
                  onTap: () => onSourceSelected(source.id),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.videoSectionLibraryScan,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (sources.isEmpty)
          Text(
            l10n.adminLibrarySourcesEmpty,
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else ...[
          DropdownButtonFormField<String>(
            initialValue: selectedSourceId,
            items: [
              for (final source in sources)
                DropdownMenuItem(value: source.id, child: Text(source.name)),
            ],
            onChanged: (value) {
              if (value != null) {
                onSelectSource(value);
              }
            },
            decoration: InputDecoration(
              labelText: l10n.videoStorageLocation,
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          if (selected != null) MediaLibraryReviewWorkspace(source: selected),
        ],
      ],
    );
  }
}
