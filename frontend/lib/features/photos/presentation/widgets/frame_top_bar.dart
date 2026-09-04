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

/// Frame 顶栏：返回 Portal、衬线视图标题、搜索框与导入、通知、头像入口。
///
/// 多选不提供顶栏按钮，由照片卡片长按进入；回收站与影集视图的
/// 卡片不支持多选。
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

  /// 设计稿搜索框在 md 以下 flex-1 撑满，md 及以上固定宽度。
  final bool searchExpanded;

  /// 显示返回 Portal 入口；应用壳托管的移动端由壳层导航承担。
  final bool showBack;

  static const double height = 56;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.frameColors;

    Widget searchField = _FrameSearchField(
      controller: searchController,
      onChanged: onSearchChanged,
      hint: l10n.photosSearchHint,
      width: searchExpanded ? null : 232,
    );
    if (searchExpanded) {
      searchField = Expanded(child: searchField);
    }

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: showTitle ? 24 : 16),
      decoration: BoxDecoration(
        color: colors.navBg,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (showBack) ...[
            FrameIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: l10n.photosBackToPortal,
              onTap: () => context.go('/portal'),
            ),
            const SizedBox(width: 12),
          ],
          if (showTitle)
            Text(
              frameViewLabel(l10n, view),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: FramePalette.serifFamily,
                fontFamilyFallback: FramePalette.serifFallback,
                color: colors.ink,
                fontSize: 20,
              ),
            ),
          const Spacer(),
          searchField,
          const SizedBox(width: 12),
          _FrameImportAction(),
          const SizedBox(width: 12),
          const NotificationIcon(size: 20),
          const SizedBox(width: 12),
          const UserAvatarMenu(),
        ],
      ),
    );
  }
}

/// Frame 搜索框：单一输入框渲染，白底、细边框、圆角 8、高 40。
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
    final colors = context.frameColors;
    Widget field = SizedBox(
      height: 40,
      width: width,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: colors.ink, fontSize: 14),
        cursorColor: colors.accent,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: colors.muted, fontSize: 14),
          filled: true,
          fillColor: colors.searchFill,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(Icons.search_rounded, size: 16, color: colors.muted),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colors.accent),
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
class FrameIconButton extends StatefulWidget {
  const FrameIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  @override
  State<FrameIconButton> createState() => _FrameIconButtonState();
}

class _FrameIconButtonState extends State<FrameIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameColors;
    final active = widget.active;
    final background =
        active
            ? colors.selectActiveBg
            : _hovering
            ? colors.hover
            : Colors.transparent;
    final iconColor =
        active
            ? colors.accent
            : _hovering
            ? colors.ink
            : colors.muted;
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
      color: context.frameColors.muted,
    );
  }
}
