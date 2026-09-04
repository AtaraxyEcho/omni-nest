import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/photos_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/core/auth/auth_controller.dart';
import 'package:omninest/core/errors/error_message.dart';
import 'package:omninest/core/widgets/workbench_top_bar.dart';
import 'package:omninest/core/widgets/mobile_shell_scope.dart';
import 'package:omninest/core/widgets/mobile_ui.dart';
import 'package:omninest/features/files/media_import_ui.dart';
import 'package:omninest/features/files/application/media_import_service.dart';
import 'package:omninest/features/notifications/notification_ui.dart';
import 'package:omninest/core/widgets/responsive_breakpoints.dart';
import 'package:omninest/core/widgets/user_avatar_menu.dart';
import 'package:omninest/core/widgets/app_error_view.dart';
import 'package:omninest/core/widgets/app_loading.dart';
import 'package:omninest/core/widgets/file_purge_confirmation.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/domain/photo_album.dart';
import 'package:omninest/features/photos/presentation/widgets/batch_progress_dialog.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_album_card.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_group_view.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_timeline_view.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_common_widgets.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_date_grid.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_album_grid.dart';
import 'package:cached_network_image/cached_network_image.dart';

part 'photos_page_batch_actions.dart';
part 'photos_page_desktop_content.dart';
part 'photos_page_desktop_shell.dart';
part 'photos_page_mobile_content.dart';
part 'photos_page_mobile_shell.dart';

/// 照片中心主页
class PhotosPage extends ConsumerStatefulWidget {
  const PhotosPage({super.key});

  @override
  ConsumerState<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends ConsumerState<PhotosPage> {
  final TextEditingController _searchController = TextEditingController();
  VoidCallback? _routeListener;
  GoRouter? _router;
  DateTime _lastRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = GoRouter.of(context);
      _router = router;
      void listener() {
        final path = router.routeInformationProvider.value.uri.path;
        if (path == '/photos' && mounted) {
          final now = DateTime.now();
          if (now.difference(_lastRefresh).inMilliseconds > 500) {
            _lastRefresh = now;
            ref.read(photoCenterControllerProvider.notifier).refresh();
          }
        }
      }

      _routeListener = listener;
      router.routeInformationProvider.addListener(listener);
    });
  }

  @override
  void dispose() {
    if (_routeListener != null && _router != null) {
      _router!.routeInformationProvider.removeListener(_routeListener!);
    }
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hosted = MobileShellScope.isHosted(context);
    final stateAsync = ref.watch(photoCenterControllerProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide =
            !hosted && !ResponsiveBreakpoints.isCompact(constraints.maxWidth);
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            context.go('/portal');
          },
          child: Scaffold(
            backgroundColor:
                hosted ? Colors.transparent : context.photosColors.surface,
            body:
                isWide
                    ? _buildWideLayout(stateAsync)
                    : _buildNarrowLayout(stateAsync, hosted: hosted),
          ),
        );
      },
    );
  }

  /// 桌面宽屏布局：顶栏 + 图库内容，无侧栏。
  Widget _buildWideLayout(AsyncValue<PhotoCenterState> stateAsync) {
    return Column(
      children: [
        _PhotoDesktopTopBar(
          searchController: _searchController,
          searchQuery: stateAsync.asData?.value.searchQuery ?? '',
          onSearchChanged:
              ref.read(photoCenterControllerProvider.notifier).setSearchQuery,
        ),
        Expanded(
          child: ColoredBox(
            color: context.photosColors.surface,
            child: stateAsync.when(
              data:
                  (data) => _PhotoContent(
                    state: data,
                    onOpenPhoto: (photo) => context.push('/photos/${photo.id}'),
                    onOpenAlbum:
                        (album) => context.push('/photos/albums/${album.id}'),
                    onDeletePhoto:
                        (photo) => _confirmDeletePhoto(context, photo),
                    onDeleteAlbum:
                        (album) => _confirmDeleteAlbum(context, album),
                    onCreateAlbum: () => _showCreateAlbumDialog(context),
                  ),
              error:
                  (error, stackTrace) => AppErrorView(
                    message: describeUserFacingError(error).displayMessage,
                    onRetry:
                        () => ref.invalidate(photoCenterControllerProvider),
                  ),
              loading: () => const AppLoading.grid(),
            ),
          ),
        ),
      ],
    );
  }

  /// 移动端窄屏布局：全局顶栏 + 图库单流内容，无底部 Dock。
  Widget _buildNarrowLayout(
    AsyncValue<PhotoCenterState> stateAsync, {
    required bool hosted,
  }) {
    return Stack(
      children: [
        MobilePageSurface(
          exposeBackdrop: hosted,
          backdropOpacity: 1,
          child: Padding(
            padding: EdgeInsets.only(
              top: hosted ? 0 : WorkbenchTopBar.totalHeightOf(context),
            ),
            child: stateAsync.when(
              data:
                  (data) => _PhotoLibrarySurface(
                    state: data,
                    hosted: hosted,
                    onOpenPhoto: (photo) => context.push('/photos/${photo.id}'),
                    onOpenAlbum:
                        (album) => context.push('/photos/albums/${album.id}'),
                    onDeletePhoto:
                        (photo) => _confirmDeletePhoto(context, photo),
                  ),
              error:
                  (error, stackTrace) => AppErrorView(
                    message: describeUserFacingError(error).displayMessage,
                    onRetry:
                        () => ref.invalidate(photoCenterControllerProvider),
                  ),
              loading:
                  () =>
                      hosted
                          ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                MobileSkeletonBlock(height: 220),
                                SizedBox(height: 16),
                                MobileSkeletonBlock(height: 180),
                              ],
                            ),
                          )
                          : const AppLoading.grid(),
            ),
          ),
        ),
        if (!hosted)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _PhotoTopBar(controller: _searchController, ref: ref),
          ),
      ],
    );
  }

  Future<void> _confirmDeletePhoto(
    BuildContext context,
    PhotoItem photo,
  ) async {
    try {
      final deleted = await confirmAndRunFilePurge(
        context,
        resourceName: photo.title,
        action: (cascade) async {
          await ref
              .read(photoCenterControllerProvider.notifier)
              .deletePhoto(photo.id, cascade: cascade);
        },
      );
      if (deleted && context.mounted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).photosDeletedPhoto(photo.title),
              ),
            ),
          );
        }
      }
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).photosDeleteFailed),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteAlbum(
    BuildContext context,
    PhotoAlbum album,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: context.photosColors.surfaceContainerHigh,
            title: Text(
              AppLocalizations.of(context).photosDeleteAlbumTitle,
              style: TextStyle(color: context.photosColors.onSurface),
            ),
            content: Text(
              AppLocalizations.of(context).photosDeleteAlbumConfirm(album.name),
              style: TextStyle(color: context.photosColors.onSurfaceVariant),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(context).photosCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: context.photosColors.danger,
                ),
                child: Text(AppLocalizations.of(context).photosDelete),
              ),
            ],
          ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(photoCenterControllerProvider.notifier)
            .deleteAlbum(album.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).photosDeletedAlbum(album.name),
              ),
            ),
          );
        }
      } on Exception {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).photosDeleteFailed),
            ),
          );
        }
      }
    }
  }

  void _showCreateAlbumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => PhotoDialogTextField(
            builder:
                (ctx, nameController) => PhotoDialogTextField(
                  builder:
                      (ctx, descController) => AlertDialog(
                        backgroundColor:
                            context.photosColors.surfaceContainerHigh,
                        title: Text(
                          AppLocalizations.of(context).photosNewAlbum,
                          style: TextStyle(
                            color: context.photosColors.onSurface,
                          ),
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: nameController,
                              autofocus: true,
                              style: TextStyle(
                                color: context.photosColors.onSurface,
                              ),
                              decoration: InputDecoration(
                                labelText:
                                    AppLocalizations.of(
                                      context,
                                    ).photosAlbumName,
                                hintText:
                                    AppLocalizations.of(
                                      context,
                                    ).photosAlbumNameHint,
                              ),
                            ),
                            SizedBox(height: 12),
                            TextField(
                              controller: descController,
                              style: TextStyle(
                                color: context.photosColors.onSurface,
                              ),
                              decoration: InputDecoration(
                                labelText:
                                    AppLocalizations.of(
                                      context,
                                    ).photosAlbumDescription,
                                hintText:
                                    AppLocalizations.of(
                                      context,
                                    ).photosAlbumDescriptionHint,
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              AppLocalizations.of(context).photosCancel,
                            ),
                          ),
                          FilledButton(
                            onPressed: () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) return;
                              Navigator.pop(ctx);
                              try {
                                await ref
                                    .read(
                                      photoCenterControllerProvider.notifier,
                                    )
                                    .createAlbum(
                                      name: name,
                                      description: descController.text.trim(),
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).photosAlbumCreated(name),
                                      ),
                                    ),
                                  );
                                }
                              } on Exception {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).photosCreateFailed,
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(
                              AppLocalizations.of(context).photosCreate,
                            ),
                          ),
                        ],
                      ),
                ),
          ),
    );
  }
}

/// 顶部导航栏
