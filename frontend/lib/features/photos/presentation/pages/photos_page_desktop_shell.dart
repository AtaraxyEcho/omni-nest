part of 'photos_page.dart';

class _PhotoDesktopTopBar extends ConsumerWidget {
  const _PhotoDesktopTopBar({
    required this.currentTab,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  final PhotoTab currentTab;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.photosColors;
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
            tooltip: AppLocalizations.of(context).photosBackToPortal,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 170,
            child: Text(
              _desktopNavLabel(context, currentTab),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
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
                    enabled:
                        currentTab == PhotoTab.all ||
                        currentTab == PhotoTab.favorites ||
                        currentTab == PhotoTab.galaxy,
                    onChanged: onSearchChanged,
                    style: TextStyle(color: colors.onSurface, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).photosSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded, size: 19),
                      suffixIcon:
                          searchQuery.isEmpty
                              ? null
                              : IconButton(
                                tooltip:
                                    AppLocalizations.of(context).photosClear,
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
          IconButton(
            tooltip: AppLocalizations.of(context).photoRegenerateThumbnails,
            onPressed: () => _handleRegenerateThumbnails(context, ref),
            icon: Icon(
              Icons.burst_mode_outlined,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
          ),
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
              final failure = controller.lastImportFailureMessage;
              if (!visible && failure != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(failure)));
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
}

const List<(IconData, PhotoTab)> _desktopNavEntries = [
  (Icons.photo_library_outlined, PhotoTab.all),
  (Icons.auto_awesome_motion_outlined, PhotoTab.albums),
  (Icons.favorite_outline, PhotoTab.favorites),
  (Icons.auto_awesome_outlined, PhotoTab.timeline),
  (Icons.category_outlined, PhotoTab.groups),
  (Icons.people_outline, PhotoTab.people),
  (Icons.auto_awesome_outlined, PhotoTab.galaxy),
];

String _desktopNavLabel(BuildContext context, PhotoTab tab) {
  final l10n = AppLocalizations.of(context);
  return switch (tab) {
    PhotoTab.all => l10n.photosAllPhotos,
    PhotoTab.albums => l10n.photosTabAlbums,
    PhotoTab.favorites => l10n.photosTabFavorites,
    PhotoTab.timeline => l10n.photosTabMemories,
    PhotoTab.people => l10n.photosTabPeople,
    PhotoTab.galaxy => l10n.photosTabGalaxy,
    PhotoTab.groups => l10n.photosTabGroups,
  };
}

class _PhotoDesktopSidebar extends StatelessWidget {
  const _PhotoDesktopSidebar({
    required this.currentTab,
    required this.onTabChanged,
  });

  final PhotoTab currentTab;
  final ValueChanged<PhotoTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.photosColors;
    return Container(
      width: 216,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 24),
        children: [
          for (final entry in _desktopNavEntries) ...[
            _DesktopNavTab(
              label: _desktopNavLabel(context, entry.$2),
              icon: entry.$1,
              isActive: currentTab == entry.$2,
              onTap: () => onTabChanged(entry.$2),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _DesktopNavTab extends StatelessWidget {
  const _DesktopNavTab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.photosColors;
    final color =
        isActive ? colors.onPrimaryContainer : colors.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        hoverColor: colors.onSurfaceVariant.withValues(alpha: 0.06),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isActive ? colors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border(
              left: BorderSide(
                color: isActive ? colors.primaryContainer : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoFunctionBar extends StatelessWidget {
  const _PhotoFunctionBar({
    required this.currentTab,
    required this.onTabChanged,
  });

  final PhotoTab currentTab;
  final ValueChanged<PhotoTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          // "全部"胶囊 — 后续用户标签在此动态扩展
          GestureDetector(
            onTap: () => onTabChanged(PhotoTab.all),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: context.photosColors.primaryContainer,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: context.photosColors.primaryContainer,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 16,
                    color: context.photosColors.onPrimaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context).photosAll,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.photosColors.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 可滚动内容区（全部/收藏/相册 tab）— 用于 SingleChildScrollView 内部
