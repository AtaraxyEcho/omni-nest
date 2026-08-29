part of 'admin_operations_pages.dart';

class AdminSessionsPage extends ConsumerStatefulWidget {
  const AdminSessionsPage({super.key});

  @override
  ConsumerState<AdminSessionsPage> createState() => _AdminSessionsPageState();
}

class _AdminSessionsPageState extends ConsumerState<AdminSessionsPage> {
  static const _pageSize = 25;
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
    final inactiveCount =
        page.items.where((session) => session.isInactive).length;
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
        const SizedBox(height: 24),
        _MetricGrid(
          children: [
            AdminMetricCard(
              title: l10n.adminActiveSessionCount,
              value: activeCount.toString(),
              detail: l10n.adminCurrentPage,
              icon: Icons.devices_rounded,
              accent: colors.success,
            ),
            AdminMetricCard(
              title: l10n.adminRevokedCount,
              value: inactiveCount.toString(),
              detail: l10n.adminCurrentPage,
              icon: Icons.block_rounded,
              accent: colors.error,
            ),
          ],
        ),
        const SizedBox(height: 24),
        WorkbenchPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.adminSessionList,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  height: 28 / 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.adminSessionListSubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  height: 20 / 13,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _buildFilters(context),
              const SizedBox(height: 16),
              if (page.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      _query.isEmpty && _status == 'ALL' && _platform == 'ALL'
                          ? l10n.adminNoSessions
                          : l10n.adminNoMatch,
                    ),
                  ),
                )
              else
                for (final session in page.items) ...[
                  _SessionTile(
                    session: session,
                    onRevoke:
                        session.isActive ? () => _revokeSession(session) : null,
                  ),
                  if (session != page.items.last) const Divider(height: 1),
                ],
              const SizedBox(height: 12),
              AdminPaginationBar(
                page: page,
                onPrevious:
                    page.hasPrevious
                        ? () => setState(() => _page = page.page - 1)
                        : null,
                onNext:
                    page.hasNext
                        ? () => setState(() => _page = page.page + 1)
                        : null,
              ),
            ],
          ),
        ),
      ],
    );
    final useExpanded =
        !ResponsiveBreakpoints.isCompact(MediaQuery.sizeOf(context).width) &&
        MediaQuery.sizeOf(context).height >= 620;
    return useExpanded ? content : SingleChildScrollView(child: content);
  }

  Widget _buildFilters(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: InputDecoration(
              labelText: l10n.adminFilterStatus,
              isDense: true,
            ),
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
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String>(
            initialValue: _platform,
            decoration: InputDecoration(
              labelText: l10n.adminFilterPlatform,
              isDense: true,
            ),
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
        ),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<int>(
            initialValue: _retentionDays,
            decoration: const InputDecoration(isDense: true),
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
        ),
        FilledButton.tonalIcon(
          onPressed: _cleanupSessions,
          icon: const Icon(Icons.cleaning_services_outlined),
          label: Text(l10n.adminCleanup),
        ),
      ],
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

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, this.onRevoke});

  final AdminSessionItem session;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final platformIcon = switch (session.clientPlatform) {
      'web' => Icons.language_rounded,
      'android' => Icons.phone_android_rounded,
      'ios' => Icons.phone_iphone_rounded,
      'desktop' || 'windows' || 'linux' || 'macos' => Icons.computer_rounded,
      _ => Icons.device_unknown_rounded,
    };
    final statusLabel =
        session.isRevoked
            ? l10n.adminRevokedLabel
            : session.isExpired
            ? l10n.adminExpiredLabel
            : l10n.adminSessionActiveOnly;
    return ListTile(
      leading: Icon(
        platformIcon,
        color:
            session.isInactive
                ? context.adminColors.onSurfaceVariant
                : context.adminColors.primary,
      ),
      title: Text(
        '${session.username ?? ''} · ${session.deviceName ?? session.clientPlatform}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          decoration: session.isInactive ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        '${session.ipAddress} · ${session.clientPlatform} · $statusLabel\n'
        '${session.expiresAt}',
      ),
      trailing:
          onRevoke == null
              ? null
              : IconButton(
                icon: Icon(
                  Icons.logout_rounded,
                  color: context.adminColors.error,
                ),
                tooltip: l10n.adminRevokeSession,
                onPressed: onRevoke,
              ),
    );
  }
}
