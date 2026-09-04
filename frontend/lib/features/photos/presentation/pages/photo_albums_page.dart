import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/photos_colors.dart';
import 'package:omninest/core/errors/error_message.dart';
import 'package:omninest/core/widgets/app_error_view.dart';
import 'package:omninest/core/widgets/app_loading.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_album_grid.dart';

/// 相册管理页：从图库货架的"展开/管理"进入，集中浏览、新建与整理相册。
class PhotoAlbumsPage extends ConsumerWidget {
  const PhotoAlbumsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(photoCenterControllerProvider);
    final colors = context.photosColors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(AppLocalizations.of(context).photosAlbums),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateAlbumDialog(context, ref),
        tooltip: AppLocalizations.of(context).photosNewAlbum,
        child: const Icon(Icons.add_rounded),
      ),
      body: stateAsync.when(
        data:
            (state) => Padding(
              padding: const EdgeInsets.all(16),
              child: PhotoAlbumGrid(
                albums: state.albums,
                onOpenAlbum:
                    (album) => context.push('/photos/albums/${album.id}'),
                onDeleteAlbum: (album) async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder:
                        (dialogContext) => AlertDialog(
                          title: Text(
                            AppLocalizations.of(context).photosDeleteAlbumTitle,
                          ),
                          content: Text(
                            AppLocalizations.of(
                              context,
                            ).photosDeleteAlbumConfirm(album.name),
                          ),
                          actions: [
                            TextButton(
                              onPressed:
                                  () => Navigator.pop(dialogContext, false),
                              child: Text(
                                AppLocalizations.of(context).photosCancel,
                              ),
                            ),
                            FilledButton(
                              onPressed:
                                  () => Navigator.pop(dialogContext, true),
                              child: Text(
                                AppLocalizations.of(context).photosDelete,
                              ),
                            ),
                          ],
                        ),
                  );
                  if (confirmed == true) {
                    await ref
                        .read(photoCenterControllerProvider.notifier)
                        .deleteAlbum(album.id);
                  }
                },
                onCreateAlbum: () => _showCreateAlbumDialog(context, ref),
              ),
            ),
        error:
            (error, stackTrace) => AppErrorView(
              message: describeUserFacingError(error).displayMessage,
              onRetry: () => ref.invalidate(photoCenterControllerProvider),
            ),
        loading: () => const AppLoading.grid(),
      ),
    );
  }

  Future<void> _showCreateAlbumDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(AppLocalizations.of(context).photosNewAlbum),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).photosAlbumName,
                    hintText: AppLocalizations.of(context).photosAlbumNameHint,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText:
                        AppLocalizations.of(context).photosAlbumDescription,
                    hintText:
                        AppLocalizations.of(context).photosAlbumDescriptionHint,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(AppLocalizations.of(context).photosCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(AppLocalizations.of(context).photosCreate),
              ),
            ],
          ),
    );
    final name = nameController.text.trim();
    if (confirmed != true || name.isEmpty) return;
    try {
      await ref
          .read(photoCenterControllerProvider.notifier)
          .createAlbum(
            name: name,
            description: descriptionController.text.trim(),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).photosAlbumCreated(name),
            ),
          ),
        );
      }
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).photosCreateFailed),
          ),
        );
      }
    }
  }
}
