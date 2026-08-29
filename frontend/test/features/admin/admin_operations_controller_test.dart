import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omninest/features/admin/application/admin_operations_controller.dart';
import 'package:omninest/features/admin/data/admin_operations_api.dart';
import 'package:omninest/features/admin/domain/admin_operations.dart';

class _MockAdminOperationsApi extends Mock implements AdminOperationsApi {}

void main() {
  test('配置历史 Provider 通过应用层加载指定配置', () async {
    final api = _MockAdminOperationsApi();
    const history = AdminConfigHistory(
      id: 'history-1',
      configKey: 'feature.reader',
      oldValue: 'false',
      newValue: 'true',
      changedBy: 'admin',
      createdAt: '2026-07-22T12:00:00Z',
    );
    when(
      () => api.configHistory('feature.reader'),
    ).thenAnswer((_) async => const [history]);
    final container = ProviderContainer(
      overrides: [adminOperationsApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    final result = await container.read(
      adminConfigHistoryProvider('feature.reader').future,
    );

    expect(result, const [history]);
    verify(() => api.configHistory('feature.reader')).called(1);
  });
}
