import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/core/auth/auth_controller.dart';
import 'package:omninest/core/errors/error_message.dart';
import 'package:omninest/core/widgets/user_avatar_menu.dart';
import 'package:omninest/features/files/application/media_import_service.dart';
import 'package:omninest/features/files/media_import_ui.dart';
import 'package:omninest/features/notifications/notification_ui.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/presentation/widgets/frame_palette.dart';
import 'package:omninest/features/photos/presentation/widgets/frame_view_meta.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_common_widgets.dart';

/// Frame 风格顶栏：衬线视图标题、搜索框与图库操作入口，高度 56px。
class FrameTopBar extends ConsumerWidget {
  const FrameTopBar({
    required this.view,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.showTitle,
    this.searchExpanded = false,
    this.showBack = false,
    super.key,
  });

  final FrameView view;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final bool showTitle;
  final bool searchExpanded;
  final bool showBack;

  static const double height = 56;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isSelectionMode =
        ref
            .watch(photoCenterControllerProvider)
            .asData
            ?.value
            .isSelectionMode ??
        false;
    // 回收站与影集视图不提供照片多选入口。
    final canSelect = view != FrameView.trash && view != FrameView.albums;

    Widget searchField = _FrameSearchField(
      controller: searchController,
      query: searchQuery,
      onChanged: onSearchChanged,
      hint: l10n.photosSearchHint,
      width: searchExpanded ? null : 208,
    );
    if (searchExpanded) {
      searchField = Expanded(child: searchField);
    }

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: FramePalette.bg,
        border: Border(bottom: BorderSide(color: FramePalette.border)),
      ),
      child: Row(
        children: [
          if (showBack) ...[
            _FrameIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: l10n.photosBackToPortal,
              onTap: () => context.go('/portal'),
            ),
            const SizedBox(width: 4),
          ],
          if (showTitle) ...[
            const SizedBox(width: 8),
            Text(
              frameViewLabel(l10n, view),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: FramePalette.serifFamily,
                color: FramePalette.ink,
                fontSize: 20,
              ),
            ),
          ],
          const Spacer(),
          searchField,
          if (canSelect) ...[
            const SizedBox(width: 8),
            _FrameIconButton(
              icon: Icons.check_box_outlined,
              tooltip: l10n.photosToggleSelection,
              active: isSelectionMode,
              onTap:
                  () =>
                      ref
                          .read(photoCenterControllerProvider.notifier)
                          .toggleSelectionMode(),
            ),
          ],
          const SizedBox(width: 4),
          _FrameImportAction(),
          const SizedBox(width: 4),
          _FrameIconButton(
            icon: Icons.account_tree_rounded,
            tooltip: l10n.photosInsightsTitle,
            onTap: () => context.push('/photos/insights'),
          ),
          const _RegenerateThumbnailsAction(),
          const SizedBox(width: 4),
          const NotificationIcon(size: 20),
          const SizedBox(width: 8),
          const UserAvatarMenu(),
        ],
      ),
    );
  }
}

/// Frame 搜索框：白底细边框，紧凑视图占满剩余宽度，宽屏固定 208px。
class _FrameSearchField extends StatelessWidget {
  const _FrameSearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.hint,
    this.width,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final String hint;
  final double? width;

  @override
  Widget build(BuildContext context) {
    Widget field = Container(
      height: 34,
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: FramePalette.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FramePalette.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 15, color: FramePalette.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(color: FramePalette.ink, fontSize: 13),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: FramePalette.muted,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (query.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: FramePalette.muted,
                ),
              ),
            ),
        ],
      ),
    );
    if (width == null) {
      field = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: field,
      );
    }
    return field;
  }
}

/// Frame 图标按钮：34px 方形、6px 圆角，激活态陶土色高亮。
class _FrameIconButton extends StatelessWidget {
  const _FrameIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: FramePalette.hover,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFF5EFE6) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 18,
            color: active ? FramePalette.accent : FramePalette.muted,
          ),
        ),
      ),
    );
  }
}

/// Frame 顶栏的照片导入入口，沿用图库导入完成回调。
class _FrameImportAction extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MediaImportButton(
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
        final controller = ref.read(photoCenterControllerProvider.notifier);
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
                photoImportNoticeText(AppLocalizations.of(context), failure),
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
      color: FramePalette.muted,
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
    return _FrameIconButton(
      icon: Icons.burst_mode_outlined,
      tooltip: AppLocalizations.of(context).photoRegenerateThumbnails,
      onTap: _submitting ? null : _handleRegenerateThumbnails,
    );
  }
}
