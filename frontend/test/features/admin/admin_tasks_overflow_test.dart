import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/features/admin/domain/admin_operations.dart';
import 'package:omninest/features/admin/domain/admin_paging.dart';
import 'package:omninest/features/admin/domain/admin_section.dart';
import 'package:omninest/features/admin/application/admin_operations_controller.dart';
import 'package:omninest/features/admin/presentation/pages/admin_dashboard_page.dart';

AdminPage<AdminTaskRecord> _fakePage(int count) {
  return AdminPage<AdminTaskRecord>(
    items: [
      for (var i = 0; i < count; i++)
        AdminTaskRecord(
          id: 'task-$i',
          taskType: 'PHOTO_SCAN',
          status: i % 2 == 0 ? 'RUNNING' : 'FAILED',
          progress: 40,
          routingKey: 'omni.photo.scan',
          errorSummary: null,
          retryCount: 0,
          createdAt: '2026-09-01T12:00:00Z',
          updatedAt: '2026-09-01T12:00:00Z',
        ),
    ],
    page: 0,
    size: 10,
    totalElements: count,
    totalPages: 1,
  );
}

void main() {
  for (final size in [
    const Size(1280, 800),
    const Size(1366, 768),
    const Size(1536, 864),
    const Size(1600, 900),
    const Size(1100, 700),
    const Size(950, 650),
    const Size(1440, 620),
    const Size(1280, 500),
  ]) {
    testWidgets('任务页 ${size.width}x${size.height} 无布局异常', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const query = (
        page: 0,
        size: 10,
        status: 'ALL',
        taskType: 'ALL',
        query: '',
        sort: 'updatedAt',
        dir: 'desc',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminTaskPageProvider(
              query,
            ).overrideWith((ref) async => _fakePage(10)),
            adminDlqProvider.overrideWith(
              (ref) async => const <AdminDlqTask>[],
            ),
          ],
          child: MaterialApp(
            theme: OmniNestTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: const AdminDashboardPage(section: AdminSection.tasks),
          ),
        ),
      );
      final exception = tester.takeException();
      // ignore: avoid_print
      print('SIZE ${size.width}x${size.height} -> ${exception ?? 'OK'}');
      expect(exception, isNull);
    });
  }
}
