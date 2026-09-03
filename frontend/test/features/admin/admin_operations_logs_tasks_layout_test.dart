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
            size: 10,
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
              size: 10,
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

  testWidgets('任务页勾选可重试任务出现批量操作条且禁用已完成行', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminTaskPageProvider((
            page: 0,
            size: 10,
            status: 'ALL',
            taskType: 'ALL',
            query: '',
            sort: 'updatedAt',
            dir: 'desc',
          )).overrideWith(
            (ref) async => AdminPage<AdminTaskRecord>(
              items: [
                AdminTaskRecord(
                  id: 'task-retryable',
                  taskType: 'PHOTO_SCAN',
                  status: 'FAILED',
                  progress: 40,
                  routingKey: 'omni.photo.scan',
                  errorSummary: null,
                  retryCount: 0,
                  createdAt: '2026-08-17T12:00:00Z',
                  updatedAt: '2026-08-17T12:00:00Z',
                ),
                AdminTaskRecord(
                  id: 'task-done',
                  taskType: 'PHOTO_SCAN',
                  status: 'COMPLETED',
                  progress: 100,
                  routingKey: 'omni.photo.scan',
                  errorSummary: null,
                  retryCount: 0,
                  createdAt: '2026-08-17T12:00:00Z',
                  updatedAt: '2026-08-17T12:00:00Z',
                ),
              ],
              page: 0,
              size: 10,
              totalElements: 2,
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

    expect(find.text('批量重试'), findsNothing);
    final checkboxes = find.byType(Checkbox);
    expect(checkboxes, findsNWidgets(3));

    final scrollable =
        find
            .ancestor(of: checkboxes.at(1), matching: find.byType(Scrollable))
            .first;
    await tester.scrollUntilVisible(
      checkboxes.at(1),
      -200,
      scrollable: scrollable,
    );

    await tester.tap(checkboxes.at(2));
    await tester.pump();
    expect(find.text('批量重试'), findsNothing, reason: '已完成任务不可勾选');

    await tester.tap(checkboxes.at(1));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 项'), findsOneWidget);
    expect(find.text('批量重试'), findsOneWidget);
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
            size: 10,
            action: 'ALL',
            query: '',
            sort: 'createdAt',
            dir: 'desc',
          )).overrideWith(
            (ref) async => const AdminPage<AdminAuditLog>(
              items: [],
              page: 0,
              size: 10,
              totalElements: 0,
              totalPages: 0,
            ),
          ),
          adminLoginAuditPageProvider((
            page: 0,
            size: 10,
            result: 'ALL',
            platform: 'ALL',
            query: '',
            sort: 'createdAt',
            dir: 'desc',
          )).overrideWith(
            (ref) async => const AdminPage<AdminLoginAuditItem>(
              items: [],
              page: 0,
              size: 10,
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
