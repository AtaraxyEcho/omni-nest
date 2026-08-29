import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/reader_colors.dart';
import 'package:omninest/features/reader/domain/reader_models.dart';
import 'package:omninest/features/reader/presentation/reader_l10n_helpers.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_cover_image.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_empty_state.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_styles.dart';

/// 漫画列表页 — 书架网格视图，展示 CBZ/ZIP 类型的漫画条目。
class ComicListPage extends ConsumerWidget {
  const ComicListPage({
    required this.items,
    required this.onOpenItem,
    super.key,
  });

  /// 所有阅读条目（由父组件传入，已从 readerControllerProvider 获取）。
  final List<ReaderItem> items;

  /// 点击条目时的回调。
  final ValueChanged<ReaderItem> onOpenItem;

  /// 从全量条目中过滤漫画类型（基于 contentKind）。
  static List<ReaderItem> filterComics(List<ReaderItem> items) {
    return items.where((i) => i.isComic).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comics = filterComics(items);

    if (comics.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return ReaderEmptyState(
        title: l10n.readerComicEmptyTitle,
        subtitle: l10n.readerComicEmptyHint,
        icon: Icons.collections_bookmark_outlined,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = readerGridColumnCount(constraints.maxWidth);
        return GridView.builder(
          itemCount: comics.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
            childAspectRatio: readerGridChildAspectRatio(context),
          ),
          itemBuilder: (context, index) {
            final item = comics[index];
            return _ComicCard(item: item, onTap: () => onOpenItem(item));
          },
        );
      },
    );
  }
}

/// 漫画卡片 — 复用 ReaderBookCard 的视觉风格，使用漫画主题色。
class _ComicCard extends StatefulWidget {
  const _ComicCard({required this.item, required this.onTap});

  final ReaderItem item;
  final VoidCallback onTap;

  @override
  State<_ComicCard> createState() => _ComicCardState();
}

class _ComicCardState extends State<_ComicCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Semantics(
      label: item.title,
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.readerColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      _hovered
                          ? context.readerColors.comicText
                          : context.readerColors.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _ComicArt(item: item, hovered: _hovered)),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.readerColors.onSurface,
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.authorName?.isNotEmpty == true
                        ? item.authorName!
                        : readerTypeLabel(
                          AppLocalizations.of(context),
                          item.itemType,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.readerColors.onSurfaceVariant,
                      fontSize: 12,
                      height: 14 / 10,
                    ),
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (item.progressPercent ?? 0).clamp(0, 1),
                      minHeight: 3,
                      backgroundColor:
                          context.readerColors.surfaceContainerHighest,
                      color:
                          _hovered
                              ? context.readerColors.comicText
                              : context.readerColors.comicMuted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          readerProgressLabelText(
                            AppLocalizations.of(context),
                            (item.progressPercent ?? 0) * 100,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.readerColors.onSurfaceVariant,
                            fontSize: 11,
                            height: 14 / 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (item.addedToBookshelf)
                        Icon(
                          Icons.bookmark_rounded,
                          color: context.readerColors.comicMuted,
                          size: 12,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 漫画封面艺术 — 使用深色渐变背景，与书籍卡片区分。
class _ComicArt extends StatelessWidget {
  const _ComicArt({required this.item, required this.hovered});

  final ReaderItem item;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 深色渐变背景（漫画专用配色）
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.readerColors.comicBg,
                  context.readerColors.comicBg.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // 封面图（如果有）
          if (item.hasCover)
            AuthCoverImage(
              itemId: item.id,
              fit: BoxFit.cover,
              fallback: const SizedBox.shrink(),
            ),
          // 悬浮遮罩
          AnimatedOpacity(
            opacity: hovered ? 0.12 : 0.0,
            duration: const Duration(milliseconds: 160),
            child: DecoratedBox(
              decoration: BoxDecoration(color: context.readerColors.onSurface),
            ),
          ),
          // 类型标签
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              margin: const EdgeInsets.all(5),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: context.readerColors.badgeBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: context.readerColors.overlayLight),
              ),
              child: Text(
                readerTypeLabel(AppLocalizations.of(context), item.itemType),
                style: TextStyle(
                  color: context.readerColors.badgeText,
                  fontSize: 11,
                  height: 14 / 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          // 评分标签
          if (item.rating != null &&
              item.rating! > 0 &&
              MediaQuery.sizeOf(context).width >= 360 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.4)
            Align(
              alignment: Alignment.topRight,
              child: Container(
                margin: const EdgeInsets.all(5),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: context.readerColors.badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: context.readerColors.star,
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      item.rating!.toStringAsFixed(1),
                      style: TextStyle(
                        color: context.readerColors.badgeText,
                        fontSize: 11,
                        height: 14 / 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 无封面时显示首字母占位
          if (!item.hasCover)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title.trim().isEmpty
                        ? 'C'
                        : item.title.trim().substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: context.readerColors.comicText,
                      fontSize: 24,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Icon(
                    Icons.auto_stories_rounded,
                    color: context.readerColors.comicMuted,
                    size: 16,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
