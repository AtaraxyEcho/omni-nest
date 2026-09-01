part of 'photos_page.dart';

class _BatchActionBar extends StatelessWidget {
  const _BatchActionBar({required this.state, required this.ref});

  final PhotoCenterState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: context.photosColors.surfaceContainerHigh,
        border: Border(
          top: BorderSide(
            color: context.photosColors.outlineVariant.withValues(alpha: 0.32),
          ),
        ),
      ),
      child: Row(
        children: [
          // 取消选择
          IconButton(
            tooltip: AppLocalizations.of(context).photosDeselect,
            onPressed: () {
              ref
                  .read(photoCenterControllerProvider.notifier)
                  .toggleSelectionMode();
            },
            icon: Icon(
              Icons.close_rounded,
              color: context.photosColors.onSurfaceVariant,
              size: 20,
            ),
          ),
          SizedBox(width: 8),
          Text(
            AppLocalizations.of(
              context,
            ).photosSelectedCount(state.selectedPhotoIds.length),
            style: TextStyle(
              color: context.photosColors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // 批量标签
          _BatchAction(
            icon: Icons.label_outline,
            label: AppLocalizations.of(context).photosTag,
            onTap: () => _showBatchTagDialog(context),
          ),
          const SizedBox(width: 8),
          // 批量移动到相册
          _BatchAction(
            icon: Icons.photo_album_outlined,
            label: AppLocalizations.of(context).photosMove,
            onTap: () => _showBatchMoveDialog(context),
          ),
          const SizedBox(width: 8),
          _BatchAction(
            icon: Icons.archive_outlined,
            label: AppLocalizations.of(context).photosExportZip,
            onTap: () => _startBatchDownload(context),
          ),
          const SizedBox(width: 8),
          // 批量删除
          _BatchAction(
            icon: Icons.delete_outline,
            label: AppLocalizations.of(context).photosDelete,
            isDestructive: true,
            onTap: () => _confirmBatchDelete(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showBatchTagDialog(BuildContext context) async {
    final tag = await showDialog<String>(
      context: context,
      builder:
          (ctx) => PhotoDialogTextField(
            builder:
                (ctx, tagController) => AlertDialog(
                  backgroundColor: context.photosColors.surfaceContainerHigh,
                  title: Text(
                    AppLocalizations.of(context).photosBatchAddTag,
                    style: TextStyle(color: context.photosColors.onSurface),
                  ),
                  content: TextField(
                    controller: tagController,
                    autofocus: true,
                    style: TextStyle(color: context.photosColors.onSurface),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).photosTagName,
                      hintText: AppLocalizations.of(context).photosTagNameHint,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(AppLocalizations.of(context).photosCancel),
                    ),
                    FilledButton(
                      onPressed:
                          () => Navigator.pop(ctx, tagController.text.trim()),
                      child: Text(AppLocalizations.of(context).photosAdd),
                    ),
                  ],
                ),
          ),
    );
    if (tag != null && tag.trim().isNotEmpty && context.mounted) {
      try {
        final task = await ref
            .read(photoCenterControllerProvider.notifier)
            .createBatchTask(taskType: 'TAG', params: {'tag': tag});
        if (context.mounted) {
          _showProgressDialog(context, task.id);
        }
      } on Exception {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).photosTaskCreateFailed,
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _showBatchMoveDialog(BuildContext context) async {
    final albums =
        await ref.read(photoCenterControllerProvider.notifier).listAlbums();
    if (!context.mounted) return;
    final selected = await showDialog<String>(
      context: context,
      builder:
          (ctx) => SimpleDialog(
            backgroundColor: context.photosColors.surfaceContainerHigh,
            title: Text(
              AppLocalizations.of(context).photosSelectAlbum,
              style: TextStyle(color: context.photosColors.onSurface),
            ),
            children:
                albums
                    .map(
                      (album) => SimpleDialogOption(
                        onPressed: () => Navigator.pop(ctx, album.id),
                        child: Text(
                          album.name,
                          style: TextStyle(
                            color: context.photosColors.onSurface,
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
    );
    if (selected != null && context.mounted) {
      try {
        final task = await ref
            .read(photoCenterControllerProvider.notifier)
            .createBatchTask(taskType: 'MOVE', params: {'albumId': selected});
        if (context.mounted) {
          _showProgressDialog(context, task.id);
        }
      } on Exception {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).photosTaskCreateFailed,
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmBatchDelete(BuildContext context) async {
    final count = state.selectedPhotoIds.length;
    final photoIds = state.selectedPhotoIds.toList(growable: false);
    final confirmed = await confirmAndRunFilePurge(
      context,
      resourceName: AppLocalizations.of(context).photosSelectedCount(count),
      action: (cascade) async {
        await ref
            .read(photoCenterControllerProvider.notifier)
            .deletePhotos(photoIds, cascade: cascade);
      },
    );
    if (confirmed == true && context.mounted) {
      ref.read(photoCenterControllerProvider.notifier).toggleSelectionMode();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).photosBatchDeleted(count),
            ),
          ),
        );
      }
    }
  }

  Future<void> _startBatchDownload(BuildContext context) async {
    try {
      final task = await ref
          .read(photoCenterControllerProvider.notifier)
          .createBatchTask(taskType: 'DOWNLOAD');
      if (context.mounted) {
        _showProgressDialog(context, task.id);
      }
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).photosTaskCreateFailed),
          ),
        );
      }
    }
  }

  void _showProgressDialog(BuildContext context, String taskId) {
    ref.read(photoCenterControllerProvider.notifier).toggleSelectionMode();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BatchProgressDialog(taskId: taskId),
    );
  }
}

class _BatchAction extends StatelessWidget {
  const _BatchAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color:
                    isDestructive
                        ? context.photosColors.danger
                        : context.photosColors.onSurfaceVariant,
                size: 18,
              ),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color:
                      isDestructive
                          ? context.photosColors.danger
                          : context.photosColors.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
