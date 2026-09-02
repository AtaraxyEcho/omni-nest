part of 'admin_operations_pages.dart';

class AdminConfigPage extends ConsumerWidget {
  const AdminConfigPage({required this.view, super.key});

  final AdminConfigManagementView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(adminSearchProvider).toLowerCase();
    final filtered =
        view.items.where((item) {
            if (_isRemovedConfigKey(item.key)) {
              return false;
            }
            if (query.isNotEmpty &&
                !item.key.toLowerCase().contains(query) &&
                !_configTitle(l10n, item).toLowerCase().contains(query)) {
              return false;
            }
            return true;
          }).toList()
          ..sort((a, b) {
            final categoryOrder = _configCategoryOrder(
              a.category,
            ).compareTo(_configCategoryOrder(b.category));
            if (categoryOrder != 0) {
              return categoryOrder;
            }
            return a.key.compareTo(b.key);
          });
    final groups = <String, List<AdminConfigEntry>>{};
    for (final item in filtered) {
      groups.putIfAbsent(_configGroup(l10n, item), () => []).add(item);
    }
    return _PageEntrance(
      children: [
        AdminPageHeader(
          title: l10n.adminConfigCenter,
          subtitle: l10n.adminConfigCenterSubtitle,
          trailing: Wrap(
            spacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AdminStatusPill(
                label: l10n.adminConfigGroupItemCount(filtered.length),
              ),
              IconButton.filledTonal(
                onPressed: () => ref.invalidate(adminConfigsProvider),
                icon: const Icon(Icons.refresh_rounded),
                tooltip: l10n.adminConfigRefresh,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (groups.isEmpty)
          AdminInfoPanel(
            title: l10n.adminConfigItemList,
            subtitle: l10n.adminConfigItemListSubtitle,
            children: [
              _EmptyText(
                query.isEmpty ? l10n.adminNoConfigItems : l10n.adminNoMatch,
              ),
            ],
          )
        else
          for (final group in groups.entries) ...[
            AdminInfoPanel(
              title: group.key,
              subtitle: l10n.adminConfigGroupItemCount(group.value.length),
              children: [
                AdminDataTable(
                  showIndex: true,
                  minTableWidth: 940,
                  columns: [
                    AdminListColumn(
                      key: 'name',
                      label: l10n.adminConfigItems,
                      flex: 2,
                    ),
                    AdminListColumn(
                      key: 'description',
                      label: l10n.adminConfigDescription,
                      flex: 3,
                    ),
                    AdminListColumn(
                      key: 'value',
                      label: l10n.adminConfigValue,
                      flex: 2,
                    ),
                    AdminListColumn(
                      key: 'updatedAt',
                      label: l10n.adminTaskUpdatedAt,
                      minWidth: 150,
                    ),
                  ],
                  rowCount: group.value.length,
                  emptyState: AdminListEmptyState(
                    message: l10n.adminNoConfigItems,
                  ),
                  rowCellsBuilder: (context, index) {
                    final item = group.value[index];
                    final summary = _configValueSummary(l10n, item);
                    return [
                      Text(
                        _configTitle(l10n, item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _configDescription(l10n, item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Tooltip(
                        message: summary,
                        child: Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        item.updatedAt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ];
                  },
                  actionsBuilder: (context, index) {
                    final entry = group.value[index];
                    final isBoolean = entry.valueType == 'BOOLEAN';
                    return [
                      IconButton.outlined(
                        onPressed:
                            () => showDialog<void>(
                              context: context,
                              builder:
                                  (_) => _ConfigHistoryDialog(
                                    configKey: entry.key,
                                    configLabel: _configTitle(l10n, entry),
                                  ),
                            ),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        tooltip: l10n.adminConfigHistory,
                      ),
                      if (isBoolean)
                        _ConfigToggleSwitch(entry: entry)
                      else
                        FilledButton.tonalIcon(
                          onPressed:
                              entry.editable
                                  ? () => showDialog<void>(
                                    context: context,
                                    builder:
                                        (_) => _ConfigEditDialog(entry: entry),
                                  )
                                  : null,
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          label: Text(l10n.adminConfigManage),
                        ),
                    ];
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
      ],
    );
  }
}

class _ConfigToggleSwitch extends ConsumerStatefulWidget {
  const _ConfigToggleSwitch({required this.entry});

  final AdminConfigEntry entry;

  @override
  ConsumerState<_ConfigToggleSwitch> createState() =>
      _ConfigToggleSwitchState();
}

class _ConfigToggleSwitchState extends ConsumerState<_ConfigToggleSwitch> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _saving
        ? const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
        : Switch(
          value: widget.entry.value == 'true',
          onChanged:
              !widget.entry.editable
                  ? null
                  : (enabled) async {
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => _saving = true);
                    try {
                      await ref
                          .read(adminOperationsActionsProvider)
                          .updateConfig(widget.entry.key, enabled.toString());
                    } on Object {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(l10n.adminOperationFailed)),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _saving = false);
                      }
                    }
                  },
        );
  }
}

bool _isRemovedConfigKey(String key) {
  return const {
    'media.metadata-providers.enabled',
    'reader.metadata-providers.enabled',
    'reader.metadata-provider.open-library.timeout-seconds',
    'reader.metadata-provider.open-library.max-results',
    'music.metadata-providers.enabled',
    'music.metadata-provider.musicbrainz.request-delay-ms',
    'music.platform.netease.request-delay-ms',
    'photo.geo.cache-enabled',
    'upload.bandwidth.max-parts-per-second',
    'upload.bandwidth.burst-capacity',
    'security.clamav.timeout-millis',
    'file.local-media.enabled',
    'file.local-media.max-files-per-scan',
    'file.local-media.max-scan-depth',
  }.contains(key);
}

int _configCategoryOrder(String category) {
  return switch (category) {
    'media' => 0,
    'reader' => 1,
    'music' => 2,
    'photo' => 3,
    'storage' => 4,
    'upload' => 5,
    'security' => 6,
    'weather' => 7,
    _ => 8,
  };
}

String _configGroup(AppLocalizations l10n, AdminConfigEntry entry) {
  if (_startsWithAny(entry.key, const [
    'music.musicbrainz',
    'music.metadata-provider.musicbrainz',
  ])) {
    return l10n.adminConfigProviderMusicBrainz;
  }
  if (_startsWithAny(entry.key, const [
    'media.tmdb',
    'media.metadata-provider.tmdb',
  ])) {
    return l10n.adminConfigProviderTmdb;
  }
  if (_startsWithAny(entry.key, const [
    'media.subtitle',
    'media.subtitle.opensubtitles',
  ])) {
    return l10n.adminConfigProviderOpenSubtitles;
  }
  if (_startsWithAny(entry.key, const [
    'reader.gbooks',
    'reader.metadata-provider.google-books',
  ])) {
    return l10n.adminConfigProviderGoogleBooks;
  }
  if (_startsWithAny(entry.key, const [
    'reader.openlib',
    'reader.metadata-provider.open-library',
  ])) {
    return l10n.adminConfigProviderOpenLibrary;
  }
  if (entry.key.startsWith('photo.ai')) {
    return l10n.adminConfigProviderPhotoAi;
  }
  if (_startsWithAny(entry.key, const [
    'music.netease',
    'music.platform.netease',
  ])) {
    return l10n.adminConfigProviderNetease;
  }
  if (_startsWithAny(entry.key, const ['music.qq', 'music.platform.qq'])) {
    return l10n.adminConfigProviderQqMusic;
  }
  if (entry.key.startsWith('weather.qweather')) {
    return l10n.adminConfigProviderQWeather;
  }
  return switch (entry.category) {
    'media' => l10n.adminConfigGroupMedia,
    'reader' => l10n.adminConfigGroupReader,
    'music' => l10n.adminConfigGroupMusic,
    'photo' => l10n.adminConfigGroupPhotos,
    'storage' => l10n.adminConfigGroupStorage,
    'upload' => l10n.adminConfigGroupUpload,
    'security' => l10n.adminConfigGroupSecurity,
    'weather' => l10n.adminConfigGroupWeather,
    _ => l10n.adminConfigGroupOther,
  };
}

bool _startsWithAny(String value, List<String> prefixes) {
  return prefixes.any(value.startsWith);
}

String _configTitle(AppLocalizations l10n, AdminConfigEntry entry) {
  final keyTitle =
      <String, String>{
        'media.tmdb.enabled': l10n.adminConfigTmdbEnabled,
        'media.metadata-provider.tmdb.enabled': l10n.adminConfigTmdbEnabled,
        'media.tmdb.token': l10n.adminConfigTmdbAccessToken,
        'media.metadata-provider.tmdb.access-token':
            l10n.adminConfigTmdbAccessToken,
        'media.tmdb.key': l10n.adminConfigTmdbApiKey,
        'media.metadata-provider.tmdb.api-key': l10n.adminConfigTmdbApiKey,
        'media.tmdb.url': l10n.adminConfigTmdbBaseUrl,
        'media.metadata-provider.tmdb.base-url': l10n.adminConfigTmdbBaseUrl,
        'media.tmdb.lang': l10n.adminConfigTmdbLanguage,
        'media.metadata-provider.tmdb.language': l10n.adminConfigTmdbLanguage,
        'media.tmdb.timeout': l10n.adminConfigTmdbTimeout,
        'media.metadata-provider.tmdb.timeout-seconds':
            l10n.adminConfigTmdbTimeout,
        'media.tmdb.strategy': l10n.adminConfigTmdbStrategy,
        'media.metadata-provider.tmdb.search-queries-strategy':
            l10n.adminConfigTmdbStrategy,
        'media.tmdb.limit': l10n.adminConfigTmdbLimit,
        'media.metadata-provider.tmdb.max-results': l10n.adminConfigTmdbLimit,
        'media.tmdb.adult': l10n.adminConfigTmdbAdult,
        'media.metadata-provider.tmdb.include-adult': l10n.adminConfigTmdbAdult,
        'media.transcode.enabled': l10n.adminConfigMediaTranscode,
        'transcode.enabled': l10n.adminConfigMediaTranscode,
        'media.import.enabled': l10n.adminConfigMediaAutoImport,
        'media.auto-import.enabled': l10n.adminConfigMediaAutoImport,
        'media.subtitle.key': l10n.adminConfigOpenSubtitlesApiKey,
        'media.subtitle.opensubtitles-api-key':
            l10n.adminConfigOpenSubtitlesApiKey,
        'reader.gbooks.enabled': l10n.adminConfigReaderGoogleBooksEnabled,
        'reader.metadata-provider.google-books.enabled':
            l10n.adminConfigReaderGoogleBooksEnabled,
        'reader.gbooks.url': l10n.adminConfigReaderGoogleBooksUrl,
        'reader.metadata-provider.google-books.base-url':
            l10n.adminConfigReaderGoogleBooksUrl,
        'reader.gbooks.lang': l10n.adminConfigReaderGoogleBooksLanguage,
        'reader.metadata-provider.google-books.language':
            l10n.adminConfigReaderGoogleBooksLanguage,
        'reader.gbooks.limit': l10n.adminConfigReaderGoogleBooksLimit,
        'reader.metadata-provider.google-books.max-results':
            l10n.adminConfigReaderGoogleBooksLimit,
        'reader.gbooks.timeout': l10n.adminConfigReaderGoogleBooksTimeout,
        'reader.metadata-provider.google-books.timeout-seconds':
            l10n.adminConfigReaderGoogleBooksTimeout,
        'reader.gbooks.key': l10n.adminConfigReaderGoogleBooksApiKey,
        'reader.metadata-provider.google-books.api-key':
            l10n.adminConfigReaderGoogleBooksApiKey,
        'reader.openlib.enabled': l10n.adminConfigReaderOpenLibraryEnabled,
        'reader.metadata-provider.open-library.enabled':
            l10n.adminConfigReaderOpenLibraryEnabled,
        'reader.openlib.url': l10n.adminConfigReaderOpenLibraryUrl,
        'reader.metadata-provider.open-library.base-url':
            l10n.adminConfigReaderOpenLibraryUrl,
        'reader.openlib.lang': l10n.adminConfigReaderOpenLibraryLanguage,
        'reader.metadata-provider.open-library.language':
            l10n.adminConfigReaderOpenLibraryLanguage,
        'reader.import.enabled': l10n.adminConfigReaderAutoImport,
        'reader.auto-import.enabled': l10n.adminConfigReaderAutoImport,
        'music.musicbrainz.enabled': l10n.adminConfigMusicBrainzEnabled,
        'music.metadata-provider.musicbrainz.enabled':
            l10n.adminConfigMusicBrainzEnabled,
        'music.import.enabled': l10n.adminConfigMusicAutoImport,
        'music.auto-import.enabled': l10n.adminConfigMusicAutoImport,
        'music.musicbrainz.url': l10n.adminConfigMusicBrainzBaseUrl,
        'music.metadata-provider.musicbrainz.base-url':
            l10n.adminConfigMusicBrainzBaseUrl,
        'music.musicbrainz.ua': l10n.adminConfigMusicBrainzUserAgent,
        'music.metadata-provider.musicbrainz.user-agent':
            l10n.adminConfigMusicBrainzUserAgent,
        'music.musicbrainz.cover-url': l10n.adminConfigMusicBrainzCoverUrl,
        'music.metadata-provider.musicbrainz.cover-base-url':
            l10n.adminConfigMusicBrainzCoverUrl,
        'music.online.enabled': l10n.adminConfigMusicOnlineEnabled,
        'music.platform.online.enabled': l10n.adminConfigMusicOnlineEnabled,
        'music.netease.enabled': l10n.adminConfigNeteaseEnabled,
        'music.platform.netease.enabled': l10n.adminConfigNeteaseEnabled,
        'music.netease.url': l10n.adminConfigNeteaseBaseUrl,
        'music.platform.netease.base-url': l10n.adminConfigNeteaseBaseUrl,
        'music.netease.hosts': l10n.adminConfigNeteaseHosts,
        'music.platform.netease.playback-host-suffixes':
            l10n.adminConfigNeteaseHosts,
        'music.qq.enabled': l10n.adminConfigQqEnabled,
        'music.platform.qq.enabled': l10n.adminConfigQqEnabled,
        'music.qq.u-url': l10n.adminConfigQqUUrl,
        'music.platform.qq.u-url': l10n.adminConfigQqUUrl,
        'music.qq.c-url': l10n.adminConfigQqCUrl,
        'music.platform.qq.c-url': l10n.adminConfigQqCUrl,
        'music.qq.hosts': l10n.adminConfigQqHosts,
        'music.platform.qq.playback-host-suffixes': l10n.adminConfigQqHosts,
        'photo.ai.enabled': l10n.adminConfigPhotoAiEnabled,
        'photo.ai.url': l10n.adminConfigPhotoAiEndpoint,
        'photo.ai.endpoint': l10n.adminConfigPhotoAiEndpoint,
        'photo.ai.timeout': l10n.adminConfigPhotoAiTimeout,
        'photo.ai.timeout-seconds': l10n.adminConfigPhotoAiTimeout,
        'photo.backup': l10n.adminConfigPhotoBackup,
        'photo.backup.enabled': l10n.adminConfigPhotoBackup,
        'photo.geo.rate': l10n.adminConfigPhotoGeoRate,
        'photo.geo.rate-limit-per-second': l10n.adminConfigPhotoGeoRate,
        'storage.quota.default': l10n.adminConfigDefaultQuota,
        'storage.quota.default.gb': l10n.adminConfigDefaultQuota,
        'storage.quota.warning': l10n.adminConfigQuotaWarning,
        'storage.quota.warning.percent': l10n.adminConfigQuotaWarning,
        'share.enabled': l10n.adminConfigSharedSpace,
        'shared_space.enabled': l10n.adminConfigSharedSpace,
        'share.max-bytes': l10n.adminConfigSharedSpaceLimit,
        'shared_space.max_bytes': l10n.adminConfigSharedSpaceLimit,
        'upload.rate.enabled': l10n.adminConfigUploadRateEnabled,
        'upload.bandwidth.enabled': l10n.adminConfigUploadRateEnabled,
        'security.rate-limit': l10n.adminConfigSecurityRateLimit,
        'rate-limit.default-limit': l10n.adminConfigSecurityRateLimit,
        'clamav.enabled': l10n.adminConfigClamavEnabled,
        'security.clamav.enabled': l10n.adminConfigClamavEnabled,
        'clamav.host': l10n.adminConfigClamavHost,
        'security.clamav.host': l10n.adminConfigClamavHost,
        'clamav.port': l10n.adminConfigClamavPort,
        'security.clamav.port': l10n.adminConfigClamavPort,
        'weather.enabled': l10n.adminConfigWeather,
        'weather.qweather.project': l10n.adminConfigQWeatherProjectId,
        'weather.qweather.project-id': l10n.adminConfigQWeatherProjectId,
        'weather.qweather.credential': l10n.adminConfigQWeatherCredentialId,
        'weather.qweather.credential-id': l10n.adminConfigQWeatherCredentialId,
        'weather.qweather.url': l10n.adminConfigQWeatherBaseUrl,
        'weather.qweather.base-url': l10n.adminConfigQWeatherBaseUrl,
        'weather.qweather.key': l10n.adminConfigQWeatherPrivateKey,
        'weather.qweather.private-key': l10n.adminConfigQWeatherPrivateKey,
        'weather.location': l10n.adminConfigWeatherLocation,
      }[entry.key];
  if (keyTitle != null) {
    return keyTitle;
  }
  return switch (entry.displayCode) {
    'config.media.autoImport' => l10n.adminConfigMediaAutoImport,
    'config.photo.backup' => l10n.adminConfigPhotoBackup,
    'config.storage.defaultQuota' => l10n.adminConfigDefaultQuota,
    'config.storage.warningPercent' => l10n.adminConfigQuotaWarning,
    'config.storage.sharedSpace' => l10n.adminConfigSharedSpace,
    'config.storage.sharedSpaceLimit' => l10n.adminConfigSharedSpaceLimit,
    'config.storage.localMedia' => l10n.adminConfigLocalMedia,
    'config.weather.enabled' => l10n.adminConfigWeather,
    'config.integration.musicbrainz.enabled' =>
      l10n.adminConfigMusicBrainzEnabled,
    'config.integration.tmdb.enabled' => l10n.adminConfigTmdbEnabled,
    'config.integration.tmdb.apiKey' => l10n.adminConfigTmdbApiKey,
    'config.integration.tmdb.accessToken' => l10n.adminConfigTmdbAccessToken,
    'config.integration.tmdb.language' => l10n.adminConfigTmdbLanguage,
    'config.integration.tmdb.includeAdult' => l10n.adminConfigTmdbAdult,
    'config.integration.opensubtitles.apiKey' =>
      l10n.adminConfigOpenSubtitlesApiKey,
    'config.integration.photoAi.enabled' => l10n.adminConfigPhotoAiEnabled,
    'config.integration.netease.enabled' => l10n.adminConfigNeteaseEnabled,
    'config.integration.qq.enabled' => l10n.adminConfigQqEnabled,
    'config.integration.qweather.projectId' =>
      l10n.adminConfigQWeatherProjectId,
    'config.integration.qweather.credentialId' =>
      l10n.adminConfigQWeatherCredentialId,
    'config.integration.qweather.privateKey' =>
      l10n.adminConfigQWeatherPrivateKey,
    _ => l10n.adminConfigUnknownItem,
  };
}

String _configDescription(AppLocalizations l10n, AdminConfigEntry entry) {
  final keyDescription =
      <String, String>{
        'storage.quota.default': l10n.adminConfigQuotaUnlimitedDescription,
        'storage.quota.default.gb': l10n.adminConfigQuotaUnlimitedDescription,
        'share.max-bytes': l10n.adminConfigQuotaUnlimitedDescription,
        'shared_space.max_bytes': l10n.adminConfigQuotaUnlimitedDescription,
        'media.tmdb.url': l10n.adminConfigEndpointDescription,
        'media.metadata-provider.tmdb.base-url':
            l10n.adminConfigEndpointDescription,
        'music.musicbrainz.url': l10n.adminConfigEndpointDescription,
        'music.metadata-provider.musicbrainz.base-url':
            l10n.adminConfigEndpointDescription,
        'weather.qweather.url': l10n.adminConfigEndpointDescription,
        'weather.qweather.base-url': l10n.adminConfigEndpointDescription,
        'music.netease.url': l10n.adminConfigEndpointDescription,
        'music.platform.netease.base-url': l10n.adminConfigEndpointDescription,
        'music.qq.u-url': l10n.adminConfigEndpointDescription,
        'music.platform.qq.u-url': l10n.adminConfigEndpointDescription,
        'music.qq.c-url': l10n.adminConfigEndpointDescription,
        'music.platform.qq.c-url': l10n.adminConfigEndpointDescription,
        'photo.ai.url': l10n.adminConfigEndpointDescription,
        'photo.ai.endpoint': l10n.adminConfigEndpointDescription,
        'reader.gbooks.url': l10n.adminConfigEndpointDescription,
        'reader.metadata-provider.google-books.base-url':
            l10n.adminConfigEndpointDescription,
        'reader.openlib.url': l10n.adminConfigEndpointDescription,
        'reader.metadata-provider.open-library.base-url':
            l10n.adminConfigEndpointDescription,
        'weather.location': l10n.adminConfigWeatherLocationDescription,
        'media.tmdb.lang': l10n.adminConfigTmdbLanguageDescription,
        'media.metadata-provider.tmdb.language':
            l10n.adminConfigTmdbLanguageDescription,
        'media.tmdb.adult': l10n.adminConfigTmdbAdultDescription,
        'media.metadata-provider.tmdb.include-adult':
            l10n.adminConfigTmdbAdultDescription,
        'media.tmdb.key': l10n.adminConfigCredentialDescription,
        'media.tmdb.token': l10n.adminConfigCredentialDescription,
        'media.metadata-provider.tmdb.api-key':
            l10n.adminConfigCredentialDescription,
        'media.metadata-provider.tmdb.access-token':
            l10n.adminConfigCredentialDescription,
        'media.subtitle.key': l10n.adminConfigCredentialDescription,
        'media.subtitle.opensubtitles-api-key':
            l10n.adminConfigCredentialDescription,
        'reader.gbooks.key': l10n.adminConfigCredentialDescription,
        'reader.metadata-provider.google-books.api-key':
            l10n.adminConfigCredentialDescription,
        'weather.qweather.key': l10n.adminConfigCredentialDescription,
        'weather.qweather.private-key': l10n.adminConfigCredentialDescription,
        'weather.qweather.project':
            l10n.adminConfigProviderIdentifierDescription,
        'weather.qweather.project-id':
            l10n.adminConfigProviderIdentifierDescription,
        'weather.qweather.credential':
            l10n.adminConfigProviderIdentifierDescription,
        'weather.qweather.credential-id':
            l10n.adminConfigProviderIdentifierDescription,
        'media.tmdb.timeout': l10n.adminConfigInternalNumericDescription,
        'media.metadata-provider.tmdb.timeout-seconds':
            l10n.adminConfigInternalNumericDescription,
        'media.tmdb.limit': l10n.adminConfigInternalNumericDescription,
        'media.metadata-provider.tmdb.max-results':
            l10n.adminConfigInternalNumericDescription,
        'reader.gbooks.timeout': l10n.adminConfigInternalNumericDescription,
        'reader.metadata-provider.google-books.timeout-seconds':
            l10n.adminConfigInternalNumericDescription,
        'reader.gbooks.limit': l10n.adminConfigInternalNumericDescription,
        'reader.metadata-provider.google-books.max-results':
            l10n.adminConfigInternalNumericDescription,
        'photo.ai.timeout': l10n.adminConfigInternalNumericDescription,
        'photo.ai.timeout-seconds': l10n.adminConfigInternalNumericDescription,
        'media.tmdb.strategy': l10n.adminConfigTmdbStrategyDescription,
        'media.metadata-provider.tmdb.search-queries-strategy':
            l10n.adminConfigTmdbStrategyDescription,
        'media.import.enabled': l10n.adminConfigMediaAutoImportDescription,
        'media.auto-import.enabled': l10n.adminConfigMediaAutoImportDescription,
        'media.transcode.enabled': l10n.adminConfigMediaTranscodeDescription,
        'transcode.enabled': l10n.adminConfigMediaTranscodeDescription,
        'reader.import.enabled': l10n.adminConfigReaderAutoImportDescription,
        'reader.auto-import.enabled':
            l10n.adminConfigReaderAutoImportDescription,
        'music.import.enabled': l10n.adminConfigMusicAutoImportDescription,
        'music.auto-import.enabled': l10n.adminConfigMusicAutoImportDescription,
        'photo.geo.rate': l10n.adminConfigPhotoGeoRateDescription,
        'photo.geo.rate-limit-per-second':
            l10n.adminConfigPhotoGeoRateDescription,
        'upload.rate.enabled': l10n.adminConfigUploadRateDescription,
        'upload.bandwidth.enabled': l10n.adminConfigUploadRateDescription,
        'security.rate-limit': l10n.adminConfigSecurityRateLimitDescription,
        'rate-limit.default-limit':
            l10n.adminConfigSecurityRateLimitDescription,
        'music.musicbrainz.ua': l10n.adminConfigMusicBrainzUserAgentDescription,
        'music.metadata-provider.musicbrainz.user-agent':
            l10n.adminConfigMusicBrainzUserAgentDescription,
        'music.musicbrainz.cover-url': l10n.adminConfigEndpointDescription,
        'music.metadata-provider.musicbrainz.cover-base-url':
            l10n.adminConfigEndpointDescription,
        'music.netease.hosts': l10n.adminConfigHostSuffixesDescription,
        'music.platform.netease.playback-host-suffixes':
            l10n.adminConfigHostSuffixesDescription,
        'music.qq.hosts': l10n.adminConfigHostSuffixesDescription,
        'music.platform.qq.playback-host-suffixes':
            l10n.adminConfigHostSuffixesDescription,
      }[entry.key];
  if (keyDescription != null) {
    return keyDescription;
  }
  return switch (entry.displayCode) {
    'config.media.autoImport' => l10n.adminConfigMediaAutoImportDescription,
    'config.photo.backup' => l10n.adminConfigPhotoBackupDescription,
    'config.storage.defaultQuota' => l10n.adminConfigDefaultQuotaDescription,
    'config.storage.warningPercent' => l10n.adminConfigQuotaWarningDescription,
    'config.storage.sharedSpace' => l10n.adminConfigSharedSpaceDescription,
    'config.storage.sharedSpaceLimit' =>
      l10n.adminConfigSharedSpaceLimitDescription,
    'config.storage.localMedia' => l10n.adminConfigLocalMediaDescription,
    'config.weather.enabled' => l10n.adminConfigWeatherDescription,
    'config.integration.tmdb.language' =>
      l10n.adminConfigTmdbLanguageDescription,
    'config.integration.tmdb.includeAdult' =>
      l10n.adminConfigTmdbAdultDescription,
    'config.integration.qweather.projectId' ||
    'config.integration.qweather.credentialId' =>
      l10n.adminConfigProviderIdentifierDescription,
    'config.integration.tmdb.apiKey' ||
    'config.integration.tmdb.accessToken' ||
    'config.integration.opensubtitles.apiKey' ||
    'config.integration.qweather.privateKey' =>
      l10n.adminConfigCredentialDescription,
    _ => l10n.adminConfigProviderToggleDescription,
  };
}

String _configValueSummary(AppLocalizations l10n, AdminConfigEntry entry) {
  if (_isSensitiveConfigEntry(entry)) {
    return entry.sensitiveConfigured
        ? l10n.adminConfigSecretConfigured
        : l10n.adminConfigNeedsSetup;
  }
  if (entry.valueType == 'BOOLEAN') {
    return entry.value == 'true' ? l10n.adminEnabled : l10n.adminDisabled;
  }
  if (_isQuotaConfigEntry(entry) && _isUnlimitedQuota(entry)) {
    return l10n.adminConfigUnlimited;
  }
  if (entry.value.isEmpty) {
    return l10n.adminConfigNeedsSetup;
  }
  return l10n.adminConfigCurrentValue(
    _formatConfigValue(entry.key, entry.value),
  );
}

bool _isQuotaConfigEntry(AdminConfigEntry entry) {
  return entry.key == 'storage.quota.default' ||
      entry.key == 'storage.quota.default.gb' ||
      entry.key == 'share.max-bytes' ||
      entry.key == 'shared_space.max_bytes';
}

bool _isUnlimitedQuota(AdminConfigEntry entry) {
  final value = double.tryParse(entry.value);
  return value != null && value <= 0;
}

bool _isSensitiveConfigEntry(AdminConfigEntry entry) {
  const sensitiveDisplayCodes = {
    'config.integration.tmdb.apiKey',
    'config.integration.tmdb.accessToken',
    'config.integration.opensubtitles.apiKey',
    'config.integration.qweather.privateKey',
  };
  const sensitiveKeys = {
    'media.tmdb.key',
    'media.tmdb.token',
    'media.subtitle.key',
    'reader.gbooks.key',
    'weather.qweather.key',
    'media.metadata-provider.tmdb.api-key',
    'media.metadata-provider.tmdb.access-token',
    'media.subtitle.opensubtitles-api-key',
    'reader.metadata-provider.google-books.api-key',
    'weather.qweather.private-key',
  };
  return sensitiveDisplayCodes.contains(entry.displayCode) ||
      sensitiveKeys.contains(entry.key);
}

class _ConfigEditDialog extends ConsumerStatefulWidget {
  const _ConfigEditDialog({required this.entry});

  final AdminConfigEntry entry;

  @override
  ConsumerState<_ConfigEditDialog> createState() => _ConfigEditDialogState();
}

class _ConfigEditDialogState extends ConsumerState<_ConfigEditDialog> {
  late final TextEditingController _valueController = TextEditingController(
    text: _initialDisplayValue,
  );
  late String _boolValue = widget.entry.value;
  late bool _unlimited =
      _isQuotaConfigEntry(widget.entry) && _isUnlimitedQuota(widget.entry);
  final _reasonController = TextEditingController();
  bool _submitting = false;
  String? _error;

  /// 需要以 GB 为单位展示/编辑的字节类配置键。
  static const _gbConfigs = {'share.max-bytes', 'shared_space.max_bytes'};
  static const _quotaSliderMaxGb = 1024.0;

  bool get _isGbConfig => _gbConfigs.contains(widget.entry.key);
  bool get _isQuotaConfig => _isQuotaConfigEntry(widget.entry);
  bool get _isBoolConfig => widget.entry.valueType == 'BOOLEAN';
  bool get _isSensitiveConfig => _isSensitiveConfigEntry(widget.entry);

  String get _initialDisplayValue {
    if (_isSensitiveConfig) return '';
    if (_isBoolConfig) return widget.entry.value;
    if (_isQuotaConfig) {
      final gb = _quotaValueInGb(widget.entry);
      return gb <= 0 ? '' : _formatQuotaInput(gb);
    }
    if (_isGbConfig) {
      final bytes = int.tryParse(widget.entry.value) ?? 0;
      return (bytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
    }
    return widget.entry.value;
  }

  /// 将 GB 输入值转换为字节字符串。
  String _gbToBytes(String gbValue) {
    final gb = double.tryParse(gbValue);
    if (gb == null || gb < 0) return '0';
    return (gb * 1024 * 1024 * 1024).round().toString();
  }

  /// 最终提交的值。
  String get _submitValue {
    if (_isBoolConfig) return _boolValue;
    final raw = _valueController.text.trim();
    if (_isQuotaConfig) {
      if (_unlimited) return '0';
      final gb = double.tryParse(raw);
      if (gb == null || gb <= 0) return raw;
      if (_isGbConfig) return _gbToBytes(raw);
      return gb.round().toString();
    }
    return _isGbConfig ? _gbToBytes(raw) : raw;
  }

  @override
  void dispose() {
    _valueController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text('${l10n.adminEdit} ${_configTitle(l10n, widget.entry)}'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSensitiveConfig) ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  widget.entry.sensitiveConfigured
                      ? l10n.adminConfigSecretConfigured
                      : l10n.adminConfigNeedsSetup,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_isBoolConfig)
              DropdownButtonFormField<String>(
                initialValue: _boolValue,
                decoration: InputDecoration(labelText: l10n.adminConfigValue),
                items: [
                  DropdownMenuItem(value: 'true', child: Text(l10n.adminTrue)),
                  DropdownMenuItem(
                    value: 'false',
                    child: Text(l10n.adminFalse),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _boolValue = v);
                },
              )
            else if (_isQuotaConfig)
              _QuotaEditor(
                controller: _valueController,
                unlimited: _unlimited,
                maxGb: _quotaSliderMaxGb,
                initialGb: _quotaValueInGb(widget.entry),
                onUnlimitedChanged: (value) {
                  setState(() {
                    _unlimited = value;
                    if (!value && _valueController.text.trim().isEmpty) {
                      _valueController.text = '1';
                    }
                  });
                },
                onValueChanged: (value) {
                  setState(() {
                    if (value >= _quotaSliderMaxGb) {
                      _unlimited = true;
                    } else {
                      _unlimited = false;
                      _valueController.text = _formatQuotaInput(value);
                    }
                  });
                },
                onTextChanged: (value) {
                  if (value == null || value <= 0) return;
                  setState(() => _unlimited = false);
                },
              )
            else if (widget.entry.allowedValues.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue:
                    widget.entry.allowedValues.contains(widget.entry.value)
                        ? widget.entry.value
                        : null,
                decoration: InputDecoration(labelText: l10n.adminConfigValue),
                items: [
                  for (final value in widget.entry.allowedValues)
                    DropdownMenuItem(value: value, child: Text(value)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _valueController.text = value;
                  }
                },
              )
            else
              TextField(
                controller: _valueController,
                decoration: InputDecoration(
                  labelText: l10n.adminConfigValue,
                  hintText:
                      _isSensitiveConfig
                          ? l10n.adminSensitiveValuePlaceholder
                          : null,
                  suffixText: _isGbConfig ? 'GB' : null,
                ),
                keyboardType:
                    _isGbConfig
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                minLines: 1,
                maxLines: 4,
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(labelText: l10n.adminChangeReason),
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
        if (_isSensitiveConfig && widget.entry.sensitiveConfigured)
          TextButton.icon(
            onPressed: _submitting ? null : _clearCredential,
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.adminConfigClearCredential),
            style: TextButton.styleFrom(
              foregroundColor: context.adminColors.error,
            ),
          ),
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.coreCancel),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: const Icon(Icons.save_outlined),
          label: Text(_submitting ? l10n.adminSaving : l10n.adminSave),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final quotaError = _validateQuota(l10n);
    if (quotaError != null) {
      setState(() => _error = quotaError);
      return;
    }
    if (_isSensitiveConfig && _submitValue.isEmpty) {
      setState(() => _error = l10n.adminSensitiveValuePlaceholder);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final actions = ref.read(adminOperationsActionsProvider);
    try {
      await actions.updateConfig(
        widget.entry.key,
        _submitValue,
        reason: _reasonController.text,
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

  String? _validateQuota(AppLocalizations l10n) {
    if (!_isQuotaConfig || _unlimited) {
      return null;
    }
    final value = double.tryParse(_valueController.text.trim());
    if (value == null || !value.isFinite || value <= 0) {
      return l10n.adminConfigQuotaInvalid;
    }
    if (!_isGbConfig && value != value.roundToDouble()) {
      return l10n.adminConfigQuotaWholeGb;
    }
    return null;
  }

  Future<void> _clearCredential() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.adminConfigClearCredential),
            content: Text(l10n.adminConfigClearCredentialConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.coreCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.adminConfigClearCredential),
              ),
            ],
          ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    final actions = ref.read(adminOperationsActionsProvider);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await actions.updateConfig(
        widget.entry.key,
        '',
        reason: l10n.adminConfigCredentialClearedReason,
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

double _quotaValueInGb(AdminConfigEntry entry) {
  final value = double.tryParse(entry.value) ?? 0;
  if (entry.key == 'share.max-bytes' || entry.key == 'shared_space.max_bytes') {
    return value / (1024 * 1024 * 1024);
  }
  return value;
}

String _formatQuotaInput(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

class _QuotaEditor extends StatelessWidget {
  const _QuotaEditor({
    required this.controller,
    required this.unlimited,
    required this.maxGb,
    required this.initialGb,
    required this.onUnlimitedChanged,
    required this.onValueChanged,
    required this.onTextChanged,
  });

  final TextEditingController controller;
  final bool unlimited;
  final double maxGb;
  final double initialGb;
  final ValueChanged<bool> onUnlimitedChanged;
  final ValueChanged<double> onValueChanged;
  final ValueChanged<double?> onTextChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final parsed = double.tryParse(controller.text.trim());
    final sliderValue =
        unlimited
            ? maxGb
            : (parsed ?? initialGb).clamp(1.0, maxGb - 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: !unlimited,
          decoration: InputDecoration(
            labelText: l10n.adminConfigValue,
            suffixText: 'GB',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) => onTextChanged(double.tryParse(value.trim())),
        ),
        const SizedBox(height: 6),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(l10n.adminConfigUnlimited),
          subtitle: Text(l10n.adminConfigUnlimitedDescription),
          value: unlimited,
          onChanged: onUnlimitedChanged,
        ),
        const SizedBox(height: 2),
        AppSlider(
          value: sliderValue,
          min: 1,
          max: maxGb,
          divisions: maxGb.round() - 1,
          label:
              unlimited
                  ? l10n.adminConfigUnlimited
                  : '${_formatQuotaInput(sliderValue)} GB',
          onChanged: onValueChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.adminConfigQuotaSliderMinimum,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              l10n.adminConfigQuotaSliderUnlimited,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _ConfigHistoryDialog extends ConsumerWidget {
  const _ConfigHistoryDialog({
    required this.configKey,
    required this.configLabel,
  });

  final String configKey;
  final String configLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final adminColors = context.adminColors;
    final history = ref.watch(adminConfigHistoryProvider(configKey));
    return AlertDialog(
      title: Text('${l10n.adminConfigHistory} — $configLabel'),
      content: SizedBox(
        width: 560,
        child: history.when(
          loading:
              () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
          error:
              (error, _) => Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l10n.adminLoadFailed('$error')),
              ),
          data: (items) {
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l10n.adminNoConfigHistory),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(
                    '${item.oldValue ?? l10n.adminNotSet}'
                    ' → ${item.newValue ?? l10n.adminNotSet}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '${item.changeReason ?? l10n.adminNoReason}'
                    ' · ${item.createdAt}',
                    style: TextStyle(
                      fontSize: 12,
                      color: adminColors.onSurfaceVariant,
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(adminOperationsActionsProvider)
                            .rollbackConfig(item.id);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      } on Exception catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.adminLoadFailed('$e'))),
                          );
                        }
                      }
                    },
                    child: Text(l10n.adminRollback),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.coreCancel),
        ),
      ],
    );
  }
}
