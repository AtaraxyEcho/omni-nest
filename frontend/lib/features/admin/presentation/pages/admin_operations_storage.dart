part of 'admin_operations_pages.dart';

class AdminStoragePage extends ConsumerWidget {
  const AdminStoragePage({required this.view, super.key});

  final AdminStorageManagementView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canManageStorage =
        ref
            .watch(authSessionProvider)
            .asData
            ?.value
            .user
            ?.permissions
            .contains('system:config:manage') ??
        false;
    final query = ref.watch(adminSearchProvider).toLowerCase();
    final filteredBuckets =
        query.isEmpty
            ? view.buckets
            : view.buckets
                .where(
                  (bucket) =>
                      bucket.name.toLowerCase().contains(query) ||
                      bucket.purpose.toLowerCase().contains(query),
                )
                .toList();
    return _PageEntrance(
      children: [
        AdminPageHeader(
          title: l10n.adminStorageManagement,
          subtitle: l10n.adminStorageManagementSubtitle,
          trailing: Wrap(
            spacing: 8,
            children: [
              IconButton.filledTonal(
                onPressed: () => ref.invalidate(adminStorageProvider),
                icon: const Icon(Icons.refresh_rounded),
                tooltip: l10n.adminRefresh,
              ),
              if (canManageStorage)
                FilledButton.tonalIcon(
                  onPressed:
                      () => showDialog<void>(
                        context: context,
                        builder:
                            (context) => _StorageLocationDialog(
                              mounts: view.trustedMounts,
                            ),
                      ),
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: Text(l10n.adminAddLocalStorageLocation),
                ),
              FilledButton.tonalIcon(
                onPressed: () async {
                  try {
                    final count =
                        await ref
                            .read(adminOperationsActionsProvider)
                            .recalculateStorage();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.adminRecalculateDone('$count')),
                        ),
                      );
                    }
                  } on Exception catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.adminLoadFailed('$e'))),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.calculate_outlined),
                label: Text(l10n.adminRecalculate),
              ),
              FilledButton.tonalIcon(
                onPressed: () async {
                  try {
                    final cleared =
                        await ref
                            .read(adminOperationsActionsProvider)
                            .rebuildSearchIndex();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.adminRebuildIndexDone('$cleared')),
                        ),
                      );
                    }
                  } on Exception catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.adminLoadFailed('$e'))),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.manage_search_rounded),
                label: Text(l10n.adminRebuildIndex),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _MetricGrid(
          children: [
            AdminMetricCard(
              title: l10n.adminBucketConfig,
              value: view.buckets.length.toString(),
              detail: l10n.adminMinioBuckets,
              icon: Icons.cloud_queue_rounded,
            ),
            AdminMetricCard(
              title: l10n.adminLocalStorageLocations,
              value: view.locations.length.toString(),
              detail: l10n.adminReadOnlyMediaMounts,
              icon: Icons.folder_copy_outlined,
            ),
          ],
        ),
        const SizedBox(height: 24),
        AdminInfoPanel(
          title: l10n.adminLocalStorageLocations,
          subtitle: l10n.adminLocalStorageLocationsSubtitle,
          children:
              view.locations.isEmpty
                  ? [_EmptyText(l10n.adminNoLocalStorageLocations)]
                  : [
                    for (final location in view.locations)
                      _StorageLocationRow(
                        location: location,
                        canManage: canManageStorage,
                      ),
                  ],
        ),
        const SizedBox(height: 24),
        AdminInfoPanel(
          title: l10n.adminObjectBuckets,
          subtitle: l10n.adminObjectBucketsSubtitle,
          children:
              filteredBuckets.isEmpty
                  ? [
                    _EmptyText(
                      query.isEmpty
                          ? l10n.adminNoBucketConfig
                          : l10n.adminNoMatch,
                    ),
                  ]
                  : [
                    for (final bucket in filteredBuckets)
                      _InfoRow(
                        leading: bucket.name,
                        middle: bucket.purpose,
                        trailing: AdminStatusPill(label: bucket.status),
                      ),
                  ],
        ),
      ],
    );
  }
}

class _StorageLocationRow extends ConsumerWidget {
  const _StorageLocationRow({required this.location, required this.canManage});

  final AdminStorageLocation location;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            location.healthStatus == 'AVAILABLE'
                ? Icons.folder_open_rounded
                : Icons.folder_off_outlined,
            color:
                location.healthStatus == 'AVAILABLE'
                    ? context.adminColors.success
                    : Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${location.mountKey} · ${location.relativeRoot} · ${location.nodeId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          AdminStatusPill(label: location.healthStatus),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: location.enabled,
            onChanged:
                canManage
                    ? (enabled) => ref
                        .read(adminOperationsActionsProvider)
                        .updateStorageLocation(
                          location: location,
                          enabled: enabled,
                        )
                    : null,
          ),
          IconButton(
            onPressed:
                canManage
                    ? () async {
                      try {
                        await ref
                            .read(adminOperationsActionsProvider)
                            .deleteStorageLocation(location.id);
                      } on Exception catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.adminLoadFailed('$error')),
                            ),
                          );
                        }
                      }
                    }
                    : null,
            tooltip: l10n.adminDeleteLocalStorageLocation,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _StorageLocationDialog extends ConsumerStatefulWidget {
  const _StorageLocationDialog({required this.mounts});

  final List<AdminTrustedMount> mounts;

  @override
  ConsumerState<_StorageLocationDialog> createState() =>
      _StorageLocationDialogState();
}

class _StorageLocationDialogState
    extends ConsumerState<_StorageLocationDialog> {
  final _nameController = TextEditingController();
  final _relativeRootController = TextEditingController(text: '.');
  String? _mountKey;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mountKey =
        widget.mounts.where((mount) => mount.available).firstOrNull?.mountKey;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relativeRootController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.adminAddLocalStorageLocation),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.adminDisplayNameLabel,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _mountKey,
              items:
                  widget.mounts
                      .map(
                        (mount) => DropdownMenuItem<String>(
                          value: mount.mountKey,
                          enabled: mount.available,
                          child: Text(
                            mount.available
                                ? mount.displayName
                                : '${mount.displayName} (${mount.mountKey})',
                          ),
                        ),
                      )
                      .toList(),
              onChanged:
                  _saving
                      ? null
                      : (value) => setState(() {
                        _mountKey = value;
                        _relativeRootController.text = '.';
                      }),
              decoration: InputDecoration(
                labelText: l10n.adminMountKey,
                helperText: l10n.adminMountKeyHint,
              ),
            ),
            if (_mountKey == null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.adminTrustedMountUnavailable,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _relativeRootController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: l10n.adminRelativeRoot,
                helperText: l10n.adminRelativeRootHint,
                suffixIcon: IconButton(
                  tooltip: l10n.adminChooseRelativeFolder,
                  onPressed:
                      _saving || _mountKey == null ? null : _chooseRelativeRoot,
                  icon: const Icon(Icons.folder_open_outlined),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.adminLocalStorageSecurityHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.adminCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child:
              _saving
                  ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Text(l10n.adminCreate),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    final mountKey = _mountKey;
    final relativeRoot = _relativeRootController.text.trim();
    if (name.isEmpty || mountKey == null || relativeRoot.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminLocalStorageRequiredFields)),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(adminOperationsActionsProvider)
          .createStorageLocation(
            name: name,
            mountKey: mountKey,
            relativeRoot: relativeRoot,
          );
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.adminLoadFailed('$error'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseRelativeRoot() async {
    final mountKey = _mountKey;
    if (mountKey == null) {
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => _MountDirectoryPickerDialog(mountKey: mountKey),
    );
    if (!mounted || selected == null) {
      return;
    }
    _relativeRootController.text = selected;
  }
}

class _MountDirectoryPickerDialog extends ConsumerStatefulWidget {
  const _MountDirectoryPickerDialog({required this.mountKey});

  final String mountKey;

  @override
  ConsumerState<_MountDirectoryPickerDialog> createState() =>
      _MountDirectoryPickerDialogState();
}

class _MountDirectoryPickerDialogState
    extends ConsumerState<_MountDirectoryPickerDialog> {
  String? _parent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final directories = ref.watch(
      adminMountDirectoriesProvider((
        mountKey: widget.mountKey,
        parent: _parent,
      )),
    );
    final current = _parent ?? '.';
    return AlertDialog(
      title: Text(l10n.adminChooseRelativeFolder),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: l10n.coreBack,
                  onPressed:
                      current == '.'
                          ? null
                          : () => setState(() {
                            final separator = current.lastIndexOf('/');
                            _parent =
                                separator < 0
                                    ? null
                                    : current.substring(0, separator);
                          }),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: SelectableText(
                    current,
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: directories.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (error, _) =>
                        Center(child: Text(l10n.adminLoadFailed('$error'))),
                data:
                    (items) =>
                        items.isEmpty
                            ? Center(child: Text(l10n.adminNoSubfolders))
                            : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final directory = items[index];
                                return ListTile(
                                  leading: const Icon(Icons.folder_outlined),
                                  title: Text(directory.name),
                                  subtitle: Text(directory.relativePath),
                                  onTap:
                                      () => Navigator.of(
                                        context,
                                      ).pop(directory.relativePath),
                                  trailing:
                                      directory.hasChildren
                                          ? IconButton(
                                            tooltip: l10n.adminOpenFolder,
                                            onPressed:
                                                () => setState(
                                                  () =>
                                                      _parent =
                                                          directory
                                                              .relativePath,
                                                ),
                                            icon: const Icon(
                                              Icons.chevron_right_rounded,
                                            ),
                                          )
                                          : null,
                                );
                              },
                            ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.adminCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(current),
          child: Text(l10n.adminUseCurrentFolder),
        ),
      ],
    );
  }
}

class AdminExternalStoragePage extends ConsumerWidget {
  const AdminExternalStoragePage({required this.view, super.key});

  final AdminExternalStorageView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final adminColors = context.adminColors;
    final query = ref.watch(adminSearchProvider).toLowerCase();
    final filtered =
        query.isEmpty
            ? view.items
            : view.items
                .where(
                  (item) =>
                      item.displayName.toLowerCase().contains(query) ||
                      item.provider.toLowerCase().contains(query),
                )
                .toList();
    return _PageEntrance(
      children: [
        AdminPageHeader(
          title: l10n.adminExternalStorageIntegration,
          subtitle: l10n.adminExternalStorageSubtitle,
          trailing: FilledButton.icon(
            onPressed:
                () => showDialog<void>(
                  context: context,
                  builder: (context) => const _ExternalStorageDialog(),
                ),
            icon: const Icon(Icons.add_link_rounded),
            label: Text(l10n.adminNewConnection),
          ),
        ),
        const SizedBox(height: 24),
        _MetricGrid(
          children: [
            AdminMetricCard(
              title: l10n.adminConnections,
              value: view.items.length.toString(),
              detail: l10n.adminExternalSources,
              icon: Icons.add_to_drive_outlined,
            ),
            AdminMetricCard(
              title: l10n.adminEnabled,
              value:
                  view.items
                      .where((item) => item.status == 'ACTIVE')
                      .length
                      .toString(),
              detail: l10n.adminSyncable,
              icon: Icons.link_rounded,
              accent: adminColors.success,
            ),
            AdminMetricCard(
              title: l10n.adminDisabled,
              value:
                  view.items
                      .where((item) => item.status == 'DISABLED')
                      .length
                      .toString(),
              detail: l10n.adminPausedSync,
              icon: Icons.link_off_rounded,
              accent: context.adminColors.tertiary,
            ),
          ],
        ),
        const SizedBox(height: 24),
        AdminInfoPanel(
          title: l10n.adminConnectionList,
          subtitle: l10n.adminConnectionListSubtitle,
          children:
              filtered.isEmpty
                  ? [
                    _EmptyText(
                      query.isEmpty
                          ? l10n.adminNoExternalStorage
                          : l10n.adminNoMatch,
                    ),
                  ]
                  : [
                    for (final item in filtered)
                      _InfoRow(
                        leading: item.displayName,
                        middle: '${item.provider}\n${item.updatedAt}',
                        trailing: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            AdminStatusPill(
                              label: item.status,
                              color:
                                  item.status == 'ACTIVE'
                                      ? adminColors.success
                                      : context.adminColors.tertiary,
                            ),
                            FilledButton.tonalIcon(
                              onPressed:
                                  () => ref
                                      .read(adminOperationsActionsProvider)
                                      .updateExternalStorageStatus(
                                        item.id,
                                        item.status == 'ACTIVE'
                                            ? 'DISABLED'
                                            : 'ACTIVE',
                                      ),
                              icon: Icon(
                                item.status == 'ACTIVE'
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              label: Text(
                                item.status == 'ACTIVE'
                                    ? l10n.adminDeactivate
                                    : l10n.adminActivate,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980 ? 3 : 1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: columns == 1 ? 3.2 : 1.7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.leading,
    required this.middle,
    required this.trailing,
  });

  final String leading;
  final String middle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.adminColors.surfaceContainerLow.withValues(
            alpha: 0.42,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.adminColors.outlineVariant.withValues(alpha: 0.18),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leading,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    middle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.adminColors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              );

              if (!isWide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    content,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerLeft, child: trailing),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: content),
                  const SizedBox(width: 18),
                  trailing,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExternalStorageDialog extends ConsumerStatefulWidget {
  const _ExternalStorageDialog();

  @override
  ConsumerState<_ExternalStorageDialog> createState() =>
      _ExternalStorageDialogState();
}

class _ExternalStorageDialogState
    extends ConsumerState<_ExternalStorageDialog> {
  final _displayNameController = TextEditingController();
  final _credentialsController = TextEditingController(text: '{}');
  String _provider = 'S3';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _displayNameController.dispose();
    _credentialsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.adminNewExternalStorage),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _provider,
              decoration: InputDecoration(labelText: l10n.adminType),
              items: [
                const DropdownMenuItem(value: 'S3', child: Text('S3')),
                const DropdownMenuItem(value: 'WEBDAV', child: Text('WebDAV')),
                const DropdownMenuItem(value: 'SMB', child: Text('SMB')),
                DropdownMenuItem(
                  value: 'LOCAL',
                  child: Text(l10n.adminLocalMount),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _provider = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _displayNameController,
              decoration: InputDecoration(
                labelText: l10n.adminDisplayNameLabel,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _credentialsController,
              decoration: InputDecoration(labelText: l10n.adminCredentialsJson),
              minLines: 3,
              maxLines: 5,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.adminColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.coreCancel),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: const Icon(Icons.add_link_rounded),
          label: Text(_submitting ? l10n.adminCreatingLabel : l10n.adminCreate),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_displayNameController.text.trim().isEmpty) {
      setState(
        () => _error = AppLocalizations.of(context).adminEnterDisplayName,
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(adminOperationsActionsProvider)
          .createExternalStorage(
            provider: _provider,
            displayName: _displayNameController.text.trim(),
            credentials: _credentialsController.text,
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.adminColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _detailText(Map<String, dynamic> detail, AppLocalizations l10n) {
  if (detail.isEmpty) {
    return l10n.adminNoDetailDiagnostics;
  }
  return detail.entries
      .map((entry) => '${entry.key}: ${entry.value}')
      .take(5)
      .join('\n');
}

Color _usageColor(double value, AdminColors adminColors) {
  if (value >= 85) {
    return adminColors.error;
  }
  if (value >= 70) {
    return adminColors.tertiary;
  }
  return adminColors.success;
}

Color _seriesColor(String metric, AdminColors adminColors) {
  return switch (metric) {
    'cpu' => adminColors.tertiary,
    'memory' => adminColors.info,
    'jvmHeap' => adminColors.primary,
    'tasks' => adminColors.success,
    _ => adminColors.onSurfaceVariant,
  };
}

/// 需要以 GB 为单位展示的字节类配置键。
const _gbValueConfigs = {'storage.quota.default', 'storage.quota.default.gb'};

const _byteToGbDisplayConfigs = {'share.max-bytes', 'shared_space.max_bytes'};

/// 将配置值格式化。
String _formatConfigValue(String key, String value) {
  if (_gbValueConfigs.contains(key)) {
    final gb = double.tryParse(value);
    return gb == null ? value : '${gb.toStringAsFixed(1)} GB';
  }
  if (!_byteToGbDisplayConfigs.contains(key)) return value;
  final bytes = int.tryParse(value) ?? 0;
  final gb = bytes / (1024 * 1024 * 1024);
  return '${gb.toStringAsFixed(1)} GB';
}

Color _statusColor(String status, AdminColors adminColors) {
  return switch (status) {
    'UP' || 'ACTIVE' || 'COMPLETED' => adminColors.success,
    'WARN' || 'FAILED' || 'DLQ' || 'DISABLED' => adminColors.error,
    'RUNNING' => adminColors.info,
    _ => adminColors.tertiary,
  };
}

// ── 会话管理页面 ──────────────────────────────────────────────────────
