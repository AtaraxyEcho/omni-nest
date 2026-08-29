import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/reader_colors.dart';
import 'package:omninest/features/reader/domain/reader_models.dart';

/// 展示阅读书签，并将书签关联到当前书库条目。
class ReaderBookmarkList extends StatefulWidget {
  const ReaderBookmarkList({
    required this.bookmarks,
    required this.items,
    required this.onOpenItem,
    super.key,
  });

  final List<ReaderBookmark> bookmarks;
  final List<ReaderItem> items;
  final ValueChanged<ReaderItem> onOpenItem;

  @override
  State<ReaderBookmarkList> createState() => _ReaderBookmarkListState();
}

class _ReaderBookmarkListState extends State<ReaderBookmarkList> {
  late Map<String, ReaderItem> _itemMap;

  @override
  void initState() {
    super.initState();
    _itemMap = {for (final item in widget.items) item.id: item};
  }

  @override
  void didUpdateWidget(ReaderBookmarkList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _itemMap = {for (final item in widget.items) item.id: item};
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      addAutomaticKeepAlives: false,
      itemCount: widget.bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = widget.bookmarks[index];
        final item = _itemMap[bookmark.readerItemId];
        return _ReaderBookmarkTile(
          bookmark: bookmark,
          item: item,
          onTap: item != null ? () => widget.onOpenItem(item) : null,
        );
      },
    );
  }
}

class _ReaderBookmarkTile extends StatelessWidget {
  const _ReaderBookmarkTile({
    required this.bookmark,
    required this.item,
    required this.onTap,
  });

  final ReaderBookmark bookmark;
  final ReaderItem? item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.bookmark_rounded,
                  color: context.readerColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item?.title ??
                            AppLocalizations.of(context).readerUnknownBook,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.readerColors.onSurface,
                          fontSize: 14,
                          height: 18 / 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (bookmark.chapterTitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          bookmark.chapterTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.readerColors.onSurfaceVariant,
                            fontSize: 12,
                            height: 16 / 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(bookmark.progressPercent * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: context.readerColors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (bookmark.note != null && bookmark.note!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.sticky_note_2_outlined,
                    color: context.readerColors.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
