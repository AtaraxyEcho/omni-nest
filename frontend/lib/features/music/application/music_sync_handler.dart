import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/core/realtime/realtime_models.dart';
import 'package:omninest/core/realtime/realtime_scope_handler.dart';
import 'package:omninest/features/music/application/music_controller.dart';
import 'package:omninest/features/music/application/music_platform_library_controller.dart';

/// 音乐作用域实时失效刷新处理器。
class MusicSyncHandler implements RealtimeScopeHandler {
  MusicSyncHandler(this.ref);

  final Ref ref;
  final RealtimeRevisionTracker _auxiliaryRevisions = RealtimeRevisionTracker();

  @override
  RealtimeScope get scope => RealtimeScope.music;

  @override
  bool appliesTo(RealtimeInvalidation invalidation) => true;

  @override
  Future<bool> refresh(List<RealtimeInvalidation> invalidations) async {
    final auxiliary = _auxiliaryRevisions.pending(invalidations);
    if (auxiliary.isNotEmpty && ref.exists(musicDashboardProvider)) {
      final _ = await ref.refresh(musicDashboardProvider.future);
    }
    if (auxiliary.isNotEmpty && ref.exists(musicPlatformLibraryProvider)) {
      await ref.read(musicPlatformLibraryProvider.future);
      await ref
          .read(musicPlatformLibraryProvider.notifier)
          .refreshForRealtime();
    }
    _auxiliaryRevisions.markCompleted(auxiliary);
    if (!ref.exists(musicCenterControllerProvider)) return false;
    await ref.read(musicCenterControllerProvider.future);
    await ref.read(musicCenterControllerProvider.notifier).refreshForRealtime();
    _auxiliaryRevisions.clear(invalidations);
    return true;
  }
}
