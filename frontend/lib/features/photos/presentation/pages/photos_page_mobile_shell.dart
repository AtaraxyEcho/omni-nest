part of 'photos_page.dart';

class _PhotoMobileSectionBar extends StatelessWidget {
  const _PhotoMobileSectionBar({
    required this.currentTab,
    required this.onTabChanged,
  });

  final PhotoTab currentTab;
  final ValueChanged<PhotoTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const tabs = <PhotoTab>[
      PhotoTab.all,
      PhotoTab.timeline,
      PhotoTab.albums,
      PhotoTab.people,
      PhotoTab.graph,
    ];
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          return ChoiceChip(
            selected: currentTab == tab,
            showCheckmark: false,
            onSelected: (_) => onTabChanged(tab),
            label: Text(switch (tab) {
              PhotoTab.all => l10n.photosTabHome,
              PhotoTab.timeline => l10n.photosTabTimeline,
              PhotoTab.albums => l10n.photosTabAlbums,
              PhotoTab.people => l10n.photosTabPeople,
              PhotoTab.graph => l10n.photosTabGraph,
              _ => l10n.photosAll,
            }),
          );
        },
      ),
    );
  }
}

class _PhotoTopBar extends StatelessWidget {
  const _PhotoTopBar({
    required this.controller,
    required this.ref,
    required this.currentTab,
  });

  final TextEditingController controller;
  final WidgetRef ref;
  final PhotoTab currentTab;

  @override
  Widget build(BuildContext context) {
    return WorkbenchTopBar(
      surfaceColor: context.photosColors.surface,
      borderColor: context.photosColors.outlineVariant,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            // 返回箭头
            IconButton(
              onPressed: () => context.go('/portal'),
              icon: Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: context.photosColors.onSurfaceVariant,
              ),
              tooltip: AppLocalizations.of(context).photosBackToPortal,
            ),
            const SizedBox(width: 8),
            // 标题
            Text(
              switch (currentTab) {
                PhotoTab.all => AppLocalizations.of(context).photosTabHome,
                PhotoTab.favorites =>
                  AppLocalizations.of(context).photosTabFavorites,
                PhotoTab.timeline =>
                  AppLocalizations.of(context).photosTabTimeline,
                PhotoTab.graph => AppLocalizations.of(context).photosTabGraph,
                PhotoTab.albums => AppLocalizations.of(context).photosTabAlbums,
                _ => AppLocalizations.of(context).portalPhotos,
              },
              style: TextStyle(
                color: context.photosColors.primaryContainer,
                fontSize: 18,
                height: 24 / 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            // 导入文件
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
                  expectedFileIds: result.imported.map(
                    (file) => file.fileNodeId,
                  ),
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
              color: context.photosColors.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            // 搜索图标
            IconButton(
              tooltip: AppLocalizations.of(context).photosSearchPhotos,
              onPressed: () => _showSearchDialog(context),
              icon: Icon(
                Icons.search_rounded,
                color: context.photosColors.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 4),
            const _RegenerateThumbnailsAction(),
            const SizedBox(width: 4),
            const NotificationIcon(size: 20),
            const SizedBox(width: 8),
            const UserAvatarMenu(size: 28),
          ],
        ),
      ),
    );
  }

  /// 窄屏搜索弹窗
  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => PhotoDialogTextField(
            initialText: controller.text,
            builder:
                (ctx, dialogController) => AlertDialog(
                  backgroundColor: context.photosColors.surfaceContainerHigh,
                  title: Text(
                    AppLocalizations.of(context).photosSearchPhotos,
                    style: TextStyle(color: context.photosColors.onSurface),
                  ),
                  content: TextField(
                    controller: dialogController,
                    autofocus: true,
                    style: TextStyle(
                      color: context.photosColors.onSurface,
                      fontSize: 14,
                    ),
                    onChanged: (v) {
                      controller.text = v;
                      ref
                          .read(photoCenterControllerProvider.notifier)
                          .setSearchQuery(v);
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: context.photosColors.surfaceContainer,
                      hintText: AppLocalizations.of(context).photosSearchHint,
                      hintStyle: TextStyle(
                        color: context.photosColors.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: context.photosColors.onSurfaceVariant,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: context.photosColors.primaryContainer
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        controller.clear();
                        ref
                            .read(photoCenterControllerProvider.notifier)
                            .setSearchQuery('');
                        Navigator.pop(ctx);
                      },
                      child: Text(AppLocalizations.of(context).photosClear),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(AppLocalizations.of(context).photosSearch),
                    ),
                  ],
                ),
          ),
    );
  }
}

/// 重建缩略图入口：自持提交状态，避免连续点击叠加任务。
class _RegenerateThumbnailsAction extends ConsumerStatefulWidget {
  const _RegenerateThumbnailsAction();

  @override
  ConsumerState<_RegenerateThumbnailsAction> createState() =>
      _RegenerateThumbnailsActionState();
}

class _RegenerateThumbnailsActionState
    extends ConsumerState<_RegenerateThumbnailsAction> {
  bool _submitting = false;

  Future<void> _handleRegenerateThumbnails() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(photoCenterControllerProvider.notifier)
          .regenerateThumbnails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).photoRegenerateQueued),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(describeUserFacingError(error).displayMessage),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 重建缩略图为照片管理操作，无 photo:admin 权限时隐藏入口。
    final canRegenerate =
        ref
            .watch(authSessionProvider)
            .asData
            ?.value
            .user
            ?.permissions
            .contains('photo:admin') ??
        false;
    if (!canRegenerate) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: AppLocalizations.of(context).photoRegenerateThumbnails,
      onPressed: _submitting ? null : _handleRegenerateThumbnails,
      icon:
          _submitting
              ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.photosColors.onSurfaceVariant,
                ),
              )
              : Icon(
                Icons.burst_mode_outlined,
                color: context.photosColors.onSurfaceVariant,
                size: 20,
              ),
    );
  }
}
