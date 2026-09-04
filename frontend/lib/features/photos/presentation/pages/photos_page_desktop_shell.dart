part of 'photos_page.dart';

/// 桌面顶栏：返回、标题、搜索、视图切换、多选与关联视图入口。
class _PhotoDesktopTopBar extends ConsumerWidget {
  const _PhotoDesktopTopBar({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.photosColors;
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(photoCenterControllerProvider).asData?.value;
    final libraryView = state?.libraryView ?? PhotoLibraryView.gridDay;
    final isSelectionMode = state?.isSelectionMode ?? false;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go('/portal'),
            icon: Icon(
              Icons.arrow_back_rounded,
              size: 19,
              color: colors.onSurfaceVariant,
            ),
            tooltip: l10n.photosBackToPortal,
          ),
          const SizedBox(width: 6),
          Text(
            l10n.photosSurfaceLibrary,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    style: TextStyle(color: colors.onSurface, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: l10n.photosSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded, size: 19),
                      suffixIcon:
                          searchQuery.isEmpty
                              ? null
                              : IconButton(
                                tooltip: l10n.photosClear,
                                onPressed: () {
                                  searchController.clear();
                                  onSearchChanged('');
                                },
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                      filled: true,
                      fillColor: colors.surfaceContainerLow,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: colors.outlineVariant.withValues(alpha: 0.16),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: colors.outlineVariant.withValues(alpha: 0.16),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<PhotoLibraryView>(
            tooltip: l10n.photosViewSwitch,
            initialValue: libraryView,
            onSelected: (view) {
              ref
                  .read(photoCenterControllerProvider.notifier)
                  .setLibraryView(view);
            },
            itemBuilder:
                (context) => [
                  _viewMenuItem(
                    context,
                    PhotoLibraryView.gridDay,
                    Icons.grid_view_rounded,
                    l10n.photosViewGridDay,
                  ),
                  _viewMenuItem(
                    context,
                    PhotoLibraryView.gridMonth,
                    Icons.calendar_view_month_rounded,
                    l10n.photosViewGridMonth,
                  ),
                  _viewMenuItem(
                    context,
                    PhotoLibraryView.timeline,
                    Icons.timeline_rounded,
                    l10n.photosViewTimeline,
                  ),
                  _viewMenuItem(
                    context,
                    PhotoLibraryView.groups,
                    Icons.folder_copy_outlined,
                    l10n.photosViewGroups,
                  ),
                ],
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _viewIcon(libraryView),
                    size: 17,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _viewLabel(l10n, libraryView),
                    style: TextStyle(color: colors.onSurface, fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: l10n.photosToggleSelection,
            onPressed:
                () =>
                    ref
                        .read(photoCenterControllerProvider.notifier)
                        .toggleSelectionMode(),
            isSelected: isSelectionMode,
            icon: const Icon(Icons.checklist_rounded, size: 20),
            color: colors.onSurfaceVariant,
          ),
          IconButton(
            tooltip: l10n.photosInsightsTitle,
            onPressed: () => context.push('/photos/insights'),
            icon: const Icon(Icons.account_tree_rounded, size: 20),
            color: colors.onSurfaceVariant,
          ),
          const _RegenerateThumbnailsAction(),
          const SizedBox(width: 4),
          MediaImportButton(
            subsystemDirectory: 'Photos',
            acceptedExtensions: const <String>[
              'jpg',
              'jpeg',
              'png',
              'gif',
              'heic',
              'heif',
              'bmp',
              'tif',
              'tiff',
            ],
            unsupportedExtensions: const <String>[],
            onImportComplete: () {},
            onImportCompleteWithResult: (result) async {
              if (!context.mounted) return null;
              final controller = ref.read(
                photoCenterControllerProvider.notifier,
              );
              final visible = await controller.refreshAfterImport(
                expectedFileIds: result.imported.map((file) => file.fileNodeId),
                taskIds:
                    result.imported
                        .map((file) => file.mediaAutoImportTaskId)
                        .whereType<String>(),
              );
              if (!context.mounted) return null;
              final failure = controller.lastImportNotice;
              if (!visible && failure != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      photoImportNoticeText(
                        AppLocalizations.of(context),
                        failure,
                      ),
                    ),
                  ),
                );
                return MediaImportCompletionState.failed;
              }
              return visible
                  ? MediaImportCompletionState.completed
                  : MediaImportCompletionState.processing;
            },
            allowSharedSpace: false,
            reuseExistingFiles: true,
            style: ImportButtonStyle.iconButton,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          const NotificationIcon(size: 20),
          const SizedBox(width: 8),
          const UserAvatarMenu(),
        ],
      ),
    );
  }

  PopupMenuItem<PhotoLibraryView> _viewMenuItem(
    BuildContext context,
    PhotoLibraryView view,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem<PhotoLibraryView>(
      value: view,
      child: Row(
        children: [Icon(icon, size: 17), const SizedBox(width: 8), Text(label)],
      ),
    );
  }

  IconData _viewIcon(PhotoLibraryView view) {
    return switch (view) {
      PhotoLibraryView.gridDay => Icons.grid_view_rounded,
      PhotoLibraryView.gridMonth => Icons.calendar_view_month_rounded,
      PhotoLibraryView.timeline => Icons.timeline_rounded,
      PhotoLibraryView.groups => Icons.folder_copy_outlined,
    };
  }

  String _viewLabel(AppLocalizations l10n, PhotoLibraryView view) {
    return switch (view) {
      PhotoLibraryView.gridDay => l10n.photosViewGridDay,
      PhotoLibraryView.gridMonth => l10n.photosViewGridMonth,
      PhotoLibraryView.timeline => l10n.photosViewTimeline,
      PhotoLibraryView.groups => l10n.photosViewGroups,
    };
  }
}
