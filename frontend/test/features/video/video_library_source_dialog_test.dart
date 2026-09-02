import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/features/video/domain/movie_management_models.dart';
import 'package:omninest/features/video/presentation/widgets/movie_management.dart';

const _healthyLocation = VideoStorageLocation(
  id: 'loc-1',
  name: '本地影视盘',
  providerType: 'LOCAL_FILESYSTEM',
  mountKey: 'movies',
  relativeRoot: '.',
  scopeType: 'GLOBAL',
  enabled: true,
  healthStatus: 'AVAILABLE',
);

const _unhealthyLocation = VideoStorageLocation(
  id: 'loc-2',
  name: '离线盘',
  providerType: 'LOCAL_FILESYSTEM',
  mountKey: 'archive',
  relativeRoot: '.',
  scopeType: 'GLOBAL',
  enabled: true,
  healthStatus: 'UNAVAILABLE',
);

Future<void> _pumpDialog(
  WidgetTester tester,
  List<VideoStorageLocation> locations,
) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: OmniNestTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed:
                      () => showDialog<void>(
                        context: context,
                        builder:
                            (dialogContext) =>
                                VideoLibrarySourceDialog(locations: locations),
                      ),
                  child: const Text('open-dialog'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('open-dialog'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('存储位置列表为空时展示提示而不是崩溃', (tester) async {
    await _pumpDialog(tester, const []);

    expect(tester.takeException(), isNull);
    expect(find.text('暂无可用存储位置'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
  });

  testWidgets('仅有不可用存储位置时同样展示提示', (tester) async {
    await _pumpDialog(tester, const [_unhealthyLocation]);

    expect(tester.takeException(), isNull);
    expect(find.text('暂无可用存储位置'), findsOneWidget);
  });

  testWidgets('存在可用存储位置时正常渲染新建表单', (tester) async {
    await _pumpDialog(tester, const [_healthyLocation]);

    expect(tester.takeException(), isNull);
    expect(find.text('添加来源'), findsOneWidget);
    expect(find.textContaining('本地影视盘'), findsOneWidget);
  });
}
