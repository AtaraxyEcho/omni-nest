import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/mobile_layout_tokens.dart';
import 'package:omninest/app/theme/feature/photos_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/core/auth/auth_controller.dart';
import 'package:omninest/core/errors/error_message.dart';
import 'package:omninest/core/theme/motion_token.dart';
import 'package:omninest/core/widgets/app_empty_state.dart';
import 'package:omninest/core/widgets/workbench_top_bar.dart';
import 'package:omninest/core/widgets/workbench_navigation_bar.dart';
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
import 'package:omninest/features/photos/presentation/widgets/photo_grid_tile.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_group_view.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_timeline_view.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_common_widgets.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_graph_view.dart';
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

/// 底部导航表面。
enum _PhotosNavDestination {
  library(Icons.photo_library_outlined, Icons.photo_library_rounded),
  explore(Icons.explore_outlined, Icons.explore_rounded);

  const _PhotosNavDestination(this.icon, this.selectedIcon);

  final IconData icon;
  final IconData selectedIcon;

  String label(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (this) {
      library => l10n.photosSurfaceLibrary,
      explore => l10n.photosSurfaceExplore,
    };
  }
}

/// 导航表面到数据页签的映射（复用已有分页逻辑）。
PhotoTab _photoTabForDestination(_PhotosNavDestination dest) {
  return switch (dest) {
    _PhotosNavDestination.library => PhotoTab.all,
    _PhotosNavDestination.explore => PhotoTab.timeline,
  };
}

/// PhotoTab 对应的导航表面。
_PhotosNavDestination _destinationForPhotoTab(PhotoTab tab) {
  return switch (tab) {
    PhotoTab.timeline ||
    PhotoTab.groups ||
    PhotoTab.graph => _PhotosNavDestination.explore,
    _ => _PhotosNavDestination.library,
  };
}

class _PhotosPageState extends ConsumerState<PhotosPage> {
  final TextEditingController _searchController = TextEditingController();
  VoidCallback? _routeListener;
  GoRouter? _router;
  DateTime _lastRefresh = DateTime.fromMillisecondsSinceEpoch(0);
  final List<PhotoTab> _tabHistory = [];
  PhotoTab? _lastTab;

  void _onTabChanged(PhotoTab tab) {
    if (_lastTab != null && _lastTab != tab) {
      _tabHistory.add(_lastTab!);
    }
    _lastTab = tab;
    _searchController.clear();
    ref.read(photoCenterControllerProvider.notifier).selectTab(tab);
  }

  void _onBack() {
    if (_tabHistory.isNotEmpty) {
      final prev = _tabHistory.removeLast();
      _lastTab = prev;
      _searchController.clear();
      ref.read(photoCenterControllerProvider.notifier).selectTab(prev);
    } else {
      context.go('/portal');
    }
  }

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
    final currentTab = stateAsync.asData?.value.tab ?? PhotoTab.all;
    final currentDest = _destinationForPhotoTab(currentTab);
    final selectedIndex = _PhotosNavDestination.values.indexOf(currentDest);
    _lastTab ??= currentTab;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide =
            !hosted && !ResponsiveBreakpoints.isCompact(constraints.maxWidth);
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _onBack();
          },
          child: Scaffold(
            backgroundColor:
                hosted ? Colors.transparent : context.photosColors.surface,
            extendBody: true,
            body:
                isWide
                    ? _buildWideLayout(stateAsync, currentTab)
                    : _buildNarrowLayout(
                      stateAsync,
                      currentTab,
                      selectedIndex,
                      hosted: hosted,
                    ),
            bottomNavigationBar:
                isWide || hosted
                    ? null
                    : WorkbenchNavigationBar(
                      currentIndex: selectedIndex,
                      onTap: (i) {
                        final dest = _PhotosNavDestination.values[i];
                        final tab = _photoTabForDestination(dest);
                        _onTabChanged(tab);
                      },
                      items:
                          _PhotosNavDestination.values
                              .map(
                                (dest) => WorkbenchNavigationItem(
                                  icon: dest.icon,
                                  selectedIcon: dest.selectedIcon,
                                  label: dest.label(context),
                                ),
                              )
                              .toList(),
                    ),
          ),
        );
      },
    );
  }

  /// 桌面宽屏布局：顶部栏导航
  Widget _buildWideLayout(
    AsyncValue<PhotoCenterState> stateAsync,
    PhotoTab currentTab,
  ) {
    return Column(
      children: [
        _PhotoDesktopTopBar(
          currentTab: currentTab,
          searchController: _searchController,
          searchQuery: stateAsync.asData?.value.searchQuery ?? '',
          onSearchChanged:
              ref.read(photoCenterControllerProvider.notifier).setSearchQuery,
        ),
        Expanded(
          child: Row(
            children: [
              _PhotoDesktopSidebar(
                currentTab: currentTab,
                onTabChanged: _onTabChanged,
              ),
              Expanded(
                child: ColoredBox(
                  color: context.photosColors.surface,
                  child: stateAsync.when(
                    data:
                        (data) => _PhotoContent(
                          state: data,
                          onOpenPhoto:
                              (photo) => context.push('/photos/${photo.id}'),
                          onOpenAlbum:
                              (album) =>
                                  context.push('/photos/albums/${album.id}'),
                          onDeletePhoto:
                              (photo) => _confirmDeletePhoto(context, photo),
                          onDeleteAlbum:
                              (album) => _confirmDeleteAlbum(context, album),
                          onCreateAlbum: () => _showCreateAlbumDialog(context),
                        ),
                    error:
                        (error, stackTrace) => AppErrorView(
                          message:
                              describeUserFacingError(error).displayMessage,
                          onRetry:
                              () =>
                                  ref.invalidate(photoCenterControllerProvider),
                        ),
                    loading: () => const AppLoading.grid(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 移动端窄屏布局：玻璃顶栏 + 功能栏 + 下拉刷新 + 底部 Dock
  Widget _buildNarrowLayout(
    AsyncValue<PhotoCenterState> stateAsync,
    PhotoTab currentTab,
    int selectedIndex, {
    required bool hosted,
  }) {
    return Stack(
      children: [
        MobilePageSurface(
          exposeBackdrop: hosted,
          backdropOpacity: hosted ? 0.56 : 1,
          child: Padding(
            padding: EdgeInsets.only(
              top: hosted ? 0 : WorkbenchTopBar.totalHeightOf(context),
            ),
            child: Column(
              children: [
                if (hosted)
                  _PhotoMobileSectionBar(
                    currentTab: currentTab,
                    onTabChanged: _onTabChanged,
                  ),
                Expanded(
                  child: stateAsync.when(
                    data: (data) {
                      // 首页：功能栏 + 下拉刷新 + 可滚动内容
                      if (data.tab == PhotoTab.all) {
                        return RefreshIndicator(
                          displacement: 40,
                          edgeOffset: 96,
                          strokeWidth: 2.5,
                          color: context.photosColors.primaryContainer,
                          onRefresh: () async {
                            await ref
                                .read(photoCenterControllerProvider.notifier)
                                .refresh();
                            await Future<void>.delayed(
                              const Duration(milliseconds: 200),
                            );
                          },
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            child: Column(
                              children: [
                                if (!hosted)
                                  _PhotoFunctionBar(
                                    currentTab: data.tab,
                                    onTabChanged:
                                        (tab) => ref
                                            .read(
                                              photoCenterControllerProvider
                                                  .notifier,
                                            )
                                            .selectTab(tab),
                                  ),
                                if (data.errorMessage != null)
                                  MaterialBanner(
                                    content: Text(data.errorMessage!),
                                    backgroundColor:
                                        context
                                            .photosColors
                                            .surfaceContainerHigh,
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () =>
                                                ref
                                                    .read(
                                                      photoCenterControllerProvider
                                                          .notifier,
                                                    )
                                                    .clearError(),
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).photosClose,
                                        ),
                                      ),
                                    ],
                                  ),
                                _PhotoScrollableContent(
                                  state: data,
                                  ref: ref,
                                  onOpenPhoto:
                                      (photo) =>
                                          context.push('/photos/${photo.id}'),
                                  onOpenAlbum:
                                      (album) => context.push(
                                        '/photos/albums/${album.id}',
                                      ),
                                  onDeletePhoto:
                                      (photo) =>
                                          _confirmDeletePhoto(context, photo),
                                  onDeleteAlbum:
                                      (album) =>
                                          _confirmDeleteAlbum(context, album),
                                  onCreateAlbum:
                                      () => _showCreateAlbumDialog(context),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      // 时间线/星系：独立滚动内容 + 下拉刷新
                      if (data.tab == PhotoTab.timeline ||
                          data.tab == PhotoTab.graph) {
                        return RefreshIndicator(
                          displacement: 40,
                          strokeWidth: 2.5,
                          color: context.photosColors.primaryContainer,
                          onRefresh: () async {
                            await ref
                                .read(photoCenterControllerProvider.notifier)
                                .refresh();
                            await Future<void>.delayed(
                              const Duration(milliseconds: 200),
                            );
                          },
                          child: _PhotoIndependentContent(
                            state: data,
                            onOpenPhoto:
                                (photo) => context.push('/photos/${photo.id}'),
                            onOpenAlbum:
                                (album) =>
                                    context.push('/photos/albums/${album.id}'),
                          ),
                        );
                      }
                      // 收藏/相册/其他：下拉刷新 + 可滚动内容
                      return RefreshIndicator(
                        displacement: 40,
                        edgeOffset: 48,
                        strokeWidth: 2.5,
                        color: context.photosColors.primaryContainer,
                        onRefresh: () async {
                          await ref
                              .read(photoCenterControllerProvider.notifier)
                              .refresh();
                          await Future<void>.delayed(
                            const Duration(milliseconds: 200),
                          );
                        },
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          child: Column(
                            children: [
                              if (data.errorMessage != null)
                                MaterialBanner(
                                  content: Text(data.errorMessage!),
                                  backgroundColor:
                                      context.photosColors.surfaceContainerHigh,
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () =>
                                              ref
                                                  .read(
                                                    photoCenterControllerProvider
                                                        .notifier,
                                                  )
                                                  .clearError(),
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).photosClose,
                                      ),
                                    ),
                                  ],
                                ),
                              _PhotoScrollableContent(
                                state: data,
                                ref: ref,
                                onOpenPhoto:
                                    (photo) =>
                                        context.push('/photos/${photo.id}'),
                                onOpenAlbum:
                                    (album) => context.push(
                                      '/photos/albums/${album.id}',
                                    ),
                                onDeletePhoto:
                                    (photo) =>
                                        _confirmDeletePhoto(context, photo),
                                onDeleteAlbum:
                                    (album) =>
                                        _confirmDeleteAlbum(context, album),
                                onCreateAlbum:
                                    () => _showCreateAlbumDialog(context),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    error:
                        (error, stackTrace) => AppErrorView(
                          message:
                              describeUserFacingError(error).displayMessage,
                          onRetry:
                              () =>
                                  ref.invalidate(photoCenterControllerProvider),
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
              ],
            ),
          ),
        ),
        if (!hosted)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _PhotoTopBar(
              controller: _searchController,
              ref: ref,
              currentTab: currentTab,
            ),
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
