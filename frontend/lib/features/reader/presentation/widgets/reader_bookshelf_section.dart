import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/reader_colors.dart';
import 'package:omninest/core/widgets/workbench_panel.dart';
import 'package:omninest/features/reader/application/reader_book_provider.dart';
import 'package:omninest/features/reader/application/reader_import_queue_controller.dart';
import 'package:omninest/features/reader/domain/reader_models.dart';
import 'package:omninest/features/reader/presentation/reader_l10n_helpers.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_cover_image.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_snack_bar.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_styles.dart';

/// 正在阅读卡片 — 展示当前继续阅读的书籍进度。
class ReadingNowCard extends ConsumerWidget {
  const ReadingNowCard({required this.book, this.onTap, super.key});

  final ReaderItem? book;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (book == null) return const SizedBox.shrink();
    final item = book!;
    return WorkbenchPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 120,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: context.readerColors.surfaceContainerHighest,
            ),
            child:
                item.hasCover
                    ? AuthCoverImage(
                      itemId: item.id,
                      fit: BoxFit.cover,
                      fallback: Center(
                        child: Text(
                          item.title.trim().isEmpty
                              ? 'R'
                              : item.title.trim().substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: context.readerColors.onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                    : Center(
                      child: Text(
                        item.title.trim().isEmpty
                            ? 'R'
                            : item.title.trim().substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: context.readerColors.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReaderBadge(
                  label: readerTypeLabel(
                    AppLocalizations.of(context),
                    item.itemType,
                  ),
                  color: context.readerColors.primary,
                  backgroundColor: context.readerColors.badgeBg,
                  foregroundColor: context.readerColors.badgeText,
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.readerColors.onSurface,
                    fontSize: 15,
                    height: 20 / 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context).readerPercentRead(
                    ((item.progressPercent ?? 0) * 100).round(),
                  ),
                  style: TextStyle(
                    color: context.readerColors.onSurfaceVariant,
                    fontSize: 12,
                    height: 16 / 12,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (item.progressPercent ?? 0).clamp(0, 1),
                    minHeight: 5,
                    backgroundColor:
                        context.readerColors.surfaceContainerHighest,
                    color: context.readerColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.readerColors.primaryContainer,
                    foregroundColor: context.readerColors.onPrimaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(AppLocalizations.of(context).readerContinueBtn),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 书架网格 — 展示书籍封面和类型标签。
class BookshelfGrid extends ConsumerStatefulWidget {
  const BookshelfGrid({
    required this.books,
    required this.onOpenItem,
    this.onDeleteItem,
    this.onCancelImport,
    this.onViewAll,
    this.importingIds = const {},
    super.key,
  });

  final List<ReaderItem> books;
  final ValueChanged<ReaderItem> onOpenItem;
  final ValueChanged<ReaderItem>? onDeleteItem;
  final ValueChanged<ReaderItem>? onCancelImport;
  final VoidCallback? onViewAll;

  /// 当前正在导入中的书籍 ID 集合（显示加载状态，禁止点击）
  final Set<String> importingIds;

  @override
  ConsumerState<BookshelfGrid> createState() => _BookshelfGridState();
}

class _BookshelfGridState extends ConsumerState<BookshelfGrid> {
  /// 分页渲染：shrinkWrap 网格会一次性布局全部子项，初始只暴露前
  /// [_pageSize] 本书，末尾提供展开入口；导入任务与添加卡片恒显。
  static const _pageSize = 60;
  bool _showAllBooks = false;

  @override
  Widget build(BuildContext context) {
    final importJobs = ref.watch(readerImportQueueProvider);
    final books = widget.books;
    final visibleBookCount =
        _showAllBooks || books.length <= _pageSize ? books.length : _pageSize;
    final hiddenBookCount = books.length - visibleBookCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context).readerBookshelfSection,
                style: TextStyle(
                  color: context.readerColors.onSurface,
                  fontSize: 15,
                  height: 20 / 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (widget.onViewAll != null)
              TextButton(
                onPressed: widget.onViewAll,
                child: Text(AppLocalizations.of(context).readerViewAll),
              ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = readerGridColumnCount(constraints.maxWidth);
            final spacing = constraints.maxWidth < 600 ? 12.0 : 18.0;
            final tileWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final metadataHeight = 34 * textScale.clamp(1.0, 2.0);
            final tileHeight = tileWidth * 1.5 + 8 + metadataHeight;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: tileHeight,
                crossAxisSpacing: spacing,
                mainAxisSpacing: 18,
              ),
              itemCount: visibleBookCount + importJobs.length + 1,
              itemBuilder: (context, index) {
                if (index < books.length) {
                  final book = books[index];
                  return _BookTile(
                    book: book,
                    onTap: () => widget.onOpenItem(book),
                    onDelete:
                        book.spaceType == 'SHARED' ||
                                widget.onDeleteItem == null
                            ? null
                            : () => widget.onDeleteItem!(book),
                    onCancelImport:
                        book.isParsing && widget.onCancelImport != null
                            ? () => widget.onCancelImport!(book)
                            : null,
                    isImporting: widget.importingIds.contains(book.id),
                  );
                }
                final jobIndex = index - books.length;
                if (jobIndex < importJobs.length) {
                  return _ImportJobTile(job: importJobs[jobIndex]);
                }
                return const _AddBookTile();
              },
            );
          },
        ),
        if (hiddenBookCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton.icon(
              onPressed: () => setState(() => _showAllBooks = true),
              icon: const Icon(Icons.expand_more_rounded, size: 18),
              label: Text(
                AppLocalizations.of(
                  context,
                ).readerShowAllBooks(hiddenBookCount),
              ),
            ),
          ),
      ],
    );
  }
}

/// 书架中的单本书籍卡片。
class _BookTile extends ConsumerWidget {
  const _BookTile({
    required this.book,
    required this.onTap,
    this.onDelete,
    this.onCancelImport,
    this.isImporting = false,
  });

  final ReaderItem book;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onCancelImport;
  final bool isImporting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: isImporting ? null : onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: _BookCoverFrame(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (book.hasCover)
                    AuthCoverImage(itemId: book.id, fit: BoxFit.cover)
                  else
                    Center(
                      child: Text(
                        book.title.trim().isEmpty
                            ? 'R'
                            : book.title.trim().substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: context.readerColors.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  _BookStatusBadges(book: book),
                  if (book.isParsing)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _ParseProgressBar(itemId: book.id),
                    ),
                  if (onDelete != null || onCancelImport != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: context.readerColors.surface.withValues(
                          alpha: 0.82,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        child: PopupMenuButton<String>(
                          tooltip: AppLocalizations.of(context).coreMore,
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            color: context.readerColors.onSurface,
                            size: 19,
                          ),
                          onSelected: (value) {
                            if (value == 'cancelImport') {
                              onCancelImport?.call();
                            } else {
                              _confirmDelete(context);
                            }
                          },
                          itemBuilder:
                              (context) => [
                                if (onCancelImport != null)
                                  PopupMenuItem(
                                    value: 'cancelImport',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.stop_circle_outlined,
                                          color: context.readerColors.danger,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          ).readerCancelImport,
                                        ),
                                      ],
                                    ),
                                  ),
                                if (onDelete != null)
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline_rounded,
                                          color: context.readerColors.danger,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          ).readerDeleteBook,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                        ),
                      ),
                    ),
                  if (isImporting) const _ImportingOverlay(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.readerColors.onSurface,
              fontSize: 11,
              height: 14 / 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.readerConfirmDelete),
            content: Text(l10n.readerConfirmDeleteMsg(book.title)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.coreCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: context.readerColors.danger,
                ),
                child: Text(l10n.filesDelete),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      onDelete?.call();
    }
  }
}

/// 添加图书的占位卡片 — 从设备选择 EPUB/TXT 文件上传并导入。
class _AddBookTile extends ConsumerStatefulWidget {
  const _AddBookTile();

  @override
  ConsumerState<_AddBookTile> createState() => _AddBookTileState();
}

class _AddBookTileState extends ConsumerState<_AddBookTile> {
  Future<void> _pickAndUpload() async {
    final l10n = AppLocalizations.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub', 'txt', 'cbz', 'zip'],
        withData: kIsWeb,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      if (!mounted) return;
      final files = result.files.map(_toUploadFile).whereType<XFile>().toList();
      if (files.isEmpty) throw StateError('No readable files selected');
      ref.read(readerImportQueueProvider.notifier).enqueue(files);
    } on Exception {
      if (mounted) {
        showReaderSnackBar(context, l10n.readerImportFailed);
      }
    }
  }

  XFile? _toUploadFile(PlatformFile file) {
    final fileName = file.name;
    final path = file.path;
    if (path != null && path.isNotEmpty) {
      return XFile(path, name: fileName, mimeType: _mimeTypeFor(fileName));
    }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    return XFile.fromData(
      bytes,
      name: fileName,
      mimeType: _mimeTypeFor(fileName),
    );
  }

  String _mimeTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.epub')) {
      return 'application/epub+zip';
    }
    if (lower.endsWith('.cbz') || lower.endsWith('.zip')) {
      return 'application/zip';
    }
    return 'text/plain';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pickAndUpload,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.readerColors.outlineVariant),
                color: context.readerColors.surfaceContainerHighest.withValues(
                  alpha: 0.28,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_rounded,
                    color: context.readerColors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).readerAddBook,
                    style: TextStyle(
                      color: context.readerColors.onSurfaceVariant,
                      fontSize: 11,
                      height: 14 / 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).readerAddBook,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.readerColors.onSurfaceVariant,
              fontSize: 11,
              height: 14 / 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ImportJobTile extends ConsumerWidget {
  const _ImportJobTile({required this.job});

  final ReaderImportJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final failed = job.status == ReaderImportJobStatus.failed;
    final label = switch (job.status) {
      ReaderImportJobStatus.queued => l10n.readerImportQueuedShort,
      ReaderImportJobStatus.uploading => l10n.importUploading,
      ReaderImportJobStatus.registering => l10n.readerImportRegistering,
      ReaderImportJobStatus.failed => l10n.readerImportFailed,
      ReaderImportJobStatus.cancelled => l10n.readerImportCancelled,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: _BookCoverFrame(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    failed ? Icons.error_outline_rounded : Icons.book_outlined,
                    color:
                        failed
                            ? context.readerColors.danger
                            : context.readerColors.primary,
                    size: 30,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.readerColors.onSurface,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!failed)
                    LinearProgressIndicator(
                      value: job.progress > 0 ? job.progress : null,
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    children: [
                      if (failed)
                        IconButton(
                          onPressed:
                              () => ref
                                  .read(readerImportQueueProvider.notifier)
                                  .retry(job.id),
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: l10n.coreRetry,
                        ),
                      IconButton(
                        onPressed:
                            () => ref
                                .read(readerImportQueueProvider.notifier)
                                .cancel(job.id),
                        icon: Icon(
                          failed ? Icons.close_rounded : Icons.stop_rounded,
                        ),
                        tooltip:
                            failed ? l10n.coreClose : l10n.readerCancelImport,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          job.fileName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.readerColors.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BookCoverFrame extends StatelessWidget {
  const _BookCoverFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: context.readerColors.surfaceContainerHighest,
      ),
      child: child,
    );
  }
}

class _BookStatusBadges extends StatelessWidget {
  const _BookStatusBadges({required this.book});

  final ReaderItem book;

  @override
  Widget build(BuildContext context) {
    final ReaderBadge? statusBadge;
    if (book.isParsing) {
      statusBadge = ReaderBadge(
        label: AppLocalizations.of(context).readerComicImportParsing,
        color: context.readerColors.tertiary.withValues(alpha: 0.2),
      );
    } else if (book.isPartialFailed) {
      statusBadge = ReaderBadge(
        label: AppLocalizations.of(context).readerComicImportPartialFailed,
        color: context.readerColors.warning.withValues(alpha: 0.2),
      );
    } else if (book.isFailed) {
      statusBadge = ReaderBadge(
        label: AppLocalizations.of(context).readerComicImportFailed,
        color: context.readerColors.danger.withValues(alpha: 0.2),
      );
    } else {
      statusBadge = null;
    }

    return Stack(
      children: [
        Positioned(
          top: 8,
          left: 8,
          child: ReaderBadge(
            label: readerTypeLabel(AppLocalizations.of(context), book.itemType),
            color: context.readerColors.primary,
            backgroundColor: context.readerColors.badgeBg,
            foregroundColor: context.readerColors.badgeText,
          ),
        ),
        if (statusBadge != null)
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Align(alignment: Alignment.bottomLeft, child: statusBadge),
          ),
      ],
    );
  }
}

class _ImportingOverlay extends StatelessWidget {
  const _ImportingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.black.withValues(alpha: 0.5),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).readerImporting,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 文本书籍解析进度条：轮询后端解析进度并在卡片底部显示百分比。
class _ParseProgressBar extends ConsumerWidget {
  const _ParseProgressBar({required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(textParseProgressProvider(itemId));
    return progressAsync.when(
      data: (value) {
        if (value.finished) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (value.progress / 100).clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                AppLocalizations.of(context).readerComicImportParsing,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  height: 12 / 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// 阅读报告统计卡片，展示今日时长、本周时长、连续天数、阅读书籍数。
class ReadingReportCard extends StatelessWidget {
  const ReadingReportCard({this.stats, super.key});

  final ReaderReadingStats? stats;

  @override
  Widget build(BuildContext context) {
    final rc = context.readerColors;
    final todayMinutes = stats?.totalMinutesToday ?? 0;
    final weekMinutes = stats?.totalMinutesThisWeek ?? 0;
    final streak = stats?.currentStreak ?? 0;
    final books = stats?.totalBooksRead ?? 0;

    return WorkbenchPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rc.tertiary.withValues(alpha: 0.16),
                ),
                child: Icon(Icons.trending_up, color: rc.tertiary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).readerReadingReport,
                  style: TextStyle(
                    color: rc.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatItem(
                label: AppLocalizations.of(context).readerStatsToday,
                value: _formatMinutes(context, todayMinutes),
                color: rc.tertiary,
              ),
              _StatItem(
                label: AppLocalizations.of(context).readerStatsWeek,
                value: _formatMinutes(context, weekMinutes),
                color: rc.onSurface,
              ),
              _StatItem(
                label: AppLocalizations.of(context).readerStatsStreak,
                value: AppLocalizations.of(context).readerStatsDays(streak),
                color: rc.tertiary,
              ),
              _StatItem(
                label: AppLocalizations.of(context).readerStatsBooks,
                value: '$books',
                color: rc.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatMinutes(BuildContext context, int minutes) {
    final l10n = AppLocalizations.of(context);
    if (minutes < 60) return l10n.readerStatsMinutes(minutes);
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0
        ? l10n.readerStatsHoursMinutes(h, m)
        : l10n.readerStatsHours(h);
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: context.readerColors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
