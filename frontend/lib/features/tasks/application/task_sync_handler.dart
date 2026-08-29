import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/core/realtime/realtime_models.dart';
import 'package:omninest/core/realtime/realtime_scope_handler.dart';
import 'package:omninest/features/tasks/application/task_controller.dart';

/// 任务作用域实时失效刷新处理器。
class TaskSyncHandler implements RealtimeScopeHandler {
  TaskSyncHandler(this.ref);

  final Ref ref;
  final RealtimeRevisionTracker _summaryRevisions = RealtimeRevisionTracker();

  @override
  RealtimeScope get scope => RealtimeScope.tasks;

  @override
  bool appliesTo(RealtimeInvalidation invalidation) => true;

  @override
  Future<bool> refresh(List<RealtimeInvalidation> invalidations) async {
    final summaryPending = _summaryRevisions.pending(invalidations);
    if (summaryPending.isNotEmpty && ref.exists(activeTaskSummaryProvider)) {
      final _ = await ref.refresh(activeTaskSummaryProvider.future);
    }
    _summaryRevisions.markCompleted(summaryPending);
    if (!ref.exists(taskListProvider)) return false;
    await ref.read(taskListProvider.notifier).load();
    _summaryRevisions.clear(invalidations);
    return true;
  }
}
