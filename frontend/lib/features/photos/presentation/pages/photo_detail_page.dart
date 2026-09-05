import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:omninest/features/photos/presentation/widgets/frame_palette.dart';
import 'package:omninest/features/photos/presentation/widgets/frame_trash_view.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/photos_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/core/errors/error_message.dart';
import 'package:omninest/core/navigation/navigation_extensions.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_common_widgets.dart';
import 'package:omninest/core/widgets/app_error_view.dart';
import 'package:omninest/core/widgets/app_loading.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/domain/photo.dart';

/// 照片详情/查看器页面
class PhotoDetailPage extends ConsumerWidget {
  const PhotoDetailPage({required this.photoId, super.key});

  final String photoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoAsync = ref.watch(photoDetailProvider(photoId));
    return Scaffold(
      backgroundColor: context.photosColors.surface,
      body: photoAsync.when(
        data: (photo) => _PhotoDetailBody(photo: photo),
        error:
            (error, stackTrace) => Column(
              children: [
                SafeArea(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: AppLocalizations.of(context).photosBackToPhotos,
                      onPressed: () => context.popOrGo('/photos'),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                ),
                Expanded(
                  child: AppErrorView(
                    message: describeUserFacingError(error).message,
                    onRetry: () => ref.invalidate(photoDetailProvider(photoId)),
                  ),
                ),
              ],
            ),
        loading: () => const AppLoading.detail(),
      ),
    );
  }
}

class _PhotoDetailBody extends ConsumerStatefulWidget {
  const _PhotoDetailBody({required this.photo});

  final PhotoItem photo;

  @override
  ConsumerState<_PhotoDetailBody> createState() => _PhotoDetailBodyState();
}

class _PhotoDetailBodyState extends ConsumerState<_PhotoDetailBody> {
  bool get _showInfo => ref.watch(photoInfoPanelVisibleProvider);
  bool _locationBackfillAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _backfillLocationIfNeeded();
    });
  }

  void _backfillLocationIfNeeded() {
    if (_locationBackfillAttempted) return;
    _locationBackfillAttempted = true;
    final photo = widget.photo;
    if (!photo.hasGps) return;
    final location = photo.gpsLocation;
    if (location != null && location.isNotEmpty) return;
    unawaited(_backfillGeocode());
  }

  Future<void> _backfillGeocode() async {
    try {
      await ref
          .read(photoCenterControllerProvider.notifier)
          .backfillGeocode(widget.photo.id);
      if (!mounted) return;
      ref.invalidate(photoDetailProvider(widget.photo.id));
    } on Exception {
      // 逆地理编码失败时静默降级：位置信息仅在成功时展示。
    }
  }

  /// 当前浏览范围：浏览视图打开照片时写入；未写入时回退为全部照片。
  List<PhotoItem> _browseScope(PhotoItem photo) {
    final centerState = ref.read(photoCenterControllerProvider).asData?.value;
    final scope = ref.read(photoBrowseScopeProvider);
    if (scope.length > 1 && scope.any((item) => item.id == photo.id)) {
      return scope;
    }
    return centerState?.photos ?? const <PhotoItem>[];
  }

  /// 在当前浏览范围中找到相邻照片 ID，返回 null 表示无相邻照片。
  String? _adjacentPhotoId(PhotoItem photo, int offset) {
    final list = _browseScope(photo);
    final index = list.indexWhere((p) => p.id == photo.id);
    if (index < 0) return null;
    final target = index + offset;
    if (target < 0 || target >= list.length) return null;
    return list[target].id;
  }

  void _navigateToAdjacent(PhotoItem photo, int offset) {
    final targetId = _adjacentPhotoId(photo, offset);
    if (targetId == null || !mounted) return;
    unawaited(_goToAdjacentPhoto(targetId));
  }

  /// 预取目标详情后再替换路由，避免切换时出现加载动画。
  Future<void> _goToAdjacentPhoto(String targetId) async {
    try {
      await ref.read(photoDetailProvider(targetId).future);
    } on Exception {
      // 预取失败时照常跳转，由目标页面展示错误。
    }
    if (!mounted) return;
    context.pushReplacement('/photos/$targetId');
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final compact = MediaQuery.sizeOf(context).width < 700;
    final prevId = _adjacentPhotoId(photo, -1);
    final nextId = _adjacentPhotoId(photo, 1);
    return Column(
      children: [
        // 顶部操作栏
        _DetailTopBar(
          photo: photo,
          onBack: () => context.popOrGo('/photos'),
          onToggleFavorite: () async {
            try {
              if (!mounted) return;
              await ref
                  .read(photoCenterControllerProvider.notifier)
                  .toggleFavorite(photo.id, currentFavorite: photo.favorite);
              if (!mounted) return;
              // 刷新详情
              ref.invalidate(photoDetailProvider(photo.id));
            } on Exception {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context).photosOperationFailed,
                    ),
                  ),
                );
              }
            }
          },
          onDelete: _confirmDelete,
          onToggleInfo:
              () => ref.read(photoInfoPanelVisibleProvider.notifier).toggle(),
          onAddToAlbum: () => _showAddToAlbumDialog(context, ref),
          onEdit: () => context.push('/photos/${photo.id}/edit'),
          onSlideshow:
              () => context.push(
                '/photos/slideshow',
                extra: _slideshowExtra(photo),
              ),
          showInfo: _showInfo,
          compact: compact,
        ),
        // 照片查看区：上/下一张按钮悬浮于图片左右两侧（Frame 设计稿样式）
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final photoView = _buildPhotoView(context, photo, prevId, nextId);
              if (!compact) {
                return Row(
                  children: [
                    Expanded(child: photoView),
                    if (_showInfo) _ExifPanel(photo: photo),
                  ],
                );
              }
              return Column(
                children: [
                  Expanded(child: photoView),
                  if (_showInfo)
                    SizedBox(
                      height: (constraints.maxHeight * 0.42).clamp(
                        180.0,
                        300.0,
                      ),
                      child: _ExifPanel(photo: photo, compact: true),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoView(
    BuildContext context,
    PhotoItem photo,
    String? prevId,
    String? nextId,
  ) {
    final imageUrl = photo.sourceUrl ?? photo.coverUrl;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewBackground =
        isDark
            ? FramePalette.viewerBg
            : context.photosColors.surfaceContainerLow;
    return ColoredBox(
      // 暗色使用设计稿查看器底色，亮色跟随主题浅色底。
      color: viewBackground,
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child:
                  imageUrl != null && imageUrl.isNotEmpty
                      ? Hero(
                        tag: 'photo-cover-${photo.id}',
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 5,
                          child: SizedBox.expand(
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              cacheKey:
                                  photo.sourceUrl != null
                                      ? photo.sourceCacheKey
                                      : photo.coverCacheKey,
                              fit: BoxFit.contain,
                              placeholder:
                                  (context, url) => Center(
                                    child: CircularProgressIndicator(
                                      color:
                                          context.photosColors.primaryContainer,
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) => Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.broken_image_outlined,
                                          color: context
                                              .photosColors
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.4),
                                          size: 48,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          ).photosImageLoadFailed,
                                          style: TextStyle(
                                            color:
                                                context
                                                    .photosColors
                                                    .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                            ),
                          ),
                        ),
                      )
                      : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_outlined,
                            color: context.photosColors.onSurfaceVariant
                                .withValues(alpha: 0.4),
                            size: 64,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            photo.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.photosColors.onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
          if (prevId != null)
            _ViewerArrowButton(
              icon: Icons.chevron_left_rounded,
              tooltip: AppLocalizations.of(context).photosPrevPhoto,
              alignRight: false,
              onTap: () => _navigateToAdjacent(photo, -1),
            ),
          if (nextId != null)
            _ViewerArrowButton(
              icon: Icons.chevron_right_rounded,
              tooltip: AppLocalizations.of(context).photosNextPhoto,
              alignRight: true,
              onTap: () => _navigateToAdjacent(photo, 1),
            ),
        ],
      ),
    );
  }

  /// 幻灯片播放当前可见照片全集，从当前照片开始。
  Map<String, dynamic> _slideshowExtra(PhotoItem photo) {
    var photos = _browseScope(photo);
    if (photos.isEmpty) {
      photos = <PhotoItem>[photo];
    }
    final index = photos.indexWhere((item) => item.id == photo.id);
    return {'photos': photos, 'initialIndex': index < 0 ? 0 : index};
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showFrameConfirmDialog(
      context,
      title: l10n.photosMoveToTrashTitle,
      body: l10n.photosMoveToTrashBodyOne,
      confirmLabel: l10n.photosMoveToTrashAction,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(photoCenterControllerProvider.notifier)
          .movePhotoToTrash(widget.photo.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.photosTrashMoved)));
      context.popOrGo('/photos');
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).photosDeleteFailed),
        ),
      );
    }
  }

  Future<void> _showAddToAlbumDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
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
                albums.isEmpty
                    ? [
                      Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          AppLocalizations.of(
                            context,
                          ).photosNoAlbumsCreateFirst,
                          style: TextStyle(
                            color: context.photosColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ]
                    : albums
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
        await ref
            .read(photoCenterControllerProvider.notifier)
            .addPhotosToAlbum(albumId: selected, photoIds: [widget.photo.id]);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).photosAddedToAlbum),
            ),
          );
        }
      } on Exception {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).photosAddFailed),
            ),
          );
        }
      }
    }
  }
}

/// 详情页顶部栏
class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({
    required this.photo,
    required this.onBack,
    required this.onToggleFavorite,
    required this.onDelete,
    required this.onToggleInfo,
    required this.onAddToAlbum,
    required this.onEdit,
    required this.onSlideshow,
    required this.showInfo,
    required this.compact,
  });

  final PhotoItem photo;
  final VoidCallback onBack;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;
  final VoidCallback onToggleInfo;
  final VoidCallback onAddToAlbum;
  final VoidCallback onEdit;
  final VoidCallback onSlideshow;
  final bool showInfo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.photosColors.surfaceContainer.withValues(
          alpha: compact ? 0.98 : 0.70,
        ),
        border: Border(
          bottom: BorderSide(
            color: context.photosColors.outlineVariant.withValues(alpha: 0.32),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: AppLocalizations.of(context).photosBack,
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: context.photosColors.onSurface,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              photo.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.photosColors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip:
                photo.favorite
                    ? AppLocalizations.of(context).photosUnfavorite
                    : AppLocalizations.of(context).photosFavorite,
            onPressed: onToggleFavorite,
            icon: Icon(
              photo.favorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color:
                  photo.favorite
                      ? context.photosColors.danger
                      : context.photosColors.onSurfaceVariant,
            ),
          ),
          if (compact)
            PopupMenuButton<_PhotoMenuAction>(
              tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
              onSelected: (action) {
                switch (action) {
                  case _PhotoMenuAction.info:
                    onToggleInfo();
                  case _PhotoMenuAction.edit:
                    onEdit();
                  case _PhotoMenuAction.slideshow:
                    onSlideshow();
                  case _PhotoMenuAction.addToAlbum:
                    onAddToAlbum();
                  case _PhotoMenuAction.delete:
                    onDelete();
                }
              },
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: _PhotoMenuAction.info,
                      child: Text(
                        showInfo
                            ? AppLocalizations.of(context).photosHideInfo
                            : AppLocalizations.of(context).photosShowInfo,
                      ),
                    ),
                    PopupMenuItem(
                      value: _PhotoMenuAction.edit,
                      child: Text(AppLocalizations.of(context).photosEdit),
                    ),
                    PopupMenuItem(
                      value: _PhotoMenuAction.slideshow,
                      child: Text(AppLocalizations.of(context).photosSlideshow),
                    ),
                    PopupMenuItem(
                      value: _PhotoMenuAction.addToAlbum,
                      child: Text(
                        AppLocalizations.of(context).photosAddToAlbum,
                      ),
                    ),
                    PopupMenuItem(
                      value: _PhotoMenuAction.delete,
                      child: Text(
                        AppLocalizations.of(context).photosDelete,
                        style: TextStyle(color: context.photosColors.danger),
                      ),
                    ),
                  ],
            )
          else ...[
            IconButton(
              tooltip:
                  showInfo
                      ? AppLocalizations.of(context).photosHideInfo
                      : AppLocalizations.of(context).photosShowInfo,
              onPressed: onToggleInfo,
              icon: const Icon(Icons.info_outline_rounded),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context).photosEdit,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context).photosSlideshow,
              onPressed: onSlideshow,
              icon: const Icon(Icons.slideshow_outlined),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context).photosAddToAlbum,
              onPressed: onAddToAlbum,
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context).photosDelete,
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: context.photosColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// EXIF 信息面板
enum _PhotoMenuAction { info, edit, slideshow, addToAlbum, delete }

class _ExifPanel extends ConsumerWidget {
  const _ExifPanel({required this.photo, this.compact = false});

  final PhotoItem photo;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: compact ? double.infinity : 280,
      decoration: BoxDecoration(
        color: context.photosColors.surfaceContainer,
        border: Border(
          left: BorderSide(
            color:
                compact
                    ? Colors.transparent
                    : context.photosColors.outlineVariant.withValues(
                      alpha: 0.24,
                    ),
          ),
          top: BorderSide(
            color: context.photosColors.outlineVariant.withValues(alpha: 0.24),
          ),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).photosPhotoInfo,
              style: TextStyle(
                color: context.photosColors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            // 基本信息
            _InfoSection(
              title: AppLocalizations.of(context).photosBasicInfo,
              items: [
                if (photo.format.isNotEmpty)
                  _InfoItem(
                    label: AppLocalizations.of(context).photosFormat,
                    value: photo.format.toUpperCase(),
                  ),
                _InfoItem(
                  label: AppLocalizations.of(context).photosFileSize,
                  value: photo.fileSizeDisplay,
                ),
                if (photo.resolutionDisplay != null)
                  _InfoItem(
                    label: AppLocalizations.of(context).photosResolution,
                    value: photo.resolutionDisplay!,
                  ),
                if (photo.dateTaken != null)
                  _InfoItem(
                    label: AppLocalizations.of(context).photosDateTaken,
                    value: _formatDate(photo.dateTaken!),
                  ),
              ],
            ),
            // 相机信息
            if (photo.hasExif) ...[
              const SizedBox(height: 20),
              _InfoSection(
                title: AppLocalizations.of(context).photosCameraInfo,
                items: [
                  if (photo.cameraMake != null)
                    _InfoItem(
                      label: AppLocalizations.of(context).photosBrand,
                      value: photo.cameraMake!,
                    ),
                  if (photo.cameraModel != null)
                    _InfoItem(
                      label: AppLocalizations.of(context).photosModel,
                      value: photo.cameraModel!,
                    ),
                  if (photo.lensModel != null)
                    _InfoItem(
                      label: AppLocalizations.of(context).photosLens,
                      value: photo.lensModel!,
                    ),
                  if (photo.aperture != null)
                    _InfoItem(
                      label: AppLocalizations.of(context).photosAperture,
                      value: 'f/${photo.aperture}',
                    ),
                  if (photo.shutterSpeed != null)
                    _InfoItem(
                      label: AppLocalizations.of(context).photosShutterSpeed,
                      value: photo.shutterSpeed!,
                    ),
                  if (photo.iso != null)
                    _InfoItem(label: 'ISO', value: '${photo.iso}'),
                  if (photo.focalLength != null)
                    _InfoItem(
                      label: AppLocalizations.of(context).photosFocalLength,
                      value: '${photo.focalLength}mm',
                    ),
                ],
              ),
            ],
            // 高级EXIF信息
            if (photo.hasAdvancedExif) ...[
              const SizedBox(height: 20),
              _InfoSection(
                title: AppLocalizations.of(context).photosShootingParams,
                items: [
                  if (photo.flash != null)
                    _InfoItem(
                      label: AppLocalizations.of(context).photosFlash,
                      value: photo.flash!,
                    ),
                  if (photo.whiteBalance != null)
                    _InfoItem(
                      label: AppLocalizations.of(context).photosWhiteBalance,
                      value: photo.whiteBalance!,
                    ),
                  if (photo.meteringMode != null)
                    _InfoItem(
                      label: AppLocalizations.of(context).photosMeteringMode,
                      value: photo.meteringMode!,
                    ),
                ],
              ),
            ],
            // GPS信息
            if (photo.hasGps) ...[
              const SizedBox(height: 20),
              _InfoSection(
                title: AppLocalizations.of(context).photosLocationInfo,
                items: [
                  if (photo.locationDisplay != null)
                    _InfoItem(
                      label: AppLocalizations.of(context).photosPlace,
                      value: photo.locationDisplay!,
                    ),
                  _InfoItem(
                    label: AppLocalizations.of(context).photosCoordinates,
                    value:
                        '${photo.gpsLatitude!.toStringAsFixed(6)}, ${photo.gpsLongitude!.toStringAsFixed(6)}',
                  ),
                ],
              ),
            ],
            // 图像分析标签
            if (photo.contentAnalysis?.labels.isNotEmpty == true) ...[
              SizedBox(height: 20),
              Text(
                AppLocalizations.of(context).photosAIRecognition,
                style: TextStyle(
                  color: context.photosColors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              for (final entry
                  in photo.contentAnalysis!.labelsByNamespace.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    _localizedPhotoAnalysisNamespace(context, entry.key),
                    style: TextStyle(
                      color: context.photosColors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final label in entry.value)
                      Chip(
                        label: Text(
                          _localizedPhotoContentLabel(context, label.code),
                          style: TextStyle(
                            color: context.photosColors.onSurface,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor: context.photosColors.primaryContainer
                            .withValues(alpha: 0.14),
                        side: BorderSide.none,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ],
            // 描述
            if (photo.description != null && photo.description!.isNotEmpty) ...[
              SizedBox(height: 20),
              Text(
                AppLocalizations.of(context).photosDescription,
                style: TextStyle(
                  color: context.photosColors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                photo.description!,
                style: TextStyle(
                  color: context.photosColors.onSurface,
                  fontSize: 13,
                  height: 18 / 13,
                ),
              ),
            ],
            // 标签
            SizedBox(height: 20),
            Text(
              AppLocalizations.of(context).photosTag,
              style: TextStyle(
                color: context.photosColors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in photo.tags)
                  Chip(
                    label: Text(
                      _localizedPhotoAiCategory(context, tag),
                      style: TextStyle(
                        color: context.photosColors.onSurface,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: context.photosColors.surfaceContainerHigh,
                    side: BorderSide.none,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () async {
                      try {
                        await ref
                            .read(photoCenterControllerProvider.notifier)
                            .removeTag(photo.id, tag);
                        if (!context.mounted) return;
                        ref.invalidate(photoDetailProvider(photo.id));
                      } on Exception {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(
                                  context,
                                ).photosDeleteTagFailed,
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ActionChip(
                  label: Text(
                    AppLocalizations.of(context).photosAddTag,
                    style: TextStyle(
                      color: context.photosColors.primaryContainer,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: context.photosColors.primaryContainer
                      .withValues(alpha: 0.12),
                  side: BorderSide.none,
                  avatar: Icon(
                    Icons.add,
                    size: 16,
                    color: context.photosColors.primaryContainer,
                  ),
                  onPressed: () => _showAddTagDialog(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showAddTagDialog(BuildContext context, WidgetRef ref) async {
    final tag = await showDialog<String>(
      context: context,
      builder:
          (ctx) => PhotoDialogTextField(
            builder:
                (ctx, controller) => AlertDialog(
                  backgroundColor: context.photosColors.surfaceContainerHigh,
                  title: Text(
                    AppLocalizations.of(context).photosAddTag,
                    style: TextStyle(color: context.photosColors.onSurface),
                  ),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    style: TextStyle(color: context.photosColors.onSurface),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).photosTagNameInput,
                      hintStyle: TextStyle(
                        color: context.photosColors.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: context.photosColors.outlineVariant.withValues(
                            alpha: 0.32,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: context.photosColors.primaryContainer,
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(AppLocalizations.of(context).photosCancel),
                    ),
                    FilledButton(
                      onPressed:
                          () => Navigator.pop(ctx, controller.text.trim()),
                      child: Text(AppLocalizations.of(context).photosAdd),
                    ),
                  ],
                ),
          ),
    );
    if (tag != null && tag.isNotEmpty && context.mounted) {
      try {
        await ref
            .read(photoCenterControllerProvider.notifier)
            .addTag(photo.id, tag);
        if (!context.mounted) return;
        ref.invalidate(photoDetailProvider(photo.id));
      } on Exception {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).photosAddTagFailed),
            ),
          );
        }
      }
    }
  }
}

String _localizedPhotoAiCategory(BuildContext context, String category) {
  final l10n = AppLocalizations.of(context);
  return switch (category) {
    'Person' => l10n.photosAiCategoryPerson,
    'Cat' => l10n.photosAiCategoryCat,
    'Dog' => l10n.photosAiCategoryDog,
    'Animal' => l10n.photosAiCategoryAnimal,
    'Nature' || 'Landscape' => l10n.photosAiCategoryNature,
    'Architecture' => l10n.photosAiCategoryArchitecture,
    'Indoor' => l10n.photosAiCategoryIndoor,
    'Food' => l10n.photosAiCategoryFood,
    'Vehicle' => l10n.photosAiCategoryVehicle,
    'Plant' => l10n.photosAiCategoryPlant,
    'Sport' => l10n.photosAiCategorySport,
    'Night' => l10n.photosAiCategoryNight,
    'Art' => l10n.photosAiCategoryArt,
    'Document' => l10n.photosAiCategoryDocument,
    _ => category,
  };
}

String _localizedPhotoContentLabel(BuildContext context, String code) {
  return _localizedPhotoAiCategory(context, switch (code) {
    'person' => 'Person',
    'cat' => 'Cat',
    'dog' => 'Dog',
    'bird' => 'Animal',
    'horse' ||
    'sheep' ||
    'cow' ||
    'elephant' ||
    'bear' ||
    'zebra' ||
    'giraffe' => 'Animal',
    'nature' ||
    'beach' ||
    'mountain' ||
    'forest' ||
    'lake' ||
    'ocean' ||
    'river' => 'Nature',
    'indoor' ||
    'office' ||
    'restaurant' ||
    'kitchen' ||
    'bedroom' ||
    'classroom' => 'Indoor',
    'vehicle' => 'Vehicle',
    'food' => 'Food',
    'plant' => 'Plant',
    'document' || 'screenshot' => 'Document',
    'illustration' || 'anime' || 'artwork' => 'Art',
    _ => code,
  });
}

String _localizedPhotoAnalysisNamespace(
  BuildContext context,
  String namespace,
) {
  final l10n = AppLocalizations.of(context);
  return switch (namespace) {
    'SUBJECT' => l10n.photosAnalysisSubject,
    'SCENE' => l10n.photosAnalysisScene,
    'STYLE' => l10n.photosAnalysisStyle,
    _ => l10n.photosAIRecognition,
  };
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.items});

  final String title;
  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.photosColors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8),
        for (final item in items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: context.photosColors.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  item.value,
                  style: TextStyle(
                    color: context.photosColors.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _InfoItem {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;
}

/// Frame 查看器左右切换按钮：42px 方形、圆角 8、35% 黑底、白色 60% 线形图标。
class _ViewerArrowButton extends StatelessWidget {
  const _ViewerArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.alignRight,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scrim =
        isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.35);
    final border =
        isDark
            ? Colors.white.withValues(alpha: 0.24)
            : Colors.white.withValues(alpha: 0.10);
    final iconColor =
        isDark
            ? Colors.white.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.88);
    return Positioned.fill(
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: scrim,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: Tooltip(
                message: tooltip,
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(icon, size: 22, color: iconColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
