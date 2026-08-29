import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/reader_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/core/widgets/app_error_view.dart';
import 'package:omninest/core/widgets/app_loading.dart';
import 'package:omninest/features/reader/application/reader_controller.dart';
import 'package:omninest/features/reader/application/reader_comic_service.dart';
import 'package:omninest/features/reader/application/reader_book_provider.dart';
import 'package:omninest/features/reader/application/reader_local_progress.dart';
import 'package:omninest/features/reader/domain/reader_chapter_hierarchy.dart';
import 'package:omninest/features/reader/domain/reader_models.dart';
import 'package:omninest/features/reader/domain/reader_status_constants.dart';
import 'package:omninest/features/reader/presentation/pages/comic_detail_page.dart';
import 'package:omninest/features/reader/presentation/reader_l10n_helpers.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_item_detail_widgets.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_snack_bar.dart';

class ReaderItemDetailPage extends ConsumerStatefulWidget {
  const ReaderItemDetailPage({required this.itemId, super.key});

  final String itemId;

  @override
  ConsumerState<ReaderItemDetailPage> createState() =>
      _ReaderItemDetailPageState();
}

class _ReaderItemDetailPageState extends ConsumerState<ReaderItemDetailPage> {
  bool _bookshelfBusy = false;

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/reader');
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(readerItemDetailProvider(widget.itemId));

    return detailAsync.when(
      data: (detail) {
        // 漫画条目使用专用详情页
        final isComic = detail.item.isComic;
        if (isComic) {
          return _ComicDetailWrapper(item: detail.item, itemId: widget.itemId);
        }

        final bookAsync = ref.watch(parsedBookProvider(widget.itemId));
        if (bookAsync.isLoading) {
          return _BookPreparationScaffold(onBack: _handleBack);
        }
        if (bookAsync.hasError) {
          return Scaffold(
            backgroundColor: context.readerColors.surface,
            body: AppErrorView(
              message: AppLocalizations.of(context).readerChapterLoadFailed,
              onBack: _handleBack,
              onRetry: () => ref.invalidate(parsedBookProvider(widget.itemId)),
            ),
          );
        }

        // 从本地解析获取章节列表（后端不返回章节）
        final parsedBook = bookAsync.asData?.value;
        final chapters =
            parsedBook?.chapters
                .asMap()
                .entries
                .map(
                  (e) => ReaderChapter.fromParsed(
                    e.key,
                    e.value.title,
                    contentPath: e.value.contentPath,
                    level: e.value.level,
                  ),
                )
                .toList() ??
            <ReaderChapter>[];
        if (chapters.isEmpty) {
          return Scaffold(
            backgroundColor: context.readerColors.surface,
            body: AppErrorView(
              message: AppLocalizations.of(context).readerChapterLoadFailed,
              onBack: _handleBack,
              onRetry: () => ref.invalidate(parsedBookProvider(widget.itemId)),
            ),
          );
        }

        // 使用解析的元数据覆盖 API 数据（如果 API 数据是临时文件名）
        final effectiveItem = _buildEffectiveItem(detail.item, parsedBook);

        return Scaffold(
          backgroundColor: context.readerColors.surface,
          body: _DetailContent(
            detail: ReaderItemDetail(
              item: effectiveItem,
              progress: detail.progress,
              chapters: chapters,
            ),
            bookshelfBusy: _bookshelfBusy,
            onToggleBookshelf: () async {
              setState(() => _bookshelfBusy = true);
              try {
                await ref
                    .read(readerCenterControllerProvider.notifier)
                    .toggleBookshelf(detail.item.id);
                if (mounted) {
                  ref.invalidate(readerItemDetailProvider(widget.itemId));
                  ref.invalidate(readerCenterControllerProvider);
                }
              } on Exception {
                if (context.mounted) {
                  final l10n = AppLocalizations.of(context);
                  showReaderSnackBar(context, l10n.readerOperationFailed);
                }
              } finally {
                if (mounted) {
                  setState(() => _bookshelfBusy = false);
                }
              }
            },
            onReadChapter: (chapter) {
              context.push(
                '/reader/items/${detail.item.id}/chapters/${chapter.id}',
              );
            },
          ),
        );
      },
      error:
          (error, stackTrace) => Scaffold(
            backgroundColor: context.readerColors.surface,
            body: AppErrorView(
              message: error.toString(),
              onBack: _handleBack,
              onRetry:
                  () => ref.invalidate(readerItemDetailProvider(widget.itemId)),
            ),
          ),
      loading:
          () => Scaffold(
            backgroundColor: context.readerColors.surface,
            body: AppLoading.detail(),
          ),
    );
  }

  /// 使用解析的元数据覆盖 API 数据（如果 API 数据是临时文件名）
  ReaderItem _buildEffectiveItem(ReaderItem apiItem, ParsedBook? parsedBook) {
    if (parsedBook == null) return apiItem;

    final parsedTitle = parsedBook.title;
    final parsedAuthor = parsedBook.author;

    // 如果解析出的标题与 API 标题不同，说明 API 存的是文件名
    final needsTitleUpdate =
        parsedTitle != null &&
        parsedTitle.isNotEmpty &&
        parsedTitle != apiItem.title;
    final needsAuthorUpdate =
        parsedAuthor != null &&
        parsedAuthor.isNotEmpty &&
        apiItem.authorName == null;

    if (!needsTitleUpdate && !needsAuthorUpdate) return apiItem;

    return ReaderItem(
      id: apiItem.id,
      fileNodeId: apiItem.fileNodeId,
      itemType: apiItem.itemType,
      title: needsTitleUpdate ? parsedTitle : apiItem.title,
      authorName: needsAuthorUpdate ? parsedAuthor : apiItem.authorName,
      coverUrl: apiItem.coverUrl,
      description: apiItem.description,
      publisher: apiItem.publisher,
      language: apiItem.language,
      rating: apiItem.rating,
      progressPercent: apiItem.progressPercent,
      updatedAt: apiItem.updatedAt,
      addedToBookshelf: apiItem.addedToBookshelf,
      spaceType: apiItem.spaceType,
      currentChapterTitle: apiItem.currentChapterTitle,
      metadataStatus: apiItem.metadataStatus,
      releaseDate: apiItem.releaseDate,
      genres: apiItem.genres,
      serialStatus: apiItem.serialStatus,
      contentKind: apiItem.contentKind,
      importStatus: apiItem.importStatus,
      parseErrorCode: apiItem.parseErrorCode,
      parseErrorMessage: apiItem.parseErrorMessage,
    );
  }
}

class _DetailContent extends StatefulWidget {
  const _DetailContent({
    required this.detail,
    required this.bookshelfBusy,
    required this.onToggleBookshelf,
    required this.onReadChapter,
  });

  final ReaderItemDetail detail;
  final bool bookshelfBusy;
  final VoidCallback onToggleBookshelf;
  final ValueChanged<ReaderChapter> onReadChapter;

  @override
  State<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends State<_DetailContent> {
  bool _showFullDescription = false;
  final ScrollController _chapterScrollController = ScrollController();

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/reader');
  }

  bool _showAllChapters = true;

  /// 已折叠的卷标题 ID 集合（默认全部展开）
  final Set<String> _collapsedVolumes = {};

  static const _collapsedMaxLines = 3;

  /// 切换卷标题的展开/折叠状态
  void _toggleVolume(String volumeId) {
    setState(() {
      if (_collapsedVolumes.contains(volumeId)) {
        _collapsedVolumes.remove(volumeId);
      } else {
        _collapsedVolumes.add(volumeId);
      }
    });
  }

  /// 判断某卷标题是否包含子章节
  bool _hasChildren(ReaderChapter volume, List<ReaderChapter> allChapters) {
    return ReaderChapterHierarchy.hasChildren(allChapters, volume);
  }

  @override
  void dispose() {
    _chapterScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.detail.item;
    final chapters = widget.detail.chapters;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = ReaderDetailLayout.resolve(constraints.maxWidth);
        final information = _buildBookInformation(
          item,
          isDesktop: layout.isDesktop,
        );
        final description = _buildDescriptionSection(item);
        final directory =
            chapters.isEmpty
                ? const SizedBox.shrink()
                : _buildChapterSection(chapters, layout);

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: layout.isDesktop ? 20 : 8,
              bottom: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.horizontalPadding,
                  ),
                  child: _buildTopBar(context),
                ),
                SizedBox(height: layout.isDesktop ? 20 : 12),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: layout.maxContentWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: layout.horizontalPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (layout.isDesktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DetailCover(
                                  item: item,
                                  width: layout.coverWidth,
                                  height: layout.coverHeight,
                                ),
                                SizedBox(width: layout.summaryGap),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      information,
                                      SizedBox(height: layout.sectionGap),
                                      Divider(
                                        color: context
                                            .readerColors
                                            .outlineVariant
                                            .withValues(alpha: 0.30),
                                      ),
                                      SizedBox(height: layout.sectionGap),
                                      description,
                                      if (chapters.isNotEmpty) ...[
                                        SizedBox(height: layout.sectionGap),
                                        directory,
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            Align(
                              child: DetailCover(
                                item: item,
                                width: layout.coverWidth,
                                height: layout.coverHeight,
                              ),
                            ),
                            SizedBox(height: layout.summaryGap),
                            information,
                            SizedBox(height: layout.sectionGap),
                            Divider(
                              color: context.readerColors.outlineVariant
                                  .withValues(alpha: 0.30),
                            ),
                            SizedBox(height: layout.sectionGap),
                            description,
                            if (chapters.isNotEmpty) ...[
                              SizedBox(height: layout.sectionGap),
                              directory,
                            ],
                          ],
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookInformation(ReaderItem item, {required bool isDesktop}) {
    final alignment = isDesktop ? TextAlign.left : TextAlign.center;
    final wrapAlignment =
        isDesktop ? WrapAlignment.start : WrapAlignment.center;
    return Column(
      crossAxisAlignment:
          isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          item.title,
          textAlign: alignment,
          style: TextStyle(
            color: context.readerColors.onSurface,
            fontSize: isDesktop ? 30 : 24,
            height: 1.25,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (item.authorName?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            item.authorName!,
            textAlign: alignment,
            style: TextStyle(
              color: context.readerColors.onSurfaceVariant,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 18),
        _buildCapsuleRow(item, alignment: wrapAlignment),
        if (item.genres?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          _buildGenreTags(item.genres!, alignment: wrapAlignment),
        ],
        const SizedBox(height: 28),
        FutureBuilder<Map<String, dynamic>?>(
          future: ReaderLocalProgress.loadLatest(item.id),
          builder: (context, snapshot) {
            return ReaderDetailActions(
              detail: widget.detail,
              bookshelfBusy: widget.bookshelfBusy,
              onToggleBookshelf: widget.onToggleBookshelf,
              onReadChapter: widget.onReadChapter,
              localPayload: snapshot.data,
              alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
            );
          },
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: AppLocalizations.of(context).coreBack,
          onPressed: _handleBack,
          icon: Icon(
            Icons.arrow_back_rounded,
            color: context.readerColors.onSurface,
          ),
          style: IconButton.styleFrom(backgroundColor: Colors.transparent),
        ),
        Spacer(),
      ],
    );
  }

  Widget _buildCapsuleRow(ReaderItem item, {required WrapAlignment alignment}) {
    final capsules = <CapsuleData>[
      CapsuleData(
        readerTypeLabel(AppLocalizations.of(context), item.itemType),
        context.readerColors.primary,
      ),
      if (item.rating != null && item.rating! > 0)
        CapsuleData(
          '${item.rating!.toStringAsFixed(1)} ★',
          context.readerColors.success,
        ),
      if (item.publisher?.isNotEmpty == true)
        CapsuleData(item.publisher!, context.readerColors.tertiary),
      if (item.serialStatus?.isNotEmpty == true)
        CapsuleData(item.serialStatus!, context.readerColors.success),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: alignment,
      children: [
        for (final c in capsules)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: c.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              c.label,
              style: TextStyle(
                color: c.color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGenreTags(
    List<String> genres, {
    required WrapAlignment alignment,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: alignment,
      children: [
        for (final genre in genres)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: context.readerColors.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: context.readerColors.outlineVariant.withValues(
                  alpha: 0.24,
                ),
              ),
            ),
            child: Text(
              genre,
              style: TextStyle(
                color: context.readerColors.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDescriptionSection(ReaderItem item) {
    final l10n = AppLocalizations.of(context);
    final desc =
        item.description?.isNotEmpty == true
            ? item.description!
            : l10n.readerNoDescription;
    // 120 字符阈值：约两行半中文字（每行约 25 字），超过时显示展开按钮
    final hasLongDesc = desc.length > 120;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.readerDescription,
          style: TextStyle(
            color: context.readerColors.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8),
        Text(
          desc,
          maxLines: _showFullDescription ? null : _collapsedMaxLines,
          overflow: _showFullDescription ? null : TextOverflow.ellipsis,
          style: TextStyle(
            color: context.readerColors.onSurfaceVariant,
            fontSize: 14,
            height: 1.75,
          ),
        ),
        if (hasLongDesc)
          TextButton(
            onPressed:
                () => setState(
                  () => _showFullDescription = !_showFullDescription,
                ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(top: 6),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: context.readerColors.primary,
            ),
            child: Text(
              _showFullDescription
                  ? AppLocalizations.of(context).readerCollapse
                  : AppLocalizations.of(context).readerExpandFull,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  Widget _buildChapterSection(
    List<ReaderChapter> chapters,
    ReaderDetailLayout layout,
  ) {
    final hierarchyVisible = ReaderChapterHierarchy.visibleChapters(
      chapters,
      _collapsedVolumes,
    );
    final visibleChapters =
        _showAllChapters
            ? hierarchyVisible
            : hierarchyVisible.take(layout.previewChapterCount).toList();

    Widget chapterTile(ReaderChapter chapter) {
      return MinimalChapterTile(
        chapter: chapter,
        onTap: () => widget.onReadChapter(chapter),
        isParent: _hasChildren(chapter, chapters),
        isExpanded: !_collapsedVolumes.contains(chapter.id),
        onToggleExpand: () => _toggleVolume(chapter.id),
      );
    }

    final chapterList =
        _showAllChapters
            ? ConstrainedBox(
              constraints: BoxConstraints(maxHeight: layout.directoryMaxHeight),
              child: Scrollbar(
                controller: _chapterScrollController,
                thumbVisibility: layout.isDesktop,
                child: ListView.builder(
                  controller: _chapterScrollController,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: visibleChapters.length,
                  itemBuilder:
                      (context, index) => chapterTile(visibleChapters[index]),
                ),
              ),
            )
            : Column(
              children: [
                for (final chapter in visibleChapters) chapterTile(chapter),
              ],
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _showAllChapters = !_showAllChapters),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context).readerTableOfContents,
                  style: TextStyle(
                    color: context.readerColors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  AppLocalizations.of(
                    context,
                  ).readerTotalChapters(chapters.length),
                  style: TextStyle(
                    color: context.readerColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Icon(
                  _showAllChapters
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: context.readerColors.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: chapterList,
        ),
      ],
    );
  }
}

/// 漫画详情包装器 — 加载清单后将目录节点传递给 ComicDetailPage。
class _ComicDetailWrapper extends ConsumerWidget {
  const _ComicDetailWrapper({required this.item, required this.itemId});

  final ReaderItem item;
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitor = ref.watch(comicManifestMonitorProvider(itemId));
    final manifest = monitor.asData?.value.manifest;
    if (manifest == null && monitor.asData?.value.refreshError == null) {
      return Scaffold(
        backgroundColor: context.readerColors.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (manifest == null) {
      return Scaffold(
        backgroundColor: context.readerColors.surface,
        body: AppErrorView(
          message: AppLocalizations.of(context).readerRefreshFailed,
          onRetry: () => ref.invalidate(comicManifestMonitorProvider(itemId)),
        ),
      );
    }
    final terminal =
        manifest.importStatus != ReaderImportStatus.pending &&
        manifest.importStatus != ReaderImportStatus.parsing;
    if (terminal && item.isParsing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.invalidate(readerItemDetailProvider(itemId));
        }
      });
    }
    return ComicDetailPage(
      item: item,
      chapters: manifest.catalog,
      sources: manifest.sources,
      canRead: manifest.pages.isNotEmpty,
      parseProgress: manifest.parseTask?.progress,
      onRetrySource: (source) => _retryComicSource(context, ref, source),
      onDeleteSource: (source) => _deleteComicSource(context, ref, source),
    );
  }

  Future<bool> _retryComicSource(
    BuildContext context,
    WidgetRef ref,
    ComicSource source,
  ) async {
    final ok = await ref
        .read(readerComicServiceProvider)
        .retrySource(itemId, source.id);
    if (ok && context.mounted) {
      ref.invalidate(comicManifestMonitorProvider(itemId));
    }
    return ok;
  }

  Future<bool> _deleteComicSource(
    BuildContext context,
    WidgetRef ref,
    ComicSource source,
  ) async {
    try {
      await ref
          .read(readerComicServiceProvider)
          .deleteSource(itemId, source.id);
      if (!context.mounted) {
        return true;
      }
      ref.invalidate(comicManifestMonitorProvider(itemId));
      ref.invalidate(readerItemDetailProvider(itemId));
      await ref.read(comicManifestMonitorProvider(itemId).future);
      return true;
    } on Exception {
      return false;
    }
  }
}

class _BookPreparationScaffold extends StatelessWidget {
  const _BookPreparationScaffold({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.readerColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: AppLoading.detail()),
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                tooltip: AppLocalizations.of(context).coreBack,
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
