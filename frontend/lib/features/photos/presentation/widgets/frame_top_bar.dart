import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/core/widgets/user_avatar_menu.dart';
import 'package:omninest/features/files/application/media_import_service.dart';
import 'package:omninest/features/files/media_import_ui.dart';
import 'package:omninest/features/notifications/notification_ui.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/presentation/widgets/frame_palette.dart';
import 'package:omninest/features/photos/presentation/widgets/frame_view_meta.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_common_widgets.dart';

/// Frame 顶栏：返回 Portal、衬线视图标题、搜索框、多选与图库功能入口。
///
/// 布局比照设计稿：标题 mr-auto 靠左，搜索框（md 及以上 208px，以下撑满）
/// 与操作图标靠右；回收站与影集视图不提供多选入口。
class FrameTopBar extends ConsumerWidget {
  const FrameTopBar({
    required this.view,
    required this.searchController,
    required this.onSearchChanged,
    required this.showTitle,
    this.searchExpanded = false,
    this.showBack = false,
    super.key,
  });

  final FrameView view;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  /// 设计稿在 md 以下隐藏衬线标题。
  final bool showTitle;

  /// 设计稿搜索框在 md 以下 flex-1 撑满，md 及以上固定 w-52（208px）。
  final bool searchExpanded;

  /// 显示返回 Portal 入口；应用壳托管的移动端由壳层导航承担。
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
    final canSelect = view != FrameView.trash && view != FrameView.albums;

    Widget searchField = _FrameSearchField(
      controller: searchController,
      onChanged: onSearchChanged,
      hint: l10n.photosSearchHint,
      width: searchExpanded ? null : 208,
    );
    if (searchExpanded) {
      searchField = Expanded(child: searchField);
    }

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: showTitle ? 24 : 16),
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
            const SizedBox(width: 8),
          ],
          if (showTitle)
            Text(
              frameViewLabel(l10n, view),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: FramePalette.serifFamily,
                fontFamilyFallback: FramePalette.serifFallback,
                color: FramePalette.ink,
                fontSize: 20,
              ),
            ),
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
          const SizedBox(width: 8),
          _FrameImportAction(),
          const SizedBox(width: 8),
          const NotificationIcon(size: 20),
          const SizedBox(width: 8),
          const UserAvatarMenu(),
        ],
      ),
    );
  }
}

/// Frame 搜索框：单一输入框渲染，白底、#E5E2DC 边框、圆角 8、高 32。
class _FrameSearchField extends StatelessWidget {
  const _FrameSearchField({
    required this.controller,
    required this.onChanged,
    required this.hint,
    this.width,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final double? width;

  @override
  Widget build(BuildContext context) {
    Widget field = SizedBox(
      height: 32,
      width: width,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: FramePalette.ink, fontSize: 14),
        cursorColor: FramePalette.accent,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: FramePalette.muted, fontSize: 14),
          filled: true,
          fillColor: FramePalette.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 12, right: 8),
            child: Icon(
              Icons.search_rounded,
              size: 14,
              color: FramePalette.muted,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: FramePalette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: FramePalette.border),
          ),
        ),
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

/// Frame 图标按钮：34px 方形、6px 圆角，激活态陶土色高亮，悬停墨色。
class _FrameIconButton extends StatefulWidget {
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
  State<_FrameIconButton> createState() => _FrameIconButtonState();
}

class _FrameIconButtonState extends State<_FrameIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final background =
        active
            ? const Color(0xFFF5EFE6)
            : _hovering
            ? FramePalette.hover
            : Colors.transparent;
    final iconColor =
        active
            ? FramePalette.accent
            : _hovering
            ? FramePalette.ink
            : FramePalette.muted;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(widget.icon, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }
}

/// 顶栏照片导入入口，沿用图库导入完成回调。
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
