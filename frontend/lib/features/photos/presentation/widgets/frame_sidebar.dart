import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/features/photos/application/photo_center_models.dart';
import 'package:omninest/features/photos/presentation/widgets/frame_palette.dart';
import 'package:omninest/features/photos/presentation/widgets/frame_view_meta.dart';

/// Frame 风格桌面侧栏：Logo、视图导航与图库统计，宽度 220px，可折叠 60px。
class FrameSidebar extends StatelessWidget {
  const FrameSidebar({
    required this.activeView,
    required this.onSelectView,
    required this.photoCount,
    required this.albumCount,
    required this.trashCount,
    required this.collapsed,
    super.key,
  });

  final FrameView activeView;
  final ValueChanged<FrameView> onSelectView;
  final int photoCount;
  final int albumCount;
  final int trashCount;
  final bool collapsed;

  /// 设计稿导航结构：五个主视图 + 分隔线 + 回收站。
  static const List<FrameView> _primaryViews = <FrameView>[
    FrameView.grid,
    FrameView.timeline,
    FrameView.locations,
    FrameView.tags,
    FrameView.albums,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedContainer(
      duration:
          MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: collapsed ? 60 : 220,
      decoration: const BoxDecoration(
        color: FramePalette.navBg,
        border: Border(right: BorderSide(color: FramePalette.border)),
      ),
      child: Column(
        children: [
          _FrameLogo(collapsed: collapsed),
          Expanded(
            child: SingleChildScrollView(
              // 设计稿 nav 容器 px-2，导航项 w-full 铺满剩余宽度。
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final view in _primaryViews)
                      _FrameNavItem(
                        key: ValueKey('frame-nav-${view.name}'),
                        view: view,
                        label: frameViewLabel(l10n, view),
                        active: activeView == view,
                        collapsed: collapsed,
                        onTap: () => onSelectView(view),
                      ),
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      height: 1,
                      color: FramePalette.border,
                    ),
                    _FrameNavItem(
                      key: const ValueKey('frame-nav-trash'),
                      view: FrameView.trash,
                      label: frameViewLabel(l10n, FrameView.trash),
                      active: activeView == FrameView.trash,
                      collapsed: collapsed,
                      onTap: () => onSelectView(FrameView.trash),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildStats(context),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    // 设计稿折叠态隐藏统计文本，但保留外层 pb-4 的底部让位。
    if (collapsed) {
      return const SizedBox(height: 16);
    }
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.photosFrameStatsPhotos(photoCount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FramePalette.ink,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            l10n.photosFrameStatsMeta(albumCount, trashCount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: FramePalette.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Frame 品牌标：黑底圆角方块内的白色照片图形，静态展示不可点击。
class _FrameLogo extends StatelessWidget {
  const _FrameLogo({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: FramePalette.dark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const CustomPaint(painter: _FrameLogoPainter()),
    );
    if (collapsed) {
      return SizedBox(height: 60, child: Center(child: mark));
    }
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          const SizedBox(width: 16),
          mark,
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'Frame',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: FramePalette.serifFamily,
                fontFamilyFallback: FramePalette.serifFallback,
                color: FramePalette.ink,
                fontSize: 18,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 复刻设计稿 Logo 图形：白色圆角矩形、纸色圆点与山形折线。
class _FrameLogoPainter extends CustomPainter {
  const _FrameLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paperPaint =
        Paint()
          ..color = FramePalette.bg
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final paperFill = Paint()..color = FramePalette.bg;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3 * scale, 3 * scale, 18 * scale, 18 * scale),
        Radius.circular(2 * scale),
      ),
      Paint()..color = FramePalette.white,
    );
    canvas.drawCircle(Offset(8.5 * scale, 8.5 * scale), 2 * scale, paperFill);
    final mountain =
        Path()
          ..moveTo(21 * scale, 15 * scale)
          ..lineTo(16 * scale, 10 * scale)
          ..lineTo(5 * scale, 21 * scale);
    canvas.drawPath(mountain, paperPaint);
  }

  @override
  bool shouldRepaint(_FrameLogoPainter oldDelegate) => false;
}

/// 侧栏导航项：激活 #EDE9E1 底 + 陶土色图标，悬停 #F0EDE6 底。
class _FrameNavItem extends StatefulWidget {
  const _FrameNavItem({
    required this.view,
    required this.label,
    required this.active,
    required this.collapsed,
    required this.onTap,
    super.key,
  });

  final FrameView view;
  final String label;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  State<_FrameNavItem> createState() => _FrameNavItemState();
}

class _FrameNavItemState extends State<_FrameNavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final background =
        active
            ? FramePalette.activeBg
            : _hovering
            ? FramePalette.hover
            : Colors.transparent;
    final foreground =
        active || _hovering ? FramePalette.ink : FramePalette.muted;
    final iconColor = active ? FramePalette.accent : foreground;

    Widget item = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Semantics(
          button: true,
          selected: active,
          child: AnimatedContainer(
            duration:
                MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
            height: 35,
            padding:
                widget.collapsed
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 14),
            alignment:
                widget.collapsed ? Alignment.center : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(frameViewIcon(widget.view), size: 17, color: iconColor),
                if (!widget.collapsed) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (widget.collapsed) {
      item = Tooltip(message: widget.label, child: item);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: item,
    );
  }
}
