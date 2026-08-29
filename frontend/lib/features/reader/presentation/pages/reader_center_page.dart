import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/reader_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/core/errors/error_message.dart';
import 'package:omninest/core/widgets/app_error_view.dart';
import 'package:omninest/core/widgets/app_loading.dart';
import 'package:omninest/features/reader/application/reader_controller.dart';
import 'package:omninest/features/reader/application/reader_book_provider.dart';
import 'package:omninest/features/reader/application/reader_progress_snapshot.dart';
import 'package:omninest/features/reader/application/reader_local_progress.dart';
import 'package:omninest/features/reader/domain/reader_models.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_book_card.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_bookshelf_section.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_empty_state.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_import_section.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_metadata_section.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_notes_section.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_snack_bar.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_shell.dart';
import 'package:omninest/features/reader/presentation/reader_l10n_helpers.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_bookmark_list.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_styles.dart';
import 'package:omninest/features/reader/reader_debug_log.dart';

class ReaderCenterPage extends ConsumerStatefulWidget {
  const ReaderCenterPage({super.key});

  @override
  ConsumerState<ReaderCenterPage> createState() => _ReaderCenterPageState();
}

class _ReaderCenterPageState extends ConsumerState<ReaderCenterPage> {
  final TextEditingController _searchController = TextEditingController();
  VoidCallback? _routeListener;
  GoRouter? _router;
  DateTime _lastRefresh = DateTime.fromMillisecondsSinceEpoch(0);
  ReaderReadingStats? _stats;
  Set<String> _importingIds = const {};
  final Set<String> _reportedParseFailureIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadStats();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = GoRouter.of(context);
      _router = router;
      void listener() {
        final path = router.routeInformationProvider.value.uri.path;
        if (path == '/reader' && mounted) {
          final now = DateTime.now();
          if (now.difference(_lastRefresh).inMilliseconds > 500) {
            _lastRefresh = now;
            ref.read(readerCenterControllerProvider.notifier).refresh();
            _loadStats();
          }
        }
      }

      _routeListener = listener;
      router.routeInformationProvider.addListener(listener);
    });
  }

  @override
  void dispose() {
    if (_routeListener != null && _router != null) {
      _router!.routeInformationProvider.removeListener(_routeListener!);
    }
    _searchController.dispose();
    super.dispose();
  }

  void _reportParseTransitions(ReaderCenterState state) {
    final previousImportingIds = _importingIds;
    final parsing = state.items.where((item) => item.isParsing).toList();
    final importingIds = parsing.map((item) => item.id).toSet();
    _importingIds = importingIds;
    _reportedParseFailureIds.removeAll(importingIds);

    for (final item in state.items) {
      final failedThisRun =
          previousImportingIds.contains(item.id) &&
          !importingIds.contains(item.id) &&
          (item.isFailed || item.isPartialFailed);
      if (failedThisRun && _reportedParseFailureIds.add(item.id)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final l10n = AppLocalizations.of(context);
          final reason = item.parseErrorMessage?.trim();
          showReaderSnackBar(
            context,
            l10n.readerImportFailedWithReason(
              item.title,
              reason == null || reason.isEmpty
                  ? l10n.readerComicImportFailed
                  : reason,
            ),
            duration: const Duration(seconds: 6),
          );
        });
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats =
          await ref
              .read(readerCenterControllerProvider.notifier)
              .syncAndLoadStats();
      if (mounted) setState(() => _stats = stats);
    } on Exception catch (e) {
      readerDebugLog('ReaderCenter: stats load failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(readerImportMonitorProvider);
    final stateAsync = ref.watch(readerCenterControllerProvider);
    final state = stateAsync.asData?.value ?? ReaderCenterState.empty();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reportParseTransitions(state);
    });
    return ReaderShell(
      section: state.section,
      onSectionSelected: (section) {
        _searchController.clear();
        ref
            .read(readerCenterControllerProvider.notifier)
            .selectSection(section);
      },
      trailing: _ReaderSearchField(
        controller: _searchController,
        onChanged: (value) {
          ref
              .read(readerCenterControllerProvider.notifier)
              .setSearchQuery(value);
        },
      ),
      onSearch: (query) {
        _searchController.text = query;
        ref.read(readerCenterControllerProvider.notifier).setSearchQuery(query);
      },
      onRefresh: () async {
        await ref.read(readerCenterControllerProvider.notifier).refresh();
      },
      child: stateAsync.when(
        data:
            (data) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (data.errorMessage != null)
                  MaterialBanner(
                    content: Text(data.errorMessage!),
                    backgroundColor: context.readerColors.surfaceContainerHigh,
                    actions: [
                      TextButton(
                        onPressed:
                            () =>
                                ref
                                    .read(
                                      readerCenterControllerProvider.notifier,
                                    )
                                    .clearError(),
                        child: Text(AppLocalizations.of(context).readerClose),
                      ),
                    ],
                  ),
                _ReaderCenterContent(
                  state: data,
                  stats: _stats,
                  importingIds: _importingIds,
                  onRefresh:
                      () =>
                          ref
                              .read(readerCenterControllerProvider.notifier)
                              .refresh(),
                  onOpenItem: _onOpenItem,
                  onSectionChanged:
                      (section) => ref
                          .read(readerCenterControllerProvider.notifier)
                          .selectSection(section),
                  onSortChanged:
                      (sortBy) => ref
                          .read(readerCenterControllerProvider.notifier)
                          .setSortBy(sortBy),
                  onDeleteItem: _onDeleteItem,
                  onCancelImport: _onCancelImport,
                  onToggleBookshelf: _onToggleBookshelf,
                  onLibrarySegmentChanged:
                      (segment) => ref
                          .read(readerCenterControllerProvider.notifier)
                          .selectLibrarySegment(segment),
                ),
              ],
            ),
        error:
            (error, stackTrace) => AppErrorView(
              message: describeUserFacingError(error).displayMessage,
              onRetry: () => ref.invalidate(readerCenterControllerProvider),
            ),
        loading: () => const AppLoading.grid(gridAspectRatio: 0.72),
      ),
    );
  }

  Future<void> _onOpenItem(ReaderItem item) async {
    if (item.id.isEmpty) {
      if (mounted) {
        showReaderSnackBar(
          context,
          AppLocalizations.of(context).readerOperationFailed,
        );
      }
      return;
    }
    // 漫画先进入详情页，阅读清单就绪后再由用户进入阅读器。
    if (item.isComic) {
      context.push('/reader/items/${item.id}');
      return;
    }

    final localSnapshot = ReaderProgressSnapshot.fromLocal(
      await ReaderLocalProgress.loadLatest(item.id),
    );
    if (!mounted) {
      return;
    }
    if (localSnapshot.hasReadableProgress) {
      final chapterId = Uri.encodeComponent(localSnapshot.chapterId);
      context.push('/reader/items/${item.id}/chapters/$chapterId');
      return;
    }
    context.push('/reader/items/${item.id}');
  }

  Future<void> _onDeleteItem(ReaderItem item) async {
    try {
      await ref
          .read(readerCenterControllerProvider.notifier)
          .deleteItem(item.id);
      if (!mounted) return;
      if (mounted) {
        showReaderSnackBar(
          context,
          AppLocalizations.of(context).readerDeletedItem(item.title),
        );
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

  Future<void> _onCancelImport(ReaderItem item) async {
    try {
      await ref
          .read(readerCenterControllerProvider.notifier)
          .cancelImport(item.id);
      if (!mounted) return;
      showReaderSnackBar(
        context,
        AppLocalizations.of(context).readerImportCancelled,
      );
    } on Exception {
      if (mounted) {
        showReaderSnackBar(
          context,
          AppLocalizations.of(context).readerOperationFailed,
        );
      }
    }
  }

  Future<void> _onToggleBookshelf(ReaderItem item) async {
    try {
      final result = await ref
          .read(readerCenterControllerProvider.notifier)
          .toggleBookshelf(item.id);
      if (mounted) {
        showReaderSnackBar(
          context,
          result.addedToBookshelf
              ? AppLocalizations.of(context).readerAddedToBookshelf
              : AppLocalizations.of(context).readerRemovedFromBookshelf,
        );
      }
    } on Exception {
      if (mounted) {
        showReaderSnackBar(
          context,
          AppLocalizations.of(context).readerOperationFailed,
        );
      }
    }
  }
}

class _ReaderSearchField extends StatelessWidget {
  const _ReaderSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          color: context.readerColors.onSurface,
          fontSize: 13,
          height: 18 / 13,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: context.readerColors.surfaceContainerHigh,
          hintText: AppLocalizations.of(context).readerSearchBooksHint,
          hintStyle: TextStyle(
            color: context.readerColors.onSurfaceVariant,
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: context.readerColors.onSurfaceVariant.withValues(alpha: 0.8),
            size: 20,
          ),
          prefixIconConstraints: BoxConstraints(minWidth: 40),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide(
              color: context.readerColors.primary.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderCenterContent extends StatelessWidget {
  const _ReaderCenterContent({
    required this.state,
    required this.onRefresh,
    required this.onOpenItem,
    required this.onSectionChanged,
    required this.onSortChanged,
    required this.onDeleteItem,
    required this.onCancelImport,
    this.onToggleBookshelf,
    this.onLibrarySegmentChanged,
    this.stats,
    this.importingIds = const {},
  });

  final ReaderCenterState state;
  final VoidCallback onRefresh;
  final ReaderReadingStats? stats;
  final Set<String> importingIds;
  final ValueChanged<ReaderItem> onOpenItem;
  final ValueChanged<ReaderSection> onSectionChanged;
  final ValueChanged<ReaderSortBy> onSortChanged;
  final ValueChanged<ReaderItem> onDeleteItem;
  final ValueChanged<ReaderItem> onCancelImport;
  final ValueChanged<ReaderItem>? onToggleBookshelf;
  final ValueChanged<ReaderLibrarySegment>? onLibrarySegmentChanged;

  @override
  Widget build(BuildContext context) {
    final visibleItems = state.visibleItems;
    final isBookshelf = state.section == ReaderSection.bookshelf;
    final isBooks = state.section == ReaderSection.books;
    final overview = state.dashboard.overview;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.section != ReaderSection.metadata) ...[
          _SectionToolbar(
            section: state.section,
            itemCount: visibleItems.length,
            continueCount: overview.continueCount,
            sortBy: state.sortBy,
            onRefresh: onRefresh,
            onSortChanged: onSortChanged,
          ),
          if (isBooks) ...[
            const SizedBox(height: 12),
            _LibrarySegmentControl(
              segment: state.librarySegment,
              onChanged: onLibrarySegmentChanged,
            ),
          ],
          const SizedBox(height: 20),
        ],
        if (isBookshelf) ...[
          ReadingNowCard(
            book:
                state.continueItems.isNotEmpty
                    ? state.continueItems.first
                    : null,
            onTap:
                state.continueItems.isNotEmpty
                    ? () => onOpenItem(state.continueItems.first)
                    : null,
          ),
          if (state.continueItems.isNotEmpty) const SizedBox(height: 20),
          BookshelfGrid(
            books: visibleItems,
            onOpenItem: onOpenItem,
            onDeleteItem: onDeleteItem,
            onCancelImport: onCancelImport,
            onViewAll: () => onSectionChanged(ReaderSection.books),
            importingIds: importingIds,
          ),
          const SizedBox(height: 20),
          ReadingReportCard(stats: stats),
        ] else ...[
          if (state.section == ReaderSection.metadata) ...[
            MetadataSection(items: visibleItems),
          ] else if (state.section == ReaderSection.bookmarks) ...[
            if (state.bookmarks.isEmpty)
              ReaderEmptyState(
                title: AppLocalizations.of(context).readerNoBookmarks,
                subtitle: AppLocalizations.of(context).readerNoBookmarksHint,
                icon: Icons.bookmark_add_outlined,
              )
            else
              ReaderBookmarkList(
                bookmarks: state.bookmarks,
                items: state.items,
                onOpenItem: onOpenItem,
              ),
          ] else if (state.section == ReaderSection.notes) ...[
            ReaderNotesSection(items: state.items, onOpenItem: onOpenItem),
          ] else if (state.section == ReaderSection.imports) ...[
            ImportSection(onImported: onRefresh),
          ] else if (visibleItems.isEmpty)
            ReaderEmptyState(
              title: AppLocalizations.of(context).readerEmptyHint,
              subtitle: AppLocalizations.of(context).readerEmptyHintDesc,
              icon: Icons.library_books_outlined,
            )
          else
            _ReaderGrid(
              items: visibleItems,
              onOpenItem: onOpenItem,
              onDeleteItem: onDeleteItem,
              onToggleBookshelf: onToggleBookshelf,
            ),
        ],
      ],
    );
  }
}

/// 书库分段控件（全部 / 图书 / 漫画）
class _LibrarySegmentControl extends StatelessWidget {
  const _LibrarySegmentControl({
    required this.segment,
    required this.onChanged,
  });

  final ReaderLibrarySegment segment;
  final ValueChanged<ReaderLibrarySegment>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children:
              ReaderLibrarySegment.values.map((s) {
                final isSelected = s == segment;
                return Expanded(
                  child: GestureDetector(
                    onTap: onChanged != null ? () => onChanged!(s) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.surface
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow:
                            isSelected
                                ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                                : null,
                      ),
                      child: Text(
                        _label(context, s),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color:
                              isSelected
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  String _label(BuildContext context, ReaderLibrarySegment s) {
    final l10n = AppLocalizations.of(context);
    return switch (s) {
      ReaderLibrarySegment.all => l10n.readerSegmentAll,
      ReaderLibrarySegment.books => l10n.readerSegmentBooks,
      ReaderLibrarySegment.comics => l10n.readerSegmentComics,
    };
  }
}

class _SectionToolbar extends StatelessWidget {
  const _SectionToolbar({
    required this.section,
    required this.itemCount,
    required this.continueCount,
    required this.sortBy,
    required this.onRefresh,
    required this.onSortChanged,
  });

  final ReaderSection section;
  final int itemCount;
  final int continueCount;
  final ReaderSortBy sortBy;
  final VoidCallback onRefresh;
  final ValueChanged<ReaderSortBy> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          readerSectionLabel(AppLocalizations.of(context), section),
          style: TextStyle(
            color: context.readerColors.onSurface,
            fontSize: 22,
            height: 28 / 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(width: 14),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: context.readerColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            AppLocalizations.of(context).readerBookCount(itemCount),
            style: TextStyle(
              color: context.readerColors.onSurfaceVariant,
              fontSize: 11,
              height: 14 / 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (continueCount > 0) ...[
          SizedBox(width: 6),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: context.readerColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              AppLocalizations.of(context).readerContinueCount(continueCount),
              style: TextStyle(
                color: context.readerColors.primary,
                fontSize: 11,
                height: 14 / 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        Spacer(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: context.readerColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ReaderSortBy>(
              value: sortBy,
              isDense: true,
              icon: Icon(
                Icons.unfold_more_rounded,
                color: context.readerColors.onSurfaceVariant,
                size: 16,
              ),
              style: TextStyle(
                color: context.readerColors.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              dropdownColor: context.readerColors.surfaceContainerHigh,
              items:
                  ReaderSortBy.values
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            readerSortLabel(AppLocalizations.of(context), s),
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (v) {
                if (v != null) onSortChanged(v);
              },
            ),
          ),
        ),
        SizedBox(width: 6),
        IconButton(
          tooltip: AppLocalizations.of(context).readerRefresh,
          onPressed: onRefresh,
          icon: Icon(
            Icons.refresh_rounded,
            color: context.readerColors.onSurfaceVariant,
            size: 20,
          ),
        ),
      ],
    );
  }
}

class _ReaderGrid extends StatelessWidget {
  const _ReaderGrid({
    required this.items,
    required this.onOpenItem,
    required this.onDeleteItem,
    this.onToggleBookshelf,
  });

  final List<ReaderItem> items;
  final ValueChanged<ReaderItem> onOpenItem;
  final ValueChanged<ReaderItem> onDeleteItem;
  final ValueChanged<ReaderItem>? onToggleBookshelf;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = readerGridColumnCount(constraints.maxWidth);
        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
            childAspectRatio: readerGridChildAspectRatio(context),
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return ReaderBookCard(
              item: item,
              onTap: () => onOpenItem(item),
              onDelete: () => onDeleteItem(item),
              onToggleBookshelf:
                  onToggleBookshelf != null
                      ? () => onToggleBookshelf!(item)
                      : null,
            );
          },
        );
      },
    );
  }
}
