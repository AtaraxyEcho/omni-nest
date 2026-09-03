import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/features/admin/domain/admin_operations.dart';
import 'package:omninest/features/admin/presentation/pages/admin_operations_pages.dart';
import 'package:omninest/features/video/application/movie_controller.dart';
import 'package:omninest/features/video/domain/movie_management_models.dart';

void main() {
  testWidgets('存储管理页表格渲染且行点击打开详情弹窗', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const location = AdminStorageLocation(
      id: 'loc-1',
      name: '影视主库',
      providerType: 'LOCAL',
      managementMode: 'MANAGED',
      mountKey: 'media-01',
      relativeRoot: '/media/movies',
      scopeType: 'SHARED',
      enabled: true,
      healthStatus: 'AVAILABLE',
      nodeId: 'node-01',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoStorageLocationsProvider.overrideWith(
            (ref) async => const <VideoStorageLocation>[],
          ),
          videoLibrarySourcesProvider.overrideWith(
            (ref) async => const <VideoLibrarySource>[],
          ),
        ],
        child: MaterialApp(
          theme: OmniNestTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: AdminStoragePage(
                view: AdminStorageManagementView(
                  buckets: [],
                  locations: [location],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 表格渲染：列头与行数据齐备，健康 AVAILABLE 为"可用"。
    expect(find.text('影视主库'), findsOneWidget);
    expect(find.text('media-01'), findsOneWidget);
    expect(find.text('可用'), findsOneWidget);

    // 行点击打开详情弹窗（弹窗内再次出现挂载键字段）。
    await tester.tap(find.text('media-01'));
    await tester.pumpAndSettle();
    expect(find.textContaining('media-01'), findsNWidgets(2));
    expect(find.textContaining('MANAGED'), findsOneWidget);
  });
}
