import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/core/realtime/realtime_models.dart';
import 'package:omninest/features/admin/application/admin_operations_controller.dart';
import 'package:omninest/features/admin/application/admin_sync_handler.dart';

final _handlerProvider = Provider<AdminSyncHandler>(AdminSyncHandler.new);

void main() {
  test('未进入管理模块时不会因全作用域重置请求管理接口', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final handler = container.read(_handlerProvider);

    final invalidation = RealtimeInvalidation(
      key: 'admin-reset',
      scope: RealtimeScope.admin,
      resourceType: '*',
      revision: 1,
      createdAt: DateTime.utc(2026, 7, 17),
    );

    expect(handler.appliesTo(invalidation), isTrue);
    expect(await handler.refresh([invalidation]), isFalse);

    expect(container.exists(adminConsoleSummaryProvider), isFalse);
  });
}
