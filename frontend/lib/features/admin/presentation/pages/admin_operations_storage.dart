part of 'admin_operations_pages.dart';

enum _StorageStatusFilter { all, enabled, disabled, unhealthy }

bool _storageHealthy(AdminStorageLocation location) =>
    location.healthStatus.toUpperCase() == 'HEALTHY';

class AdminStoragePage extends ConsumerStatefulWidget {
  const AdminStoragePage({required this.view, super.key});

  final AdminStorageManagementView view;

  @override
  ConsumerState<AdminStoragePage> createState() => _AdminStoragePageState();
}

class _AdminStoragePageState extends ConsumerState<AdminStoragePage> {
  _StorageStatusFilter _statusFilter = _StorageStatusFilter.all;
  String? _selectedLocationId;
  String? _selectedSourceId;
  String? _reviewSourceId;

  List<AdminStorageLocation> _filteredLocations(
    List<AdminStorageLocation> locations,
    String query,
  ) {
    final normalizedQuery = query.toLowerCase();
    return locations.where((location) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          location.name.toLowerCase().contains(normalizedQuery) ||
          location.mountKey.toLowerCase().contains(normalizedQuery) ||
          location.relativeRoot.toLowerCase().contains(normalizedQuery);
      if (!matchesQuery) {
        return false;
      }
      return switch (_statusFilter) {
        _StorageStatusFilter.all => true,
        _StorageStatusFilter.enabled => location.enabled,
        _StorageStatusFilter.disabled => !location.enabled,
        _StorageStatusFilter.unhealthy => !_storageHealthy(location),
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
    final canManageSources =
        ref
            .watch(authSessionProvider)
            .asData
            ?.value
            .user
            ?.permissions
            .contains('media:library:manage') ??
        false;
    final query = ref.watch(adminSearchProvider).toLowerCase();
    final locations = _filteredLocations(widget.view.locations, query);
    final selected =
        widget.view.locations
            .where((location) => location.id == _selectedLocationId)
            .firstOrNull;
    final wideLayout = MediaQuery.sizeOf(context).width >= 1080;

    final listSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final filter in _StorageStatusFilter.values)
              ChoiceChip(
                label: Text(switch (filter) {
                  _StorageStatusFilter.all => l10n.adminStorageFilterAll,
                  _StorageStatusFilter.enabled =>
                    l10n.adminStorageFilterEnabled,
                  _StorageStatusFilter.disabled =>
                    l10n.adminStorageFilterDisabled,
                  _StorageStatusFilter.unhealthy =>
                    l10n.adminStorageFilterUnhealthy,
                }),
                selected: _statusFilter == filter,
                onSelected: (_) => setState(() => _statusFilter = filter),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (locations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              children: [
                Icon(
                  Icons.folder_off_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.adminStorageEmptyList,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          )
        else
          ...locations.map(
            (location) => _StorageLocationRow(
              location: location,
              selected: location.id == _selectedLocationId,
              onTap: () => setState(() => _selectedLocationId = location.id),
            ),
          ),
      ],
    );

    final detailSection =
        selected == null
            ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.adminStorageDetailHint,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
            : _StorageDetailPanel(location: selected);

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
                            (context) => _StorageLocationWizard(
                              mounts: widget.view.trustedMounts,
                            ),
                      ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.adminAddLocalStorageLocation),
                ),
            ],
          ),
        ),
        if (wideLayout)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: listSection),
              const SizedBox(width: 24),
              VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
              const SizedBox(width: 24),
              Expanded(flex: 3, child: detailSection),
            ],
          )
        else ...[
          listSection,
          if (selected != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: detailSection,
            ),
        ],
        const SizedBox(height: 32),
        _LibrarySourcesSection(
          canManage: canManageSources,
          onSourceSelected:
              (id) => setState(() {
                _selectedSourceId = id;
                _reviewSourceId = id;
              }),
          selectedSourceId: _selectedSourceId,
        ),
        if (canManageSources) ...[
          const SizedBox(height: 32),
          _LibraryReviewSection(
            sources:
                ref.watch(videoLibrarySourcesProvider).asData?.value ??
                const <VideoLibrarySource>[],
            selectedSourceId: _reviewSourceId,
            onSelectSource:
                (id) => setState(() {
                  _reviewSourceId = id;
                  _selectedSourceId = id;
                }),
          ),
        ],
      ],
    );
  }
}

class _StorageLocationRow extends StatelessWidget {
  const _StorageLocationRow({
    required this.location,
    required this.selected,
    required this.onTap,
  });

  final AdminStorageLocation location;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final healthy = _storageHealthy(location);
    final statusColor =
        !location.enabled
            ? colors.outline
            : (healthy ? Colors.green.shade600 : colors.tertiary);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.surfaceContainerHighest : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.circle, size: 10, color: statusColor),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                location.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                location.mountKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                location.relativeRoot,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              location.enabled
                  ? healthStatusLabel(
                    AppLocalizations.of(context),
                    location.healthStatus,
                  )
                  : AppLocalizations.of(context).adminStorageStatusDisabled,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageDetailPanel extends ConsumerWidget {
  const _StorageDetailPanel({required this.location});

  final AdminStorageLocation location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canManage =
        ref
            .watch(authSessionProvider)
            .asData
            ?.value
            .user
            ?.permissions
            .contains('system:config:manage') ??
        false;
    final colors = Theme.of(context).colorScheme;
    final healthy = _storageHealthy(location);
    final statusColor =
        !location.enabled
            ? colors.outline
            : (healthy ? Colors.green.shade600 : colors.tertiary);

    Future<void> toggleEnabled(bool enabled) async {
      if (!enabled) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: Text(l10n.adminStorageDisableConfirmTitle),
                content: Text(
                  l10n.adminStorageDisableConfirmBody(location.name),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(l10n.adminCancel),
                  ),
                  FilledButton.tonal(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(l10n.adminStorageDisableAction),
                  ),
                ],
              ),
        );
        if (confirmed != true) {
          return;
        }
      }
      try {
        await ref
            .read(adminOperationsActionsProvider)
            .updateStorageLocation(location: location, enabled: enabled);
      } on Exception catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.adminLoadFailed(error.toString()))),
          );
        }
      }
    }

    Future<void> deleteLocation() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: Text(l10n.adminStorageDeleteConfirmTitle),
              content: Text(l10n.adminStorageDeleteConfirmBody(location.name)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.adminCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.adminStorageDeleteAction),
                ),
              ],
            ),
      );
      if (confirmed != true) {
        return;
      }
      try {
        await ref
            .read(adminOperationsActionsProvider)
            .deleteStorageLocation(location.id);
      } on Exception catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.adminLoadFailed(error.toString()))),
          );
        }
      }
    }

    String fieldLabel(String label, String value) => '$label: $value';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 10, color: statusColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  location.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AdminStatusPill(
                label: healthStatusLabel(
                  AppLocalizations.of(context),
                  location.healthStatus,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            fieldLabel(l10n.adminMountKey, location.mountKey),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            fieldLabel(l10n.adminStorageFieldPath, location.relativeRoot),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            fieldLabel(
              l10n.adminStorageFieldScope,
              scopeTypeLabel(l10n, location.scopeType),
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            fieldLabel(
              l10n.adminStorageFieldProvider,
              providerTypeLabel(l10n, location.providerType),
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            fieldLabel(
              l10n.adminStorageFieldManagement,
              location.managementMode,
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (canManage) ...[
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              children: [
                location.enabled
                    ? OutlinedButton.icon(
                      onPressed: () => toggleEnabled(false),
                      icon: const Icon(Icons.pause_circle_outline_rounded),
                      label: Text(l10n.adminStorageDisableAction),
                    )
                    : FilledButton.tonalIcon(
                      onPressed: () => toggleEnabled(true),
                      icon: const Icon(Icons.play_circle_outline_rounded),
                      label: Text(l10n.adminStorageEnableAction),
                    ),
                OutlinedButton.icon(
                  onPressed: deleteLocation,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(l10n.adminStorageDeleteAction),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StorageLocationWizard extends ConsumerStatefulWidget {
  const _StorageLocationWizard({required this.mounts});

  final List<AdminTrustedMount> mounts;

  @override
  ConsumerState<_StorageLocationWizard> createState() =>
      _StorageLocationWizardState();
}

class _StorageLocationWizardState
    extends ConsumerState<_StorageLocationWizard> {
  final _nameController = TextEditingController();
  String? _mountKey;
  String? _parent;
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
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    final mountKey = _mountKey;
    final relativeRoot = _parent ?? '.';
    if (name.isEmpty || mountKey == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(adminOperationsActionsProvider)
          .createStorageLocation(
            name: name,
            mountKey: mountKey,
            relativeRoot: relativeRoot,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminLoadFailed(error.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = _parent ?? '.';
    return AlertDialog(
      title: Text(l10n.adminAddLocalStorageLocation),
      content: SizedBox(
        width: 480,
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
                      : (value) {
                        setState(() {
                          _mountKey = value;
                          _parent = null;
                        });
                      },
              decoration: InputDecoration(
                labelText: l10n.adminMountKey,
                helperText: l10n.adminMountKeyHint,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  l10n.adminStorageFieldPath,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    current,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: l10n.coreBack,
                  onPressed:
                      current != '.' && !_saving
                          ? () => setState(() {
                            final separator = current.lastIndexOf('/');
                            _parent =
                                separator < 0
                                    ? null
                                    : current.substring(0, separator);
                          })
                          : null,
                  icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Builder(
                  builder: (context) {
                    final directoryAsync = ref.watch(
                      adminMountDirectoriesProvider((
                        mountKey: _mountKey ?? '',
                        parent: _parent,
                      )),
                    );
                    return directoryAsync.when(
                      loading:
                          () => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      error:
                          (error, _) => Center(
                            child: Text(l10n.adminLoadFailed(error.toString())),
                          ),
                      data:
                          (directories) =>
                              directories.isEmpty
                                  ? Center(child: Text(l10n.adminNoSubfolders))
                                  : ListView.builder(
                                    itemCount: directories.length,
                                    itemBuilder: (context, index) {
                                      final directory = directories[index];
                                      return ListTile(
                                        dense: true,
                                        leading: const Icon(
                                          Icons.folder_outlined,
                                          size: 20,
                                        ),
                                        title: Text(
                                          directory.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          directory.relativePath,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onTap:
                                            _saving
                                                ? null
                                                : () => setState(
                                                  () =>
                                                      _parent =
                                                          directory
                                                              .relativePath,
                                                ),
                                      );
                                    },
                                  ),
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
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.adminCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.adminUseCurrentFolder),
        ),
      ],
    );
  }
}
