import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/features/admin/application/admin_operations_controller.dart';
import 'package:omninest/features/admin/domain/admin_operations.dart';
import 'package:omninest/features/admin/domain/admin_paging.dart';
import 'package:omninest/features/admin/presentation/pages/admin_operations_pages.dart';

AdminSessionItem _session({required String id, String? revokedAt}) {
  return AdminSessionItem(
    id: id,
    userId: 'u-$id',
    username: 'user-$id',
    clientPlatform: 'web',
    ipAddress: '10.0.0.1',
    issuedAt: '2026-08-30T08:00:00Z',
    expiresAt: '2026-09-30T08:00:00Z',
    lastActiveAt: '2026-09-01T08:00:00Z',
    revokedAt: revokedAt,
  );
}

void main() {
  testWidgets('会话页勾选活跃会话出现批量操作条且禁用已吊销行', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const query = (
      page: 0,
      size: 20,
      status: 'ALL',
      platform: 'ALL',
      query: '',
      sort: 'lastActiveAt',
      dir: 'desc',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminSessionPageProvider(query).overrideWith(
            (ref) async => AdminPage<AdminSessionItem>(
              items: [
                _session(id: 'active-1'),
                _session(id: 'revoked-1', revokedAt: '2026-09-01T09:00:00Z'),
              ],
              page: 0,
              size: 20,
              totalElements: 2,
              totalPages: 1,
            ),
          ),
        ],
        child: MaterialApp(
          theme: OmniNestTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(body: const AdminSessionsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('user-active-1'), findsOneWidget);
    expect(find.text('user-revoked-1'), findsOneWidget);
    expect(find.text('批量强制下线'), findsNothing);

    // 三颗复选框：表头全选 + 两行；第二行为已吊销会话，不可勾选。
    final checkboxes = find.byType(Checkbox);
    expect(checkboxes, findsNWidgets(3));
    await tester.tap(checkboxes.at(2));
    await tester.pump();
    expect(find.text('批量强制下线'), findsNothing, reason: '已吊销行不可勾选');

    await tester.tap(checkboxes.at(1));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 项'), findsOneWidget);
    expect(find.text('批量强制下线'), findsOneWidget);
  });
}
