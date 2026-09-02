part of 'admin_operations_pages.dart';

class AdminLogsPage extends ConsumerStatefulWidget {
  const AdminLogsPage({super.key});

  @override
  ConsumerState<AdminLogsPage> createState() => _AdminLogsPageState();
}

class _AdminLogsPageState extends ConsumerState<AdminLogsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Timer? _searchTimer;
  String _query = '';
  String _auditAction = 'ALL';
  String _loginResult = 'ALL';
  int _auditPage = 0;
  int _loginPage = 0;
  int _retentionDays = 30;

  @override
  void initState() {
    super.initState();
    _query = ref.read(adminSearchProvider);
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
    ref.listenManual<String>(adminSearchProvider, (_, next) {
      _searchTimer?.cancel();
      _searchTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() {
          _query = next.trim();
          _auditPage = 0;
          _loginPage = 0;
        });
      });
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auditQuery = (
      page: _auditPage,
      size: 20,
      action: _auditAction,
      query: _query,
    );
    final loginQuery = (
      page: _loginPage,
      size: 20,
      result: _loginResult,
      platform: 'ALL',
      query: _query,
    );
    final auditAsync = ref.watch(adminLogPageProvider(auditQuery));
    final loginAsync = ref.watch(adminLoginAuditPageProvider(loginQuery));
    final auditPage = auditAsync.asData?.value;
    final loginPage = loginAsync.asData?.value;
    final currentTotal =
        _tabController.index == 0
            ? auditPage?.totalElements ?? 0
            : loginPage?.totalElements ?? 0;
    final currentOptions =
        <String>{
            'ALL',
            ...?auditPage?.items.map((item) => item.action),
            if (_auditAction != 'ALL') _auditAction,
          }.toList()
          ..sort();

    return LayoutBuilder(
      builder: (context, constraints) {
        final l10n = AppLocalizations.of(context);
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminPageHeader(
              title: l10n.adminLogCenter,
              subtitle: l10n.adminLogCenterSubtitle,
              trailing: AdminStatusPill(
                label: l10n.adminAuditCount('$currentTotal'),
              ),
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              labelColor: context.adminColors.primary,
              unselectedLabelColor: context.adminColors.onSurfaceVariant,
              indicatorColor: context.adminColors.primary,
              tabs: [
                Tab(text: l10n.adminTabAudit),
                Tab(text: l10n.adminTabLoginLog),
              ],
            ),
            const SizedBox(height: 16),
            _AdminRecordFilterBar(
              key: ValueKey<int>(_tabController.index),
              label:
                  _tabController.index == 0
                      ? l10n.adminFilterAction
                      : l10n.adminFilterStatus,
              value: _tabController.index == 0 ? _auditAction : _loginResult,
              options:
                  _tabController.index == 0
                      ? currentOptions
                      : const <String>['ALL', 'SUCCESS', 'FAILED'],
              optionLabel: (value) {
                if (value == 'ALL') return l10n.adminAll;
                if (value == 'SUCCESS') return l10n.adminLoginSuccess;
                if (value == 'FAILED') return l10n.adminLoginFailed;
                return value;
              },
              onChanged: (value) {
                setState(() {
                  if (_tabController.index == 0) {
                    _auditAction = value;
                    _auditPage = 0;
                  } else {
                    _loginResult = value;
                    _loginPage = 0;
                  }
                });
              },
              retentionDays: _retentionDays,
              onRetentionChanged:
                  (value) => setState(() => _retentionDays = value),
              onCleanup: _cleanupCurrentLog,
            ),
            const SizedBox(height: 16),
            _buildTabView(
              _AuditLogTab(
                page: auditAsync,
                onPageChanged: (page) => setState(() => _auditPage = page),
              ),
              _LoginAuditLogTab(
                page: loginAsync,
                onPageChanged: (page) => setState(() => _loginPage = page),
              ),
              useExpanded: _useExpanded(constraints),
            ),
          ],
        );
        return _useExpanded(constraints)
            ? content
            : SingleChildScrollView(child: content);
      },
    );
  }

  bool _useExpanded(BoxConstraints constraints) {
    return !ResponsiveBreakpoints.isCompact(MediaQuery.sizeOf(context).width) &&
        (!constraints.hasBoundedHeight || constraints.maxHeight >= 620);
  }

  Widget _buildTabView(
    Widget audit,
    Widget login, {
    required bool useExpanded,
  }) {
    final tabView = TabBarView(
      controller: _tabController,
      children: [audit, login],
    );
    return useExpanded
        ? Expanded(child: tabView)
        : SizedBox(height: 520, child: tabView);
  }

  Future<void> _cleanupCurrentLog() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.adminCleanupConfirmTitle),
            content: Text(l10n.adminCleanupConfirmMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.coreCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.adminCleanup),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final actions = ref.read(adminOperationsActionsProvider);
      final count =
          _tabController.index == 0
              ? await actions.cleanupAuditLogs(_retentionDays)
              : await actions.cleanupLoginAuditLogs(_retentionDays);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminCleanupCompleted('$count'))),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.adminLoadFailed(''))));
    }
  }
}

class _AuditLogTab extends StatelessWidget {
  const _AuditLogTab({required this.page, required this.onPageChanged});

  final AsyncValue<AdminPage<AdminAuditLog>> page;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return page.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(l10n.adminLoadFailed(''))),
      data:
          (result) => SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: AdminInfoPanel(
              title: l10n.adminRecentAudit,
              subtitle: l10n.adminRecentAuditSubtitle,
              children: [
                if (result.items.isEmpty)
                  _EmptyText(l10n.adminNoAuditLogs)
                else
                  for (final item in result.items)
                    _InfoRow(
                      leading:
                          item.description.isEmpty
                              ? item.action
                              : item.description,
                      middle:
                          '${item.action} · ${item.resourceType} ${item.resourceId ?? ''}\n${item.ipAddress} · ${item.createdAt}',
                      trailing: const Icon(Icons.receipt_long_outlined),
                    ),
                const SizedBox(height: 12),
                AdminPaginationBar(
                  page: result,
                  onPrevious:
                      result.hasPrevious
                          ? () => onPageChanged(result.page - 1)
                          : null,
                  onNext:
                      result.hasNext
                          ? () => onPageChanged(result.page + 1)
                          : null,
                ),
              ],
            ),
          ),
    );
  }
}

class _LoginAuditLogTab extends StatelessWidget {
  const _LoginAuditLogTab({required this.page, required this.onPageChanged});

  final AsyncValue<AdminPage<AdminLoginAuditItem>> page;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.adminColors;
    return page.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(l10n.adminLoadFailed(''))),
      data:
          (result) => SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: AdminInfoPanel(
              title: l10n.adminLoginLog,
              subtitle: l10n.adminLoginLogSubtitle,
              children: [
                if (result.items.isEmpty)
                  _EmptyText(l10n.adminNoLoginLogs)
                else
                  for (final item in result.items)
                    _InfoRow(
                      leading:
                          item.loginResult == 'SUCCESS'
                              ? l10n.adminLoginSuccess
                              : l10n.adminLoginFailed,
                      middle:
                          '${item.username} · ${item.clientPlatform}\n${item.ipAddress} · ${item.failureReason ?? ''} · ${item.createdAt}',
                      trailing: Icon(
                        item.loginResult == 'SUCCESS'
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color:
                            item.loginResult == 'SUCCESS'
                                ? colors.success
                                : colors.error,
                      ),
                    ),
                const SizedBox(height: 12),
                AdminPaginationBar(
                  page: result,
                  onPrevious:
                      result.hasPrevious
                          ? () => onPageChanged(result.page - 1)
                          : null,
                  onNext:
                      result.hasNext
                          ? () => onPageChanged(result.page + 1)
                          : null,
                ),
              ],
            ),
          ),
    );
  }
}

class AdminTasksPage extends ConsumerStatefulWidget {
  const AdminTasksPage({super.key});

  @override
  ConsumerState<AdminTasksPage> createState() => _AdminTasksPageState();
}

class _AdminTasksPageState extends ConsumerState<AdminTasksPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Timer? _searchTimer;
  String _query = '';
  String _status = 'ALL';
  String _taskType = 'ALL';
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _query = ref.read(adminSearchProvider);
    _tabController = TabController(length: 2, vsync: this);
    ref.listenManual<String>(adminSearchProvider, (_, next) {
      _searchTimer?.cancel();
      _searchTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() {
          _query = next.trim();
          _page = 0;
        });
      });
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = (
      page: _page,
      size: 20,
      status: _status,
      taskType: _taskType,
      query: _query,
    );
    final taskAsync = ref.watch(adminTaskPageProvider(query));
    final dlqAsync = ref.watch(adminDlqProvider);
    return taskAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (_, _) => Center(
            child: Text(AppLocalizations.of(context).adminLoadFailed('')),
          ),
      data: (page) => _buildPage(context, page, dlqAsync),
    );
  }

  Widget _buildPage(
    BuildContext context,
    AdminPage<AdminTaskRecord> page,
    AsyncValue<List<AdminDlqTask>> dlqAsync,
  ) {
    final l10n = AppLocalizations.of(context);
    final colors = context.adminColors;
    final taskTypes =
        <String>{
            'ALL',
            ...page.items.map((item) => item.taskType),
            if (_taskType != 'ALL') _taskType,
          }.toList()
          ..sort();
    final failed = page.items.where((item) => item.status == 'FAILED').length;
    final running = page.items.where((item) => item.status == 'RUNNING').length;
    final useExpanded =
        !ResponsiveBreakpoints.isCompact(MediaQuery.sizeOf(context).width) &&
        MediaQuery.sizeOf(context).height >= 620;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminPageHeader(
          title: l10n.adminBackgroundTasks,
          subtitle: l10n.adminBackgroundTasksSubtitle,
          trailing: IconButton.filledTonal(
            tooltip: l10n.adminRefresh,
            onPressed: () => ref.invalidate(adminTaskPageProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            _TaskFilter(
              label: l10n.adminFilterStatus,
              value: _status,
              options: const [
                'ALL',
                'QUEUED',
                'RUNNING',
                'COMPLETED',
                'FAILED',
                'CANCELLED',
                'DLQ',
              ],
              optionLabel: (value) => value == 'ALL' ? l10n.adminAll : value,
              onChanged:
                  (value) => setState(() {
                    _status = value;
                    _page = 0;
                  }),
            ),
            _TaskFilter(
              label: l10n.adminFilterTaskType,
              value: _taskType,
              options: taskTypes,
              optionLabel: (value) => value == 'ALL' ? l10n.adminAll : value,
              onChanged:
                  (value) => setState(() {
                    _taskType = value;
                    _page = 0;
                  }),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _MetricGrid(
          children: [
            AdminMetricCard(
              title: l10n.adminTotalTasks,
              value: page.totalElements.toString(),
              detail: l10n.adminRecentTasks,
              icon: Icons.pending_actions_outlined,
            ),
            AdminMetricCard(
              title: l10n.adminRunningTasks,
              value: running.toString(),
              detail: l10n.adminCurrentPage,
              icon: Icons.play_circle_outline_rounded,
              accent: colors.info,
            ),
            AdminMetricCard(
              title: l10n.adminFailedTasks,
              value: failed.toString(),
              detail: l10n.adminCurrentPage,
              icon: Icons.error_outline_rounded,
              accent: failed == 0 ? colors.success : colors.error,
            ),
          ],
        ),
        const SizedBox(height: 20),
        TabBar(
          controller: _tabController,
          labelColor: colors.primary,
          unselectedLabelColor: colors.onSurfaceVariant,
          indicatorColor: colors.primary,
          tabs: [Tab(text: l10n.adminTaskList), Tab(text: l10n.adminDlq)],
        ),
        const SizedBox(height: 12),
        _buildTabView(
          _TaskListTab(
            page: page,
            onPageChanged: (value) => setState(() => _page = value),
            onRetry: _retryTask,
          ),
          _DlqTab(query: _query, state: dlqAsync),
          useExpanded: useExpanded,
        ),
      ],
    );
    return useExpanded ? content : SingleChildScrollView(child: content);
  }

  Widget _buildTabView(Widget tasks, Widget dlq, {required bool useExpanded}) {
    final tabView = TabBarView(
      controller: _tabController,
      children: [tasks, dlq],
    );
    return useExpanded
        ? Expanded(child: tabView)
        : SizedBox(height: 520, child: tabView);
  }

  void _retryTask(String taskId) {
    unawaited(_retryTaskAsync(taskId));
  }

  Future<void> _retryTaskAsync(String taskId) async {
    try {
      await ref.read(adminOperationsActionsProvider).retryTask(taskId);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).adminLoadFailed('')),
        ),
      );
    }
  }
}

class _TaskListTab extends StatelessWidget {
  const _TaskListTab({
    required this.page,
    required this.onPageChanged,
    required this.onRetry,
  });

  final AdminPage<AdminTaskRecord> page;
  final ValueChanged<int> onPageChanged;
  final void Function(String taskId) onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    AdminTagTone taskStatusToneFor(String status) => switch (status) {
      'COMPLETED' => AdminTagTone.success,
      'RUNNING' => AdminTagTone.info,
      'FAILED' || 'DLQ' => AdminTagTone.error,
      _ => AdminTagTone.neutral,
    };

    String taskStatusLabelFor(AppLocalizations l10n, String status) =>
        switch (status) {
          'RUNNING' => l10n.adminTaskStatusRunning,
          'COMPLETED' => l10n.adminTaskStatusCompleted,
          'DLQ' => l10n.adminTaskStatusDlq,
          'FAILED' => l10n.statusScanFailed,
          'CANCELLED' => l10n.statusScanCancelled,
          'QUEUED' => l10n.statusScanQueued,
          _ => status,
        };

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: AdminInfoPanel(
        title: l10n.adminTaskList,
        subtitle: l10n.adminTaskListSubtitle,
        children: [
          if (page.items.isEmpty)
            AdminListEmptyState(message: l10n.adminNoBackgroundTasks)
          else
            AdminDataTable(
              showIndex: true,
              indexBase: page.page * 20,
              minTableWidth: 1040,
              columns: const [
                AdminListColumn(key: 'taskType', label: '任务类型'),
                AdminListColumn(key: 'description', label: '任务名称'),
                AdminListColumn(key: 'progress', label: '进度'),
                AdminListColumn(key: 'status', label: '执行状态'),
                AdminListColumn(key: 'error', label: '错误摘要'),
                AdminListColumn(key: 'updatedAt', label: '更新时间'),
              ],
              rowCount: page.items.length,
              emptyState: AdminListEmptyState(
                message: l10n.adminNoBackgroundTasks,
              ),
              rowCellsBuilder: (context, index) {
                final item = page.items[index];
                return [
                  Text(
                    item.taskType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item.description.isEmpty ? item.id : item.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(
                    width: 110,
                    child: Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: item.progress / 100,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.progress}%',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  AdminStatusTag(
                    label: taskStatusLabelFor(l10n, item.status),
                    tone: taskStatusToneFor(item.status),
                  ),
                  Tooltip(
                    message: item.errorSummary ?? '-',
                    child: Text(
                      item.errorSummary ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    item.updatedAt,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ];
              },
              actionsBuilder:
                  (context, index) =>
                      page.items[index].canRetry
                          ? [
                            IconButton(
                              tooltip: l10n.adminRetry,
                              icon: const Icon(Icons.replay_rounded, size: 20),
                              onPressed: () => onRetry(page.items[index].id),
                            ),
                          ]
                          : const [],
            ),
          const SizedBox(height: 12),
          AdminListPaginationBar(
            currentPage: page.page,
            totalPages: page.totalPages,
            totalElements: page.totalElements,
            rowsPerPage: 20,
            onPageChanged: onPageChanged,
            onRowsPerPageChanged: (_) {},
          ),
        ],
      ),
    );
  }
}

class _TaskFilter extends StatelessWidget {
  const _TaskFilter({
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final String Function(String) optionLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          for (final option in options)
            DropdownMenuItem(value: option, child: Text(optionLabel(option))),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }
}

class _AdminRecordFilterBar extends StatelessWidget {
  const _AdminRecordFilterBar({
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    required this.retentionDays,
    required this.onRetentionChanged,
    required this.onCleanup,
    super.key,
  });

  final String label;
  final String value;
  final List<String> options;
  final String Function(String value) optionLabel;
  final ValueChanged<String> onChanged;
  final int retentionDays;
  final ValueChanged<int> onRetentionChanged;
  final VoidCallback onCleanup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(labelText: label, isDense: true),
            items: [
              for (final option in options)
                DropdownMenuItem(
                  value: option,
                  child: Text(optionLabel(option)),
                ),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<int>(
            initialValue: retentionDays,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final days in const <int>[7, 30, 90, 365])
                DropdownMenuItem(
                  value: days,
                  child: Text(l10n.adminRetentionDays('$days')),
                ),
            ],
            onChanged: (next) {
              if (next != null) onRetentionChanged(next);
            },
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: onCleanup,
          icon: const Icon(Icons.cleaning_services_outlined),
          label: Text(l10n.adminCleanup),
        ),
      ],
    );
  }
}

class _DlqTab extends StatelessWidget {
  const _DlqTab({required this.query, required this.state});

  final String query;
  final AsyncValue<List<AdminDlqTask>> state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.adminColors;
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(l10n.adminLoadFailed(''))),
      data: (items) {
        final filtered =
            query.isEmpty
                ? items
                : items.where((item) {
                  return item.taskType.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      (item.errorSummary?.toLowerCase().contains(
                            query.toLowerCase(),
                          ) ??
                          false);
                }).toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: AdminInfoPanel(
            title: l10n.adminDlq,
            subtitle: l10n.adminDlqSubtitle,
            children: [
              if (filtered.isEmpty)
                _EmptyText(
                  query.isEmpty ? l10n.adminNoDlqTasks : l10n.adminNoMatch,
                )
              else
                for (final item in filtered)
                  _InfoRow(
                    leading: item.taskType,
                    middle:
                        '${item.errorSummary ?? l10n.adminNoErrorSummary}\n${l10n.adminProgress} ${item.progress}% · ${item.updatedAt}',
                    trailing: AdminStatusPill(
                      label: item.status,
                      color: colors.error,
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}
