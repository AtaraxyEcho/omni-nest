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
  AdminListSort _auditSort = const AdminListSort(
    columnKey: 'createdAt',
    ascending: false,
  );
  AdminListSort _loginSort = const AdminListSort(
    columnKey: 'createdAt',
    ascending: false,
  );
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
      sort: _auditSort.columnKey,
      dir: _auditSort.ascending ? 'asc' : 'desc',
    );
    final loginQuery = (
      page: _loginPage,
      size: 20,
      result: _loginResult,
      platform: 'ALL',
      query: _query,
      sort: _loginSort.columnKey,
      dir: _loginSort.ascending ? 'asc' : 'desc',
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
              onExport: _exportCurrentPageAsCsv,
            ),
            const SizedBox(height: 16),
            _buildTabView(
              _AuditLogTab(
                page: auditAsync,
                onPageChanged: (page) => setState(() => _auditPage = page),
                sort: _auditSort,
                onSort: (key, ascending) {
                  setState(() {
                    _auditSort = AdminListSort(
                      columnKey: key,
                      ascending: ascending,
                    );
                    _auditPage = 0;
                  });
                },
              ),
              _LoginAuditLogTab(
                page: loginAsync,
                onPageChanged: (page) => setState(() => _loginPage = page),
                sort: _loginSort,
                onSort: (key, ascending) {
                  setState(() {
                    _loginSort = AdminListSort(
                      columnKey: key,
                      ascending: ascending,
                    );
                    _loginPage = 0;
                  });
                },
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

  /// 将当前激活 Tab 的当前页导出为 CSV 文件。
  Future<void> _exportCurrentPageAsCsv() async {
    final l10n = AppLocalizations.of(context);
    final isAudit = _tabController.index == 0;
    final suggestedName =
        isAudit ? 'omninest-audit-logs.csv' : 'omninest-login-audits.csv';
    try {
      final csv = isAudit ? _buildAuditCsv(l10n) : _buildLoginCsv(l10n);
      final savedPath = await saveAdminCsvToDisk(
        suggestedName: suggestedName,
        csv: csv,
      );
      if (!mounted || savedPath == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.adminCsvExported)));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.adminOperationFailed)));
    }
  }

  String _buildAuditCsv(AppLocalizations l10n) {
    final pageData =
        ref
            .read(
              adminLogPageProvider((
                page: _auditPage,
                size: 20,
                action: _auditAction,
                query: _query,
                sort: _auditSort.columnKey,
                dir: _auditSort.ascending ? 'asc' : 'desc',
              )),
            )
            .asData
            ?.value;
    final items = pageData?.items ?? const <AdminAuditLog>[];
    return adminCsvDocument(
      header: [
        l10n.adminFilterAction,
        l10n.adminLogContent,
        l10n.adminResourceType,
        l10n.adminSessionIp,
        l10n.adminLogTime,
      ],
      rows: [
        for (final item in items)
          [
            item.action,
            item.description.isEmpty ? item.action : item.description,
            item.resourceType,
            item.ipAddress,
            item.createdAt,
          ],
      ],
    );
  }

  String _buildLoginCsv(AppLocalizations l10n) {
    final pageData =
        ref
            .read(
              adminLoginAuditPageProvider((
                page: _loginPage,
                size: 20,
                result: _loginResult,
                platform: 'ALL',
                query: _query,
                sort: _loginSort.columnKey,
                dir: _loginSort.ascending ? 'asc' : 'desc',
              )),
            )
            .asData
            ?.value;
    final items = pageData?.items ?? const <AdminLoginAuditItem>[];
    return adminCsvDocument(
      header: [
        l10n.adminUsername,
        l10n.adminFilterStatus,
        l10n.adminFilterPlatform,
        l10n.adminSessionIp,
        l10n.adminLoginFailureReason,
        l10n.adminLogTime,
      ],
      rows: [
        for (final item in items)
          [
            item.username,
            item.loginResult == 'SUCCESS'
                ? l10n.adminLoginSuccess
                : l10n.adminLoginFailed,
            item.clientPlatform,
            item.ipAddress,
            item.failureReason ?? '',
            item.createdAt,
          ],
      ],
    );
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
  const _AuditLogTab({
    required this.page,
    required this.onPageChanged,
    required this.sort,
    required this.onSort,
  });

  final AsyncValue<AdminPage<AdminAuditLog>> page;
  final ValueChanged<int> onPageChanged;
  final AdminListSort sort;
  final void Function(String columnKey, bool ascending) onSort;

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
                AdminDataTable(
                  showIndex: true,
                  indexBase: result.page * 20,
                  minTableWidth: 960,
                  columns: [
                    AdminListColumn(
                      key: 'action',
                      label: l10n.adminFilterAction,
                      minWidth: 160,
                      sortable: true,
                    ),
                    AdminListColumn(
                      key: 'content',
                      label: l10n.adminLogContent,
                      flex: 2,
                    ),
                    AdminListColumn(
                      key: 'resourceType',
                      label: l10n.adminResourceType,
                      minWidth: 110,
                    ),
                    AdminListColumn(
                      key: 'ip',
                      label: l10n.adminSessionIp,
                      minWidth: 130,
                    ),
                    AdminListColumn(
                      key: 'createdAt',
                      label: l10n.adminLogTime,
                      minWidth: 150,
                      sortable: true,
                    ),
                  ],
                  sort: sort,
                  onSort: onSort,
                  rowCount: result.items.length,
                  emptyState: AdminListEmptyState(
                    message: l10n.adminNoAuditLogs,
                  ),
                  rowCellsBuilder: (context, index) {
                    final item = result.items[index];
                    return [
                      Text(
                        item.action,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        item.description.isEmpty
                            ? item.action
                            : item.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item.resourceType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item.ipAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        item.createdAt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ];
                  },
                ),
                const SizedBox(height: 12),
                AdminListPaginationBar(
                  currentPage: result.page,
                  totalPages: result.totalPages,
                  totalElements: result.totalElements,
                  rowsPerPage: 20,
                  onPageChanged: onPageChanged,
                  onRowsPerPageChanged: (_) {},
                ),
              ],
            ),
          ),
    );
  }
}

class _LoginAuditLogTab extends StatelessWidget {
  const _LoginAuditLogTab({
    required this.page,
    required this.onPageChanged,
    required this.sort,
    required this.onSort,
  });

  final AsyncValue<AdminPage<AdminLoginAuditItem>> page;
  final ValueChanged<int> onPageChanged;
  final AdminListSort sort;
  final void Function(String columnKey, bool ascending) onSort;

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
              title: l10n.adminLoginLog,
              subtitle: l10n.adminLoginLogSubtitle,
              children: [
                AdminDataTable(
                  showIndex: true,
                  indexBase: result.page * 20,
                  minTableWidth: 960,
                  columns: [
                    AdminListColumn(
                      key: 'username',
                      label: l10n.adminUsername,
                      flex: 2,
                      sortable: true,
                    ),
                    AdminListColumn(
                      key: 'result',
                      label: l10n.adminFilterStatus,
                      minWidth: 100,
                    ),
                    AdminListColumn(
                      key: 'platform',
                      label: l10n.adminFilterPlatform,
                      minWidth: 100,
                    ),
                    AdminListColumn(
                      key: 'ip',
                      label: l10n.adminSessionIp,
                      minWidth: 130,
                    ),
                    AdminListColumn(
                      key: 'failureReason',
                      label: l10n.adminLoginFailureReason,
                      flex: 2,
                    ),
                    AdminListColumn(
                      key: 'createdAt',
                      label: l10n.adminLogTime,
                      minWidth: 150,
                      sortable: true,
                    ),
                  ],
                  sort: sort,
                  onSort: onSort,
                  rowCount: result.items.length,
                  emptyState: AdminListEmptyState(
                    message: l10n.adminNoLoginLogs,
                  ),
                  rowCellsBuilder: (context, index) {
                    final item = result.items[index];
                    final success = item.loginResult == 'SUCCESS';
                    return [
                      Text(
                        item.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      AdminStatusTag(
                        label:
                            success
                                ? l10n.adminLoginSuccess
                                : l10n.adminLoginFailed,
                        tone:
                            success ? AdminTagTone.success : AdminTagTone.error,
                      ),
                      Text(
                        item.clientPlatform,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item.ipAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        item.failureReason ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        item.createdAt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ];
                  },
                ),
                const SizedBox(height: 12),
                AdminListPaginationBar(
                  currentPage: result.page,
                  totalPages: result.totalPages,
                  totalElements: result.totalElements,
                  rowsPerPage: 20,
                  onPageChanged: onPageChanged,
                  onRowsPerPageChanged: (_) {},
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
  AdminListSort _taskSort = const AdminListSort(
    columnKey: 'updatedAt',
    ascending: false,
  );

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
      sort: _taskSort.columnKey,
      dir: _taskSort.ascending ? 'asc' : 'desc',
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
            sort: _taskSort,
            onSort: (key, ascending) {
              setState(() {
                _taskSort = AdminListSort(columnKey: key, ascending: ascending);
                _page = 0;
              });
            },
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
    required this.sort,
    required this.onSort,
  });

  final AdminPage<AdminTaskRecord> page;
  final ValueChanged<int> onPageChanged;
  final void Function(String taskId) onRetry;
  final AdminListSort sort;
  final void Function(String columnKey, bool ascending) onSort;

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
              columns: [
                AdminListColumn(
                  key: 'taskType',
                  label: l10n.adminFilterTaskType,
                  sortable: true,
                ),
                AdminListColumn(key: 'description', label: l10n.adminTaskName),
                AdminListColumn(
                  key: 'progress',
                  label: l10n.adminProgress,
                  sortable: true,
                ),
                AdminListColumn(
                  key: 'status',
                  label: l10n.adminTaskExecutionStatus,
                  sortable: true,
                ),
                AdminListColumn(
                  key: 'error',
                  label: l10n.adminTaskErrorSummary,
                ),
                AdminListColumn(
                  key: 'updatedAt',
                  label: l10n.adminTaskUpdatedAt,
                  sortable: true,
                ),
              ],
              sort: sort,
              onSort: onSort,
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
    required this.onExport,
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
  final VoidCallback onExport;

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
        FilledButton.tonalIcon(
          onPressed: onExport,
          icon: const Icon(Icons.file_download_outlined),
          label: Text(l10n.adminListExportCsv),
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
