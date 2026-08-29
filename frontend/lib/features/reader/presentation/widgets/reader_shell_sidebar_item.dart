part of 'reader_shell.dart';

class _SidebarGroupLabel extends StatelessWidget {
  const _SidebarGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: context.readerColors.onSurfaceVariant,
          fontSize: 11,
          height: 14 / 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  const _SidebarNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.closeOnSelect,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool closeOnSelect;
  final VoidCallback? onTap;

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              height: 42,
              decoration: BoxDecoration(
                color:
                    widget.selected
                        ? context.readerColors.sidebarSelectedBg
                        : _hovered
                        ? context.readerColors.sidebarHoverBg
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      widget.selected
                          ? context.readerColors.sidebarSelectedBorder
                          : _hovered
                          ? context.readerColors.outlineVariant.withValues(
                            alpha: 0.52,
                          )
                          : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(
                    widget.icon,
                    size: 19,
                    color:
                        widget.selected
                            ? context.readerColors.sidebarSelectedFg
                            : _hovered
                            ? context.readerColors.onSurface
                            : context.readerColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            widget.selected
                                ? context.readerColors.sidebarSelectedFg
                                : _hovered
                                ? context.readerColors.onSurface
                                : context.readerColors.onSurfaceVariant,
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight:
                            widget.selected ? FontWeight.w800 : FontWeight.w700,
                      ),
                    ),
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

/// ReaderSection 图标扩展（UI 层）
extension ReaderSectionIcon on ReaderSection {
  IconData get icon => switch (this) {
    ReaderSection.bookshelf => Icons.auto_stories_outlined,
    ReaderSection.books => Icons.library_books_outlined,
    ReaderSection.comics => Icons.collections_bookmark_outlined,
    ReaderSection.bookmarks => Icons.bookmark_outline,
    ReaderSection.notes => Icons.edit_note_outlined,
    ReaderSection.history => Icons.history_outlined,
    ReaderSection.imports => Icons.upload_file_outlined,
    ReaderSection.metadata => Icons.admin_panel_settings_outlined,
  };
}
