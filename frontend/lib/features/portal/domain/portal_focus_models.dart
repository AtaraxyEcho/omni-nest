/// Portal 可聚焦模块。
///
/// Portal 只承接模块的轻量入口和预览，完整操作仍回到各模块页面。
enum PortalFocusModule {
  reader,
  video,
  photos,
  music,
  files,
  weather,
  tasks,
  admin,
}

/// Portal 焦点项图标语义。
enum PortalFocusIcon { reader, video, photos, music }

/// Portal 焦点内容项。
class PortalFocusItem {
  const PortalFocusItem({
    required this.icon,
    required this.module,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.route,
    required this.actionLabel,
    required this.variant,
    this.heroEyebrow,
    this.heroBody,
    this.readerItemId,
  });

  final PortalFocusIcon icon;
  final PortalFocusModule module;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String route;
  final String actionLabel;
  final int variant;
  final String? heroEyebrow;
  final String? heroBody;
  final String? readerItemId;
}
