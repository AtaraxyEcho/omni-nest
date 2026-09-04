import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/presentation/widgets/frame_palette.dart';
import 'package:omninest/features/photos/presentation/widgets/frame_view_meta.dart';

/// Frame 顶栏：衬线视图标题（mr-auto）、搜索框与多选按钮，高度 56px。
///
/// 与设计稿一致：仅"标题 + 搜索 + 选择"三个元素；回收站与影集视图
/// 不提供多选入口。
class FrameTopBar extends ConsumerWidget {
  const FrameTopBar({
    required this.view,
    required this.searchController,
    required this.onSearchChanged,
    required this.showTitle,
    this.searchExpanded = false,
    super.key,
  });

  final FrameView view;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  /// 设计稿在 md 以下隐藏衬线标题。
  final bool showTitle;

  /// 设计稿搜索框在 md 以下 flex-1 撑满，md 及以上固定 w-52（208px）。
  final bool searchExpanded;

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
            _FrameSelectButton(active: isSelectionMode),
          ],
        ],
      ),
    );
  }
}

/// Frame 搜索框：白底、#E5E2DC 细边框、圆角 8、高 32。
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
    Widget field = Container(
      height: 32,
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: FramePalette.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FramePalette.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 14, color: FramePalette.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(color: FramePalette.ink, fontSize: 14),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: FramePalette.muted,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
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

/// 多选按钮：icon-btn 34px，激活态 #C07840 + #F5EFE6 底，悬停 #1A1917 + #F0EDE6 底。
class _FrameSelectButton extends ConsumerStatefulWidget {
  const _FrameSelectButton({required this.active});

  final bool active;

  @override
  ConsumerState<_FrameSelectButton> createState() => _FrameSelectButtonState();
}

class _FrameSelectButtonState extends ConsumerState<_FrameSelectButton> {
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
      message: AppLocalizations.of(context).photosToggleSelection,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap:
              () =>
                  ref
                      .read(photoCenterControllerProvider.notifier)
                      .toggleSelectionMode(),
          child: Semantics(
            button: true,
            selected: active,
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.check_box_outlined, size: 17, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
