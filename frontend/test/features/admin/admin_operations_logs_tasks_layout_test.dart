import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/features/admin/application/admin_operations_controller.dart';
import 'package:omninest/features/admin/domain/admin_operations.dart';
import 'package:omninest/features/admin/domain/admin_paging.dart';
import 'package:omninest/features/admin/presentation/pages/admin_operations_pages.dart';

void main() {
  testWidgets('任务页在短桌面窗口中使用滚动布局', (tester) async {
    tester.view.physicalSize = const Size(1280, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminTaskPageProvider((
            page: 0,
            size: 20,
            status: 'ALL',
            taskType: 'ALL',
            query: '',
            sort: 'updatedAt',
            dir: 'desc',
          )).overrideWith(
            (ref) async => AdminPage<AdminTaskRecord>(
              items: [
                AdminTaskRecord(
                  id: 'task-1',
                  taskType: 'PHOTO_SCAN',
                  status: 'RUNNING',
                  progress: 40,
                  routingKey: 'omni.photo.scan',
                  errorSummary: null,
                  retryCount: 0,
                  createdAt: '2026-08-17T12:00:00Z',
                  updatedAt: '2026-08-17T12:00:00Z',
                ),
              ],
              page: 0,
              size: 20,
              totalElements: 1,
              totalPages: 1,
            ),
          ),
          adminDlqProvider.overrideWith((ref) async => const <AdminDlqTask>[]),
        ],
        child: MaterialApp(
          theme: OmniNestTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(body: const AdminTasksPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(1));
  });

  testWidgets('日志页在短桌面窗口中使用滚动布局', (tester) async {
    tester.view.physicalSize = const Size(1280, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminLogPageProvider((
            page: 0,
            size: 20,
            action: 'ALL',
            query: '',
            sort: 'createdAt',
            dir: 'desc',
          )).overrideWith(
            (ref) async => const AdminPage<AdminAuditLog>(
              items: [],
              page: 0,
              size: 20,
              totalElements: 0,
              totalPages: 0,
            ),
          ),
          adminLoginAuditPageProvider((
            page: 0,
            size: 20,
            result: 'ALL',
            platform: 'ALL',
            query: '',
            sort: 'createdAt',
            dir: 'desc',
          )).overrideWith(
            (ref) async => const AdminPage<AdminLoginAuditItem>(
              items: [],
              page: 0,
              size: 20,
              totalElements: 0,
              totalPages: 0,
            ),
          ),
        ],
        child: MaterialApp(
          theme: OmniNestTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(body: const AdminLogsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(1));
  });
}
