/// Admin 通用列表组件集：筛选栏、数据表格、分页条、状态标签。
///
/// 四个列表页（会话/任务/日志/配置）共用同一套组件，保证交互
/// 与视觉词汇一致；行高固定以支持"横向滚动 + 右侧固定操作列"。
library;

import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';

/// 状态标签语义色。
enum AdminTagTone { success, warning, error, info, neutral }

/// 语义色对应的标签配色。
extension AdminTagToneColor on AdminTagTone {
  Color foreground(BuildContext context) => switch (this) {
    AdminTagTone.success => Colors.green.shade700,
    AdminTagTone.warning => Colors.orange.shade800,
    AdminTagTone.error => Theme.of(context).colorScheme.error,
    AdminTagTone.info => Theme.of(context).colorScheme.primary,
    AdminTagTone.neutral => Theme.of(context).colorScheme.outline,
  };

  Color background(BuildContext context) => switch (this) {
    AdminTagTone.success => Colors.green.shade50,
    AdminTagTone.warning => Colors.orange.shade50,
    AdminTagTone.error => Theme.of(
      context,
    ).colorScheme.error.withValues(alpha: 0.08),
    AdminTagTone.info => Theme.of(
      context,
    ).colorScheme.primary.withValues(alpha: 0.08),
    AdminTagTone.neutral =>
      Theme.of(context).colorScheme.surfaceContainerHighest,
  };
}

/// 语义化状态标签。
class AdminStatusTag extends StatelessWidget {
  const AdminStatusTag({
    required this.label,
    this.tone = AdminTagTone.neutral,
    super.key,
  });

  final String label;
  final AdminTagTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tone.background(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tone.foreground(context),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 列表列定义。
class AdminListColumn {
  const AdminListColumn({
    required this.key,
    required this.label,
    this.flex = 1,
    this.minWidth,
    this.sortable = false,
    this.numeric = false,
  });

  /// 列标识（排序回调与取值键共用）。
  final String key;
  final String label;

  /// 弹性宽度权重；设置 [minWidth] 时按最小宽度参与横向滚动分配。
  final int flex;
  final double? minWidth;
  final bool sortable;
  final bool numeric;
}

/// 服务端排序状态。
class AdminListSort {
  const AdminListSort({required this.columnKey, required this.ascending});

  final String columnKey;
  final bool ascending;
}

/// 筛选栏：关键词 + 组合筛选控件 + 可选的展开/收起。
class AdminFilterBar extends StatelessWidget {
  const AdminFilterBar({
    required this.keyword,
    required this.onKeywordChanged,
    this.filterChildren = const <Widget>[],
    this.trailing,
    this.collapsible = false,
    this.expanded = true,
    this.onToggleExpanded,
    super.key,
  });

  final String keyword;
  final ValueChanged<String> onKeywordChanged;
  final List<Widget> filterChildren;
  final List<Widget>? trailing;

  /// 是否提供展开/收起能力；收起时仅显示关键词与前两个筛选项。
  final bool collapsible;
  final bool expanded;
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final visibleFilters =
        collapsible && !expanded
            ? filterChildren.take(2).toList()
            : filterChildren;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: TextField(
            controller: TextEditingController(text: keyword),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              hintText: AppLocalizations.of(context).adminSearchHint,
            ),
            onSubmitted: onKeywordChanged,
            onChanged: onKeywordChanged,
          ),
        ),
        ...visibleFilters,
        if (collapsible)
          TextButton.icon(
            onPressed: onToggleExpanded,
            icon: Icon(
              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 18,
            ),
            label: Text(
              expanded
                  ? AppLocalizations.of(context).adminListCollapseFilters
                  : AppLocalizations.of(context).adminListExpandFilters,
            ),
          ),
        if (trailing != null) ...trailing!,
      ],
    );
  }
}

/// 高密度数据表格：固定行高、横向滚动、右侧固定操作列、可选多选列、
/// 可排序表头。行内容与操作列由调用方以 builder 提供。
class AdminDataTable extends StatelessWidget {
  const AdminDataTable({
    required this.columns,
    required this.rowCount,
    required this.rowCellsBuilder,
    this.actionsBuilder,
    this.showCheckboxes = false,
    this.isChecked,
    this.onRowCheck,
    this.allChecked = false,
    this.someChecked = false,
    this.onCheckAll,
    this.sort,
    this.onSort,
    this.showIndex = false,
    this.indexBase = 0,
    this.minTableWidth = 860,
    this.actionColumnWidth = 168,
    this.rowHeight = 48,
    this.emptyState,
    super.key,
  }) : assert(
         !showCheckboxes || (isChecked != null && onRowCheck != null),
         'showCheckboxes 需要同时提供 isChecked 与 onRowCheck',
       );

  final List<AdminListColumn> columns;
  final int rowCount;
  final List<Widget> Function(BuildContext context, int index) rowCellsBuilder;

  /// 操作列内容（每行一组操作控件）；为空时不渲染操作列。
  final List<Widget> Function(BuildContext context, int index)? actionsBuilder;

  final bool showCheckboxes;
  final bool Function(int index)? isChecked;
  final void Function(int index, bool value)? onRowCheck;
  final bool allChecked;
  final bool someChecked;
  final void Function(bool value)? onCheckAll;

  final AdminListSort? sort;
  final void Function(String columnKey, bool ascending)? onSort;

  /// 是否在首列渲染序号列。
  final bool showIndex;

  /// 序号基数：服务端分页下传入（页码 × 每页条数），行号 = 基数 + 行序 + 1。
  final int indexBase;

  /// 主表最小宽度（低于该宽度出现横向滚动条）。
  final double minTableWidth;
  final double actionColumnWidth;
  final double rowHeight;
  final Widget? emptyState;

  bool get _hasActionColumn => actionsBuilder != null;

  /// 序号列固定宽度。
  static const _indexColumnWidth = 64.0;

  @override
  Widget build(BuildContext context) {
    if (rowCount == 0 && emptyState != null) {
      return emptyState!;
    }
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;

    // 列宽解析：声明 minWidth 的列按固定宽计入；弹性列按 flex 分配
    // 剩余宽度（表宽取 minTableWidth 与固定宽之和的较大者）。
    var fixedTotal = showIndex ? _indexColumnWidth : 0.0;
    var flexTotal = 0;
    for (final column in columns) {
      if (column.minWidth != null) {
        fixedTotal += column.minWidth!;
      } else {
        flexTotal += column.flex;
      }
    }
    final tableWidth = fixedTotal > minTableWidth ? fixedTotal : minTableWidth;
    final remaining = tableWidth - fixedTotal;
    double columnWidth(AdminListColumn column) {
      if (column.minWidth != null) {
        return column.minWidth!;
      }
      return flexTotal == 0 ? 0 : remaining * (column.flex / flexTotal);
    }

    Widget headerMainTable = _buildHeaderTable(
      context,
      colors,
      columnWidth,
      l10n: l10n,
    );
    Widget rowsMainTable = _buildRowsTable(context, colors, columnWidth);

    if (_hasActionColumn) {
      headerMainTable = _withActionCell(
        headerMainTable,
        showCheckboxes
            ? Checkbox(
              tristate: true,
              value: allChecked ? true : (someChecked ? null : false),
              onChanged: (value) => onCheckAll?.call(value == true),
            )
            : Text(l10n.adminListActions, style: _headerStyle(context, colors)),
        colors,
      );
      rowsMainTable = _withActionCell(
        rowsMainTable,
        _buildActionCells(context),
        colors,
      );
    }

    // 滚动内容宽度 = 主表宽 + 固定操作列宽，否则操作列溢出被裁剪
    final scrollContentWidth =
        tableWidth + (_hasActionColumn ? actionColumnWidth : 0);
    Widget scrollable(Widget child) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: scrollContentWidth, child: child),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: scrollable(headerMainTable),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: colors.outlineVariant),
              right: BorderSide(color: colors.outlineVariant),
              bottom: BorderSide(color: colors.outlineVariant),
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(10),
            ),
          ),
          child: scrollable(rowsMainTable),
        ),
      ],
    );
  }

  /// 主表右侧拼接固定操作列单元。
  Widget _withActionCell(Widget table, Widget actionCell, ColorScheme colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: table),
        Container(
          width: actionColumnWidth,
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: colors.outlineVariant)),
          ),
          alignment: Alignment.topCenter,
          child: actionCell,
        ),
      ],
    );
  }

  TextStyle? _headerStyle(BuildContext context, ColorScheme colors) =>
      Theme.of(context).textTheme.labelLarge?.copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w700,
      );

  Widget _buildHeaderTable(
    BuildContext context,
    ColorScheme colors,
    double Function(AdminListColumn column) columnWidth, {
    required AppLocalizations l10n,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showIndex)
          SizedBox(
            width: _indexColumnWidth,
            height: 44,
            child: Align(
              child: Text(
                l10n.adminListIndex,
                style: _headerStyle(context, colors),
              ),
            ),
          ),
        for (final column in columns)
          SizedBox(
            width: columnWidth(column),
            height: 44,
            child: Align(
              alignment:
                  column.numeric ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _headerChild(context, column, colors, l10n),
              ),
            ),
          ),
      ],
    );
  }

  Widget _headerChild(
    BuildContext context,
    AdminListColumn column,
    ColorScheme colors,
    AppLocalizations l10n,
  ) {
    if (!column.sortable) {
      return Text(column.label, style: _headerStyle(context, colors));
    }
    final isSorted = sort?.columnKey == column.key;
    final ascending = isSorted ? sort!.ascending : false;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => onSort?.call(column.key, isSorted ? !ascending : true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(column.label, style: _headerStyle(context, colors)),
          Icon(
            isSorted
                ? (ascending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 14,
            color: isSorted ? colors.primary : colors.outline,
          ),
        ],
      ),
    );
  }

  Widget _buildRowsTable(
    BuildContext context,
    ColorScheme colors,
    double Function(AdminListColumn column) columnWidth,
  ) {
    final cellsByRow = <int, List<Widget>>{
      for (var i = 0; i < rowCount; i++) i: rowCellsBuilder(context, i),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rowCount; i++)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (showIndex)
                    SizedBox(
                      width: _indexColumnWidth,
                      height: rowHeight,
                      child: Align(
                        child: Text(
                          '${indexBase + i + 1}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  for (final column in columns)
                    SizedBox(
                      width: columnWidth(column),
                      height: rowHeight,
                      child: Align(
                        alignment:
                            column.numeric
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: cellsByRow[i]![columns.indexOf(column)],
                        ),
                      ),
                    ),
                ],
              ),
              Divider(height: 1, color: colors.outlineVariant),
            ],
          ),
      ],
    );
  }

  Widget _buildActionCells(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < rowCount; i++)
          Column(
            children: [
              SizedBox(
                height: rowHeight,
                child: Align(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actionsBuilder!(context, i),
                  ),
                ),
              ),
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ],
          ),
      ],
    );
  }
}

class AdminPaginationBar extends StatelessWidget {
  const AdminPaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalElements,
    required this.rowsPerPage,
    required this.onPageChanged,
    required this.onRowsPerPageChanged,
    super.key,
  });

  final int currentPage;
  final int totalPages;
  final int totalElements;
  final int rowsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onRowsPerPageChanged;

  static const _rowsPerPageChoices = [10, 20, 50, 100];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Text('$totalElements', style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(
            l10n.adminListRowsPerPage,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: rowsPerPage,
            items: [
              for (final choice in _rowsPerPageChoices)
                DropdownMenuItem(value: choice, child: Text('$choice')),
            ],
            onChanged: (value) {
              if (value != null) {
                onRowsPerPageChanged(value);
              }
            },
            underline: const SizedBox.shrink(),
            isDense: true,
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed:
                currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: l10n.adminListPrevPage,
          ),
          Text(
            l10n.adminListPageOf(currentPage + 1, totalPages),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          IconButton(
            onPressed:
                currentPage < totalPages - 1
                    ? () => onPageChanged(currentPage + 1)
                    : null,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: l10n.adminListNextPage,
          ),
        ],
      ),
    );
  }
}

/// 列表空态：左对齐行式提示（符合 admin 页面布局惯例）。
class AdminListEmptyState extends StatelessWidget {
  const AdminListEmptyState({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
