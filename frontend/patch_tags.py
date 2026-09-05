# -*- coding: utf-8 -*-
"""标签视图接线 + 编辑器旧组件清理。"""
import io


def load(p):
    return io.open(p, encoding='utf-8').read()


def save(p, s):
    io.open(p, 'w', encoding='utf-8', newline='').write(s)


def rep(s, old, new, what):
    assert old in s, 'NOT FOUND [' + what + ']: ' + old[:90]
    return s.replace(old, new, 1)

# ── 1) 视图分发：tags 分支接标签视图 ──
p = 'lib/features/photos/presentation/pages/photos_page_view_content.dart'
s = load(p)
s = rep(s, """        FrameView.tags => FrameEmptyView(
          key: const ValueKey('frame-tags'),
          icon: Icons.sell_outlined,
          message: AppLocalizations.of(context).photosFrameTagsEmpty,
          hint: AppLocalizations.of(context).photosFrameTagsEmptyHint,
        ),""",
"""        FrameView.tags => FrameTagsView(
          key: const ValueKey('frame-tags'),
          onOpenPhoto: onOpenPhoto,
          onToggleFavorite: onToggleFavorite,
        ),""", 'tags branch')
s = rep(s, "import 'package:omninest/features/photos/presentation/widgets/frame_masonry_grid.dart';",
"import 'package:omninest/features/photos/presentation/widgets/frame_masonry_grid.dart';\nimport 'package:omninest/features/photos/presentation/widgets/frame_tags_view.dart';", 'tags import')
save(p, s)
print('view content ok')

# ── 2) 移除旧编辑组件与测试 ──
import os
for f in [
    'lib/features/photos/presentation/widgets/photo_editor_toolbar.dart',
    'lib/features/photos/presentation/widgets/photo_crop_overlay.dart',
    'test/features/photos/photo_crop_overlay_test.dart',
]:
    if os.path.exists(f):
        os.remove(f)
        print('removed', f)
