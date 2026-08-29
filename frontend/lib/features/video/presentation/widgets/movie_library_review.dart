part of 'movie_management.dart';

class _MediaLibraryReviewWorkspace extends ConsumerStatefulWidget {
  const _MediaLibraryReviewWorkspace({required this.source});

  final VideoLibrarySource source;

  @override
  ConsumerState<_MediaLibraryReviewWorkspace> createState() =>
      _MediaLibraryReviewWorkspaceState();
}

class _MediaLibraryReviewWorkspaceState
    extends ConsumerState<_MediaLibraryReviewWorkspace> {
  final List<MediaScanTreeNode> _ancestors = [];
  MediaScanTreeNode? _focusedNode;
  String? _runId;
  int? _selectionRevision;
  int _page = 0;
  bool _mutating = false;

  @override
  void didUpdateWidget(covariant _MediaLibraryReviewWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.id != widget.source.id) {
      _ancestors.clear();
      _focusedNode = null;
      _runId = null;
      _selectionRevision = null;
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runProvider = latestMediaScanRunProvider(widget.source.id);
    ref.listen(runProvider, (previous, next) {
      final nextRun = next.asData?.value;
      if (nextRun != null && nextRun.id != _runId && mounted) {
        setState(() {
          _runId = nextRun.id;
          _selectionRevision = nextRun.selectionRevision;
          _ancestors.clear();
          _focusedNode = null;
          _page = 0;
        });
      } else if (nextRun != null &&
          !_mutating &&
          nextRun.selectionRevision != _selectionRevision &&
          mounted) {
        setState(() => _selectionRevision = nextRun.selectionRevision);
      }
    });
    final runState = ref.watch(runProvider);
    return runState.when(
      loading: () => const _MediaLibraryLoadingSkeleton(),
      error:
          (error, _) => MovieNoticePanel(
            icon: Icons.error_outline_rounded,
            title: l10n.videoLoadTreeFailed,
            message: movieErrorMessage(error),
          ),
      data: (run) => _buildRun(context, l10n, run),
    );
  }

  Widget _buildRun(
    BuildContext context,
    AppLocalizations l10n,
    MediaScanRun? run,
  ) {
    if (run == null) {
      return MovieNoticePanel(
        icon: Icons.manage_search_rounded,
        title: l10n.videoDiscoveryTitle,
        message: l10n.videoDiscoveryEmpty,
      );
    }
    if (run.active) {
      return _MediaLibraryTaskProgress(
        run: run,
        mutating: _mutating,
        onPause: run.status == 'APPLYING' ? () => _pause(run) : null,
        onCancel: () => _cancel(run),
      );
    }
    if (run.status == 'FAILED') {
      return MovieNoticePanel(
        icon: Icons.error_outline_rounded,
        title: l10n.videoDiscoveryTitle,
        message: l10n.videoDiscoveryFailed,
      );
    }
    if (run.status == 'CANCELLED') {
      return MovieNoticePanel(
        icon: Icons.cancel_outlined,
        title: l10n.videoDiscoveryTitle,
        message: l10n.videoDiscoveryCancelled,
      );
    }

    final parentNodeId = _ancestors.isEmpty ? null : _ancestors.last.nodeId;
    final tree = ref.watch(
      mediaScanTreeProvider((
        runId: run.id,
        parentNodeId: parentNodeId,
        page: _page,
      )),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReviewSummaryBar(
          run: run,
          mutating: _mutating,
          onSelectAll: run.reviewable ? () => _toggle(run, 'ROOT', true) : null,
          onClear: run.reviewable ? () => _toggle(run, 'ROOT', false) : null,
          onApply:
              run.reviewable && run.selectedCount > 0
                  ? () => _apply(run)
                  : null,
        ),
        const SizedBox(height: 14),
        tree.when(
          loading: () => const LinearProgressIndicator(),
          error:
              (error, _) => MovieNoticePanel(
                icon: Icons.error_outline_rounded,
                title: l10n.videoLoadTreeFailed,
                message: movieErrorMessage(error),
              ),
          data: (page) => _buildTree(context, l10n, run, page),
        ),
      ],
    );
  }

  Widget _buildTree(
    BuildContext context,
    AppLocalizations l10n,
    MediaScanRun run,
    MediaPage<MediaScanTreeNode> page,
  ) {
    final list = _MediaTreeList(
      nodes: page.items,
      focusedNodeId: _focusedNode?.nodeId,
      canSelect: run.reviewable && !_mutating,
      onFocus: (node) => setState(() => _focusedNode = node),
      onOpen: (node) {
        setState(() {
          _ancestors.add(node);
          _focusedNode = null;
          _page = 0;
        });
      },
      onToggle: (node, selected) => _toggle(run, node.nodeId, selected),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReviewBreadcrumbs(
          ancestors: _ancestors,
          onRoot: () {
            setState(() {
              _ancestors.clear();
              _focusedNode = null;
              _page = 0;
            });
          },
          onAncestor: (index) {
            setState(() {
              _ancestors.removeRange(index + 1, _ancestors.length);
              _focusedNode = null;
              _page = 0;
            });
          },
        ),
        const SizedBox(height: 10),
        if (page.items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            decoration: BoxDecoration(
              color: context.videoColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l10n.videoNoCandidates,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.videoColors.onSurfaceVariant),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 760) {
                return Container(
                  decoration: BoxDecoration(
                    color: context.videoColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: list,
                );
              }
              return SizedBox(
                height: 420,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.videoColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: list,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.videoColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _MediaTreeNodeDetails(node: _focusedNode),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        if (page.totalPages > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: page.page > 0 ? () => setState(() => _page--) : null,
                tooltip: MaterialLocalizations.of(context).previousPageTooltip,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text('${page.page + 1} / ${page.totalPages}'),
              IconButton(
                onPressed:
                    page.page + 1 < page.totalPages
                        ? () => setState(() => _page++)
                        : null,
                tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _toggle(MediaScanRun run, String nodeId, bool selected) async {
    setState(() => _mutating = true);
    try {
      final summary = await ref
          .read(videoLibrarySourceActionsProvider)
          .updateSelection(
            run: run,
            nodeId: nodeId,
            selected: selected,
            expectedRevision: _selectionRevision,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _selectionRevision = summary.revision;
        _focusedNode = null;
      });
    } on Exception catch (error) {
      if (mounted) {
        showMovieFeedback(context, movieErrorMessage(error), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _mutating = false);
      }
    }
  }

  Future<void> _apply(MediaScanRun run) async {
    setState(() => _mutating = true);
    try {
      final task = await ref
          .read(videoLibrarySourceActionsProvider)
          .apply(run, expectedRevision: _selectionRevision);
      if (mounted) {
        showMovieFeedback(context, task.message);
      }
    } on Exception catch (error) {
      if (mounted) {
        showMovieFeedback(context, movieErrorMessage(error), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _mutating = false);
      }
    }
  }

  Future<void> _pause(MediaScanRun run) async {
    setState(() => _mutating = true);
    try {
      await ref.read(videoLibrarySourceActionsProvider).pause(run);
    } on Exception catch (error) {
      if (mounted) {
        showMovieFeedback(context, movieErrorMessage(error), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _mutating = false);
      }
    }
  }

  Future<void> _cancel(MediaScanRun run) async {
    setState(() => _mutating = true);
    try {
      await ref.read(videoLibrarySourceActionsProvider).cancel(run);
    } on Exception catch (error) {
      if (mounted) {
        showMovieFeedback(context, movieErrorMessage(error), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _mutating = false);
      }
    }
  }
}

class _ReviewSummaryBar extends StatelessWidget {
  const _ReviewSummaryBar({
    required this.run,
    required this.mutating,
    required this.onSelectAll,
    required this.onClear,
    required this.onApply,
  });

  final MediaScanRun run;
  final bool mutating;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClear;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final applyButton = FilledButton.icon(
      onPressed: mutating ? null : onApply,
      icon:
          mutating
              ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : const Icon(Icons.library_add_outlined),
      label: Text(l10n.videoAddSelectedToLibrary),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.videoColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.videoDiscoveryTitle,
                    style: TextStyle(
                      color: context.videoColors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.videoReviewSelectionHint,
                    style: TextStyle(
                      color: context.videoColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 12), applyButton],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 16),
                  applyButton,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _ReviewMetric(
                icon: Icons.inventory_2_outlined,
                label: l10n.videoDiscoveryCandidates(run.candidateCount),
              ),
              _ReviewMetric(
                icon: Icons.check_circle_outline_rounded,
                label: l10n.videoDiscoverySelected(run.selectedCount),
                emphasized: run.selectedCount > 0,
              ),
              _ReviewMetric(
                icon: Icons.report_problem_outlined,
                label: l10n.videoDiscoveryIssues(
                  run.conflictCount + run.unmatchedCount,
                ),
                issue: run.conflictCount + run.unmatchedCount > 0,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: mutating ? null : onSelectAll,
                icon: const Icon(Icons.select_all_rounded),
                label: Text(l10n.videoSelectAllCandidates),
              ),
              TextButton.icon(
                onPressed: mutating ? null : onClear,
                icon: const Icon(Icons.deselect_rounded),
                label: Text(l10n.videoClearCandidateSelection),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewMetric extends StatelessWidget {
  const _ReviewMetric({
    required this.icon,
    required this.label,
    this.emphasized = false,
    this.issue = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;
  final bool issue;

  @override
  Widget build(BuildContext context) {
    final color =
        issue
            ? Theme.of(context).colorScheme.error
            : emphasized
            ? context.videoColors.primary
            : context.videoColors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MediaTreeList extends StatelessWidget {
  const _MediaTreeList({
    required this.nodes,
    required this.focusedNodeId,
    required this.canSelect,
    required this.onFocus,
    required this.onOpen,
    required this.onToggle,
  });

  final List<MediaScanTreeNode> nodes;
  final String? focusedNodeId;
  final bool canSelect;
  final ValueChanged<MediaScanTreeNode> onFocus;
  final ValueChanged<MediaScanTreeNode> onOpen;
  final void Function(MediaScanTreeNode node, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: nodes.length,
      separatorBuilder:
          (_, _) => Divider(
            height: 1,
            indent: 54,
            color: context.videoColors.outlineVariant.withValues(alpha: 0.2),
          ),
      itemBuilder: (context, index) {
        final node = nodes[index];
        final selected = node.selectionState == 'ALL';
        final partial = node.selectionState == 'PARTIAL';
        final focused = focusedNodeId == node.nodeId;
        return Material(
          color:
              focused
                  ? context.videoColors.primaryContainer
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: ListTile(
            minTileHeight: 56,
            contentPadding: const EdgeInsetsDirectional.fromSTEB(8, 2, 6, 2),
            onTap: () => onFocus(node),
            leading: Checkbox(
              tristate: true,
              value: partial ? null : selected,
              onChanged:
                  canSelect
                      ? (value) => onToggle(node, value ?? !selected)
                      : null,
            ),
            title: Row(
              children: [
                Icon(
                  _mediaTreeNodeIcon(node.nodeType),
                  size: 18,
                  color:
                      focused
                          ? context.videoColors.onPrimaryContainer
                          : context.videoColors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          focused
                              ? context.videoColors.onPrimaryContainer
                              : context.videoColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              node.subtitle?.trim().isNotEmpty == true
                  ? node.subtitle!
                  : AppLocalizations.of(
                    context,
                  ).videoDiscoveryCandidates(node.candidateCount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    focused
                        ? context.videoColors.onPrimaryContainer.withValues(
                          alpha: 0.76,
                        )
                        : context.videoColors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!node.hasChildren || node.issueCount > 0)
                  _CandidateStatusBadge(status: node.matchStatus),
                if (node.hasChildren) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => onOpen(node),
                    tooltip: node.title,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MediaTreeNodeDetails extends StatelessWidget {
  const _MediaTreeNodeDetails({required this.node});

  final MediaScanTreeNode? node;

  @override
  Widget build(BuildContext context) {
    final current = node;
    if (current == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 36,
              color: context.videoColors.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context).videoCandidateDetailsHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.videoColors.onSurfaceVariant,
                fontSize: 12,
                height: 17 / 12,
              ),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.videoColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _mediaTreeNodeIcon(current.nodeType),
                  color: context.videoColors.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  current.title,
                  style: TextStyle(
                    color: context.videoColors.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CandidateStatusBadge(status: current.matchStatus),
              _DetailCountBadge(
                icon: Icons.inventory_2_outlined,
                label: AppLocalizations.of(
                  context,
                ).videoDiscoveryCandidates(current.candidateCount),
              ),
              if (current.issueCount > 0)
                _DetailCountBadge(
                  icon: Icons.report_problem_outlined,
                  label: AppLocalizations.of(
                    context,
                  ).videoDiscoveryIssues(current.issueCount),
                  issue: true,
                ),
            ],
          ),
          if (current.subtitle != null) ...[
            const SizedBox(height: 16),
            SelectableText(
              current.subtitle!,
              style: TextStyle(
                color: context.videoColors.onSurfaceVariant,
                height: 20 / 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailCountBadge extends StatelessWidget {
  const _DetailCountBadge({
    required this.icon,
    required this.label,
    this.issue = false,
  });

  final IconData icon;
  final String label;
  final bool issue;

  @override
  Widget build(BuildContext context) {
    final color =
        issue
            ? Theme.of(context).colorScheme.error
            : context.videoColors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
