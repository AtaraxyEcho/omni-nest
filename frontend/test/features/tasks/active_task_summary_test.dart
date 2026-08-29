import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omninest/features/tasks/application/task_controller.dart';
import 'package:omninest/features/tasks/data/task_api.dart';
import 'package:omninest/features/tasks/domain/task_record.dart';

void main() {
  test('活动任务摘要优先展示失败任务并统计活动数量', () {
    final summary = ActiveTaskSummary.fromRecords([
      _task('pending', 'PENDING'),
      _task('running', 'RUNNING'),
      _task('failed', 'FAILED'),
      _task('completed', 'COMPLETED'),
    ]);

    expect(summary.activeCount, 2);
    expect(summary.failedCount, 1);
    expect(summary.priorityTask?.id, 'failed');
    expect(summary.hasActivity, isTrue);
  });

  test('活动任务 Provider 不依赖任务页面列表状态', () async {
    final api = _MockTaskApi();
    when(
      () => api.list(page: 0, size: 100),
    ).thenAnswer((_) async => [_task('running', 'RUNNING')]);
    final container = ProviderContainer(
      overrides: [taskApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    expect(container.read(taskListProvider), isEmpty);
    final summary = await container.read(activeTaskSummaryProvider.future);

    expect(summary.activeCount, 1);
    expect(summary.priorityTask?.id, 'running');
    verify(() => api.list(page: 0, size: 100)).called(1);
  });
}

TaskRecord _task(String id, String status) {
  return TaskRecord(
    id: id,
    taskType: 'test',
    status: status,
    retryCount: 0,
    maxRetries: 3,
    createdAt: DateTime.utc(2026, 7, 14),
  );
}

class _MockTaskApi extends Mock implements TaskApi {}
