import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/features/admin/admin_dashboard.dart';
import 'package:omninest/features/files/file_dashboard.dart';
import 'package:omninest/features/music/music_portal.dart';
import 'package:omninest/features/photos/photo_dashboard.dart';
import 'package:omninest/features/portal/portal_weather.dart';
import 'package:omninest/features/reader/reader_dashboard.dart';
import 'package:omninest/features/video/video_dashboard.dart';

final portalStorageStatsProvider = fileStorageStatsProvider;

final portalMovieDashboardProvider = movieDashboardProvider;

final portalMusicSnapshotProvider = musicPortalSnapshotProvider;

final portalMusicPlaybackTimelineProvider = musicPortalPlaybackTimelineProvider;

final portalMusicActionsProvider = musicPortalActionsProvider;

final portalPhotoDashboardProvider = photoDashboardProvider;

final portalAdminSummaryProvider = adminConsoleSummaryProvider;

final portalReaderDashboardProvider = readerDashboardProvider;

/// Portal 可独立刷新的摘要分区。
enum PortalDashboardSection {
  storage,
  video,
  music,
  photos,
  reader,
  admin,
  weather,
}

/// 一次 Portal 刷新的分区结果。
class PortalDashboardRefreshResult {
  const PortalDashboardRefreshResult({required this.failedSections});

  final Set<PortalDashboardSection> failedSections;

  bool get succeeded => failedSections.isEmpty;
}

/// Portal 摘要刷新入口，单个分区失败不会中断其他分区。
class PortalDashboardActions {
  PortalDashboardActions(
    Map<PortalDashboardSection, Future<void> Function()> refreshers,
  ) : _refreshers = Map.unmodifiable(refreshers);

  final Map<PortalDashboardSection, Future<void> Function()> _refreshers;

  Future<PortalDashboardRefreshResult> refreshAll() async {
    final outcomes = await Future.wait(
      PortalDashboardSection.values.map((section) async {
        final succeeded = await retry(section);
        return (section: section, succeeded: succeeded);
      }),
    );
    return PortalDashboardRefreshResult(
      failedSections: {
        for (final outcome in outcomes)
          if (!outcome.succeeded) outcome.section,
      },
    );
  }

  Future<bool> retry(PortalDashboardSection section) async {
    final refresher = _refreshers[section];
    if (refresher == null) {
      return false;
    }
    try {
      await refresher();
      return true;
    } on Object {
      return false;
    }
  }
}

final portalDashboardActionsProvider = Provider<PortalDashboardActions>((ref) {
  return PortalDashboardActions({
    PortalDashboardSection.storage: () async {
      ref.invalidate(portalStorageStatsProvider);
      await ref.read(portalStorageStatsProvider.future);
    },
    PortalDashboardSection.video: () async {
      ref.invalidate(portalMovieDashboardProvider);
      await ref.read(portalMovieDashboardProvider.future);
    },
    PortalDashboardSection.music:
        () => ref.read(portalMusicActionsProvider).refresh(),
    PortalDashboardSection.photos: () async {
      ref.invalidate(portalPhotoDashboardProvider);
      await ref.read(portalPhotoDashboardProvider.future);
    },
    PortalDashboardSection.reader: () async {
      ref.invalidate(portalReaderDashboardProvider);
      await ref.read(portalReaderDashboardProvider.future);
    },
    PortalDashboardSection.admin: () async {
      ref.invalidate(portalAdminSummaryProvider);
      await ref.read(portalAdminSummaryProvider.future);
    },
    PortalDashboardSection.weather: () async {
      ref.invalidate(realtimeWeatherProvider);
      await ref.read(realtimeWeatherProvider.future);
    },
  });
});
