import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/photos_colors.dart';
import 'package:omninest/features/photos/domain/photo.dart';

/// 照片网格缩略图
class PhotoGridTile extends StatelessWidget {
  const PhotoGridTile({
    required this.photo,
    required this.onTap,
    this.onLongPress,
    this.onDelete,
    this.isSelectionMode = false,
    this.isSelected = false,
    super.key,
  });

  final PhotoItem photo;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<PhotoItem>? onDelete;
  final bool isSelectionMode;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel =
        photo.resolutionDisplay == null
            ? photo.title
            : '${photo.title}, ${photo.resolutionDisplay}';
    final deleteSemanticsActions =
        !isSelectionMode && onDelete != null
            ? <CustomSemanticsAction, VoidCallback>{
              CustomSemanticsAction(
                    label: AppLocalizations.of(context).photosDelete,
                  ):
                  () => onDelete!(photo),
            }
            : null;
    Widget tile = FocusableActionDetector(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onTap();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        label: semanticsLabel,
        onTap: onTap,
        onLongPress: onLongPress,
        customSemanticsActions: deleteSemanticsActions,
        child: GestureDetector(
          excludeFromSemantics: true,
          onTap: onTap,
          onLongPress: onLongPress,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 照片缩略图
                if (photo.hasCover)
                  CachedNetworkImage(
                    imageUrl: photo.coverUrl!,
                    cacheKey: photo.coverCacheKey,
                    fit: BoxFit.cover,
                    memCacheWidth: 200,
                    useOldImageOnUrlChange: true,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder:
                        (context, url) => Container(
                          color: context.photosColors.surfaceContainerHigh,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                AppLocalizations.of(
                                  context,
                                ).photoThumbnailLoading,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.photosColors.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                    errorWidget:
                        (context, url, error) =>
                            _Placeholder(format: photo.format),
                  )
                else
                  _Placeholder(format: photo.format),

                // 选中半透明遮罩
                if (isSelected)
                  Container(
                    color: context.photosColors.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                  ),

                // 选择模式复选框
                if (isSelectionMode)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? context.photosColors.primaryContainer
                                : context.photosColors.badgeBg,
                        shape: BoxShape.circle,
                        border:
                            isSelected
                                ? null
                                : Border.all(
                                  color: context.photosColors.badgeText
                                      .withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                      ),
                      child:
                          isSelected
                              ? Icon(
                                Icons.check_rounded,
                                color: context.photosColors.badgeText,
                                size: 16,
                              )
                              : null,
                    ),
                  ),

                // 收藏标记（非选择模式时显示）
                if (photo.favorite && !isSelectionMode)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: context.photosColors.badgeBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        color: context.photosColors.danger,
                        size: 14,
                      ),
                    ),
                  ),

                // 底部渐变 + 文件大小
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 20, 8, 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          context.photosColors.overlay,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            photo.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.photosColors.mediaOverlayText,
                              fontSize: 11,
                              height: 14 / 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (photo.resolutionDisplay != null) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              photo.resolutionDisplay!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: context.photosColors.mediaOverlayText
                                    .withValues(alpha: 0.7),
                                fontSize: 10,
                                height: 13 / 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 非选择模式且有 onDelete 回调时，支持左滑删除
    if (!isSelectionMode && onDelete != null) {
      tile = Dismissible(
        key: ValueKey(photo.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          onDelete!(photo);
          return false;
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
        child: tile,
      );
    }

    return tile;
  }
}

/// 无封面时的占位图
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.format});

  final String format;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.photosColors.surfaceContainerHigh,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_outlined,
              color: context.photosColors.onSurfaceVariant.withValues(
                alpha: 0.4,
              ),
              size: 28,
            ),
            SizedBox(height: 4),
            Text(
              format.toUpperCase(),
              style: TextStyle(
                color: context.photosColors.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
