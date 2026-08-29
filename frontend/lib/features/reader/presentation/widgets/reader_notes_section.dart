import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/reader_colors.dart';
import 'package:omninest/features/reader/application/reader_controller.dart';
import 'package:omninest/features/reader/domain/reader_models.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_empty_state.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_snack_bar.dart';

/// 自由笔记列表 — 展示所有书籍的笔记，按时间倒序。
///
/// 业内主流（Kindle/微信读书）都有独立的笔记本页面，
/// 用户可以查看、编辑、删除笔记，并跳转到对应书籍。
class ReaderNotesSection extends ConsumerStatefulWidget {
  const ReaderNotesSection({
    required this.items,
    required this.onOpenItem,
    super.key,
  });

  final List<ReaderItem> items;
  final ValueChanged<ReaderItem> onOpenItem;

  @override
  ConsumerState<ReaderNotesSection> createState() => _ReaderNotesSectionState();
}

class _ReaderNotesSectionState extends ConsumerState<ReaderNotesSection> {
  List<_NoteWithBook> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAllNotes();
  }

  Future<void> _loadAllNotes() async {
    if (!mounted) return;
    final dataManager = ref.read(readerDataManagerProvider);
    final allNotes = <_NoteWithBook>[];

    for (final item in widget.items) {
      if (!mounted) return;
      try {
        final notes = await dataManager.loadNotes(item.id);
        if (!mounted) return;
        for (final note in notes) {
          allNotes.add(_NoteWithBook(note: note, item: item));
        }
      } on Exception {
        // 单本书加载失败不影响其他
      }
    }

    // 按创建时间倒序
    allNotes.sort((a, b) {
      final aTime = a.note.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.note.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    if (!mounted) return;
    setState(() {
      _notes = allNotes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_notes.isEmpty) {
      return ReaderEmptyState(
        title: '暂无笔记',
        subtitle: '阅读时选中文本可以添加高亮笔记，或在书籍详情页添加自由笔记',
        icon: Icons.edit_note_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '笔记',
          style: TextStyle(
            color: context.readerColors.onSurface,
            fontSize: 18,
            height: 24 / 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_notes.length} 条笔记',
          style: TextStyle(
            color: context.readerColors.onSurfaceVariant,
            fontSize: 13,
            height: 18 / 13,
          ),
        ),
        const SizedBox(height: 16),
        ..._notes.map(
          (entry) => _NoteTile(
            entry: entry,
            onTap: () => widget.onOpenItem(entry.item),
            onDelete: () => _deleteNote(entry),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteNote(_NoteWithBook entry) async {
    try {
      await ref.read(readerDataManagerProvider).deleteNote(entry.note.id);
      if (mounted) {
        setState(() => _notes.remove(entry));
      }
    } on Exception {
      if (mounted) {
        showReaderSnackBar(
          context,
          AppLocalizations.of(context).readerDeleteItemFailed,
        );
      }
    }
  }
}

/// 笔记与书籍的关联
class _NoteWithBook {
  const _NoteWithBook({required this.note, required this.item});

  final ReaderNote note;
  final ReaderItem item;
}

/// 单条笔记卡片
class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final _NoteWithBook entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final note = entry.note;
    final item = entry.item;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.readerColors.outlineVariant.withValues(
                  alpha: 0.3,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 书籍标题 + 时间
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 14,
                      color: context.readerColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.readerColors.onSurfaceVariant,
                          fontSize: 12,
                          height: 16 / 12,
                        ),
                      ),
                    ),
                    if (note.createdAt != null)
                      Text(
                        _formatTime(note.createdAt!),
                        style: TextStyle(
                          color: context.readerColors.onSurfaceVariant
                              .withValues(alpha: 0.6),
                          fontSize: 11,
                          height: 14 / 11,
                        ),
                      ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onDelete,
                      child: Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: context.readerColors.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                // 笔记标题
                if (note.title != null && note.title!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    note.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.readerColors.onSurface,
                      fontSize: 14,
                      height: 18 / 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                // 笔记内容
                const SizedBox(height: 6),
                Text(
                  note.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.readerColors.onSurface.withValues(
                      alpha: 0.8,
                    ),
                    fontSize: 13,
                    height: 18 / 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }
}
