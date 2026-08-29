import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/core/errors/error_message.dart';
import 'package:omninest/features/music/application/music_controller.dart';
import 'package:omninest/features/music/application/music_deck_source_selection_controller.dart';
import 'package:omninest/features/music/application/music_platform_library_controller.dart';
import 'package:omninest/features/music/domain/music_models.dart';
import 'package:omninest/features/music/domain/music_playable_item.dart';

final musicDailyRecommendationProvider = AsyncNotifierProvider<
  MusicDailyRecommendationController,
  DailyRecommendedTracks?
>(MusicDailyRecommendationController.new);

/// 按网易云登录状态和来源筛选加载每日推荐歌曲。
class MusicDailyRecommendationController
    extends AsyncNotifier<DailyRecommendedTracks?> {
  static const String _authenticationExpiredCode = '5004';

  @override
  Future<DailyRecommendedTracks?> build() async {
    final platformLibrary =
        ref.watch(musicPlatformLibraryProvider).asData?.value;
    final sources = ref.watch(musicDeckSourceSelectionProvider);
    final neteaseStatus = _neteaseStatus(platformLibrary);
    final visible =
        neteaseStatus != null &&
        neteaseStatus.enabled &&
        neteaseStatus.connected &&
        neteaseStatus.capabilities.dailyRecommendations &&
        sources.contains(MusicPlatform.netease);
    if (!visible) {
      return null;
    }
    try {
      return await ref
          .read(musicApiProvider)
          .platformDailyRecommendedTracks(MusicPlatform.netease.apiValue);
    } on Object catch (exception) {
      if (describeUserFacingError(exception).code ==
          _authenticationExpiredCode) {
        unawaited(
          Future<void>.microtask(
            () => ref.invalidate(musicPlatformLibraryProvider),
          ),
        );
      }
      rethrow;
    }
  }

  /// 重试加载当前可见的每日推荐歌曲。
  void retry() {
    ref.invalidateSelf();
  }

  MusicPlatformStatus? _neteaseStatus(
    MusicPlatformLibraryState? platformLibrary,
  ) {
    if (platformLibrary == null) {
      return null;
    }
    for (final status in platformLibrary.statuses) {
      if (status.platform == MusicPlatform.netease.apiValue) {
        return status;
      }
    }
    return null;
  }
}
