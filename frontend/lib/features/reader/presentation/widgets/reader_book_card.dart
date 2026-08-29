import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/reader_colors.dart';
import 'package:omninest/features/reader/domain/reader_models.dart';
import 'package:omninest/features/reader/presentation/reader_l10n_helpers.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_cover_image.dart';

class ReaderBookCard extends StatefulWidget {
  const ReaderBookCard({
    required this.item,
    required this.onTap,
    this.onDelete,
    this.onToggleBookshelf,
    super.key,
  });

  final ReaderItem item;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleBookshelf;

  @override
  State<ReaderBookCard> createState() => _ReaderBookCardState();
}

class _ReaderBookCardState extends State<ReaderBookCard> {
  bool _hovered = false;

  void _showContextMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = widget.item;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.readerColors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onToggleBookshelf != null)
                  ListTile(
                    leading: Icon(
                      item.addedToBookshelf
                          ? Icons.bookmark_remove_rounded
                          : Icons.bookmark_add_rounded,
                      color: context.readerColors.primary,
                    ),
                    title: Text(
                      item.addedToBookshelf
                          ? l10n.readerRemoveFromBookshelf
                          : l10n.readerAddToBookshelf,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onToggleBookshelf?.call();
                    },
                  ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: context.readerColors.danger,
                  ),
                  title: Text(
                    l10n.readerDeleteBook,
                    style: TextStyle(color: context.readerColors.danger),
                  ),
                  subtitle: Text(l10n.readerDeleteBookHint),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(context);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.readerConfirmDelete),
            content: Text(l10n.readerConfirmDeleteMsg(widget.item.title)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.coreCancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onDelete?.call();
                },
                style: TextButton.styleFrom(
                  foregroundColor: context.readerColors.danger,
                ),
                child: Text(l10n.filesDelete),
              ),
            ],
          ),
    );
  }

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
            onLongPress:
                widget.onDelete != null
                    ? () => _showContextMenu(context)
                    : null,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.readerColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      _hovered
                          ? context.readerColors.primary
                          : context.readerColors.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ReaderBookArt(item: item, hovered: _hovered),
                  ),
                  SizedBox(height: 4),
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
                  SizedBox(height: 2),
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
                  SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (item.progressPercent ?? 0).clamp(0, 1),
                      minHeight: 3,
                      backgroundColor:
                          context.readerColors.surfaceContainerHighest,
                      color:
                          _hovered
                              ? context.readerColors.tertiary
                              : context.readerColors.primary,
                    ),
                  ),
                  SizedBox(height: 5),
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
                          color: context.readerColors.tertiary,
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

class _ReaderBookArt extends StatelessWidget {
  const _ReaderBookArt({required this.item, required this.hovered});

  final ReaderItem item;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(context, item.title);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: palette,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          if (item.hasCover)
            AuthCoverImage(
              itemId: item.id,
              fit: BoxFit.cover,
              fallback: const SizedBox.shrink(),
            ),
          AnimatedOpacity(
            opacity: hovered ? 0.12 : 0.0,
            duration: const Duration(milliseconds: 160),
            child: DecoratedBox(
              decoration: BoxDecoration(color: context.readerColors.onSurface),
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              margin: EdgeInsets.all(5),
              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
          if (item.rating != null &&
              item.rating! > 0 &&
              MediaQuery.sizeOf(context).width >= 360 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.4)
            Align(
              alignment: Alignment.topRight,
              child: Container(
                margin: EdgeInsets.all(5),
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                    SizedBox(width: 2),
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
          if (!item.hasCover)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title.trim().isEmpty
                        ? 'R'
                        : item.title.trim().substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: context.readerColors.badgeText,
                      fontSize: 24,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Icon(
                    Icons.auto_stories_rounded,
                    color: context.readerColors.badgeText.withValues(
                      alpha: 0.7,
                    ),
                    size: 16,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 根据书名哈希值选择封面渐变色板。
  /// 使用固定的 5 组配色方案，确保同一本书始终显示相同的渐变背景。
  List<Color> _paletteFor(BuildContext context, String seed) {
    final start = context.readerColors.coverGradientStart;
    final end = context.readerColors.coverGradientEnd;
    final palettes = <List<Color>>[
      [start, end],
      [start, const Color(0xFF1E7B8B)],
      [start, const Color(0xFFB85C38)],
      [start, const Color(0xFF4C8C72)],
      [start, const Color(0xFF8D6ABF)],
    ];
    return palettes[seed.hashCode.abs() % palettes.length];
  }
}

class ReaderContinueCard extends StatefulWidget {
  const ReaderContinueCard({
    required this.item,
    required this.onTap,
    super.key,
  });

  final ReaderItem item;
  final VoidCallback onTap;

  @override
  State<ReaderContinueCard> createState() => _ReaderContinueCardState();
}

class _ReaderContinueCardState extends State<ReaderContinueCard> {
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
        child: Container(
          width: 220,
          padding: EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: context.readerColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.readerColors.outlineVariant),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: widget.onTap,
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _ReaderBookArt(item: item, hovered: _hovered),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.readerColors.onSurface,
                                fontSize: 13,
                                height: 17 / 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (item.addedToBookshelf)
                            Icon(
                              Icons.bookmark_rounded,
                              color: context.readerColors.tertiary,
                              size: 14,
                            ),
                        ],
                      ),
                      SizedBox(height: 3),
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
                          fontSize: 11,
                          height: 14 / 11,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        item.currentChapterTitle?.isNotEmpty == true
                            ? item.currentChapterTitle!
                            : AppLocalizations.of(
                              context,
                            ).readerContinueReading,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.readerColors.onSurface,
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Spacer(),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: (item.progressPercent ?? 0).clamp(0, 1),
                          minHeight: 5,
                          backgroundColor:
                              context.readerColors.surfaceContainerHighest,
                          color: context.readerColors.tertiary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            readerProgressLabelText(
                              AppLocalizations.of(context),
                              (item.progressPercent ?? 0) * 100,
                            ),
                            style: TextStyle(
                              color: context.readerColors.onSurfaceVariant,
                              fontSize: 11,
                              height: 14 / 11,
                            ),
                          ),
                          Spacer(),
                          Icon(
                            Icons.play_circle_outline_rounded,
                            color: context.readerColors.onPrimaryContainer,
                            size: 15,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
