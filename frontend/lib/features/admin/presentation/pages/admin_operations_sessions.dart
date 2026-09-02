part of 'admin_operations_pages.dart';

class AdminSessionsPage extends ConsumerStatefulWidget {
  const AdminSessionsPage({super.key});

  @override
  ConsumerState<AdminSessionsPage> createState() => _AdminSessionsPageState();
}

class _AdminSessionsPageState extends ConsumerState<AdminSessionsPage> {
  static const _pageSize = 20;
  static const _platforms = <String>[
    'ALL',
    'android',
    'ios',
    'web',
    'windows',
    'macos',
    'linux',
    'desktop',
  ];

  String _status = 'ALL';
  String _platform = 'ALL';
  String _query = '';
  int _page = 0;
  int _retentionDays = 30;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _query = ref.read(adminSearchProvider);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = (
      page: _page,
      size: _pageSize,
      status: _status,
      platform: _platform,
      query: _query,
    );
    final sessionsAsync = ref.watch(adminSessionPageProvider(query));
    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (_, _) => Center(
            child: Text(AppLocalizations.of(context).adminLoadFailed('')),
          ),
      data: (page) => _buildPage(context, page),
    );
  }

  Widget _buildPage(BuildContext context, AdminPage<AdminSessionItem> page) {
    final l10n = AppLocalizations.of(context);
    final colors = context.adminColors;
    final activeCount = page.items.where((session) => session.isActive).length;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminPageHeader(
          title: l10n.adminSessionManagement,
          subtitle: l10n.adminSessionManagementSubtitle,
          trailing: AdminStatusPill(
            label:
                '${l10n.adminActiveSessions}: $activeCount / ${page.totalElements}',
            color: colors.success,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _SessionFilterDropdown<String>(
              width: 190,
              label: l10n.adminFilterStatus,
              value: _status,
              items: [
                DropdownMenuItem(
                  value: 'ALL',
                  child: Text(l10n.adminSessionAllStatuses),
                ),
                DropdownMenuItem(
                  value: 'ACTIVE',
                  child: Text(l10n.adminSessionActiveOnly),
                ),
                DropdownMenuItem(
                  value: 'REVOKED',
                  child: Text(l10n.adminSessionRevokedOnly),
                ),
                DropdownMenuItem(
                  value: 'EXPIRED',
                  child: Text(l10n.adminSessionExpiredOnly),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _status = value;
                    _page = 0;
                  });
                }
              },
            ),
            _SessionFilterDropdown<String>(
              width: 190,
              label: l10n.adminFilterPlatform,
              value: _platform,
              items: [
                for (final platform in _platforms)
                  DropdownMenuItem(
                    value: platform,
                    child: Text(platform == 'ALL' ? l10n.adminAll : platform),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _platform = value;
                    _page = 0;
                  });
                }
              },
            ),
            _SessionFilterDropdown<int>(
              width: 160,
              label: '',
              value: _retentionDays,
              items: [
                for (final days in const <int>[7, 30, 90, 365])
                  DropdownMenuItem(
                    value: days,
                    child: Text(l10n.adminRetentionDays('$days')),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _retentionDays = value);
              },
            ),
            FilledButton.tonalIcon(
              onPressed: _cleanupSessions,
              icon: const Icon(Icons.cleaning_services_outlined),
              label: Text(l10n.adminCleanup),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AdminInfoPanel(
          title: l10n.adminSessionList,
          subtitle: l10n.adminSessionListSubtitle,
          children: [
            AdminDataTable(
              showIndex: true,
              indexBase: page.page * _pageSize,
              minTableWidth: 980,
              columns: [
                AdminListColumn(
                  key: 'username',
                  label: l10n.adminUsername,
                  flex: 2,
                ),
                AdminListColumn(
                  key: 'device',
                  label: l10n.adminSessionDeviceName,
                  flex: 2,
                ),
                AdminListColumn(
                  key: 'ip',
                  label: l10n.adminSessionIp,
                  minWidth: 130,
                ),
                AdminListColumn(
                  key: 'issuedAt',
                  label: l10n.adminSessionLoginTime,
                  minWidth: 150,
                ),
                AdminListColumn(
                  key: 'lastActiveAt',
                  label: l10n.adminSessionLastActive,
                  minWidth: 150,
                ),
                AdminListColumn(
                  key: 'status',
                  label: l10n.adminFilterStatus,
                  minWidth: 100,
                ),
              ],
              rowCount: page.items.length,
              emptyState: AdminListEmptyState(
                message:
                    _query.isEmpty && _status == 'ALL' && _platform == 'ALL'
                        ? l10n.adminNoSessions
                        : l10n.adminNoMatch,
              ),
              rowCellsBuilder: (context, index) {
                final session = page.items[index];
                return [
                  Text(
                    session.username ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration:
                          session.isInactive
                              ? TextDecoration.lineThrough
                              : null,
                    ),
                  ),
                  Text(
                    session.deviceName ??
                        session.deviceId ??
                        session.clientPlatform,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    session.ipAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    session.issuedAt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    session.lastActiveAt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  _sessionStatusTag(context, session),
                ];
              },
              actionsBuilder: (context, index) {
                final session = page.items[index];
                return [
                  IconButton(
                    tooltip: l10n.adminSessionDetailTitle,
                    icon: const Icon(Icons.info_outline_rounded, size: 20),
                    onPressed: () => _showSessionDetail(context, session),
                  ),
                  if (session.isActive)
                    IconButton(
                      tooltip: l10n.adminRevokeSession,
                      icon: Icon(
                        Icons.logout_rounded,
                        size: 20,
                        color: context.adminColors.error,
                      ),
                      onPressed: () => _revokeSession(session),
                    ),
                ];
              },
            ),
            const SizedBox(height: 12),
            AdminListPaginationBar(
              currentPage: page.page,
              totalPages: page.totalPages,
              totalElements: page.totalElements,
              rowsPerPage: _pageSize,
              onPageChanged: (next) => setState(() => _page = next),
              onRowsPerPageChanged: (_) {},
            ),
          ],
        ),
      ],
    );
    final useExpanded =
        !ResponsiveBreakpoints.isCompact(MediaQuery.sizeOf(context).width) &&
        MediaQuery.sizeOf(context).height >= 620;
    return useExpanded ? content : SingleChildScrollView(child: content);
  }

  AdminStatusTag _sessionStatusTag(
    BuildContext context,
    AdminSessionItem session,
  ) {
    final l10n = AppLocalizations.of(context);
    if (session.isRevoked) {
      return AdminStatusTag(
        label: l10n.adminSessionStatusRevoked,
        tone: AdminTagTone.error,
      );
    }
    if (session.isExpired) {
      return AdminStatusTag(
        label: l10n.adminSessionStatusExpired,
        tone: AdminTagTone.neutral,
      );
    }
    return AdminStatusTag(
      label: l10n.adminSessionStatusActive,
      tone: AdminTagTone.success,
    );
  }

  void _showSessionDetail(BuildContext context, AdminSessionItem session) {
    final l10n = AppLocalizations.of(context);
    final rows = <(String, String)>[
      (l10n.adminUsername, session.username ?? '-'),
      (l10n.adminSessionFieldDeviceId, session.deviceId ?? '-'),
      (l10n.adminSessionDeviceName, session.deviceName ?? '-'),
      (l10n.adminFilterPlatform, session.clientPlatform),
      (l10n.adminSessionIp, session.ipAddress),
      (l10n.adminSessionLoginTime, session.issuedAt),
      (l10n.adminSessionExpiresAt, session.expiresAt),
      (l10n.adminSessionLastActive, session.lastActiveAt),
      (l10n.adminRevokedLabel, session.revokedAt ?? '-'),
      (l10n.adminSessionRevokeReason, session.revokeReason ?? '-'),
    ];
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.adminSessionDetailTitle),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (label, value) in rows) ...[
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.adminColors.onSurfaceVariant,
                      ),
                    ),
                    Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.coreClose),
              ),
            ],
          ),
    );
  }

  Future<void> _revokeSession(AdminSessionItem session) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.adminConfirmKick),
            content: Text(
              l10n.adminConfirmKickMessage(
                session.deviceName ?? session.clientPlatform,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.coreCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.coreConfirm),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(adminOperationsActionsProvider).revokeSession(session.id);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.adminLoadFailed(''))));
    }
  }

  Future<void> _cleanupSessions() async {
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
      final count = await ref
          .read(adminOperationsActionsProvider)
          .cleanupSessions(_retentionDays);
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

class _SessionFilterDropdown<T> extends StatelessWidget {
  const _SessionFilterDropdown({
    required this.width,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final double width;
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label.isEmpty ? null : label,
          isDense: true,
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}
