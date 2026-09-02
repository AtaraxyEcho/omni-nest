import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/features/admin/presentation/widgets/admin_list_components.dart';

void main() {
  Future<void> pumpTable(
    WidgetTester tester, {
    required int rowCount,
    required void Function(String columnKey, bool ascending) onSort,
    AdminListSort? sort,
    bool withActions = true,
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final columns = [
      const AdminListColumn(key: 'name', label: '名称', sortable: true),
      const AdminListColumn(key: 'ip', label: 'IP'),
    ];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: OmniNestTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: AdminDataTable(
              columns: columns,
              rowCount: rowCount,
              rowCellsBuilder:
                  (context, index) => [
                    Text('row-$index'),
                    Text('10.0.0.$index'),
                  ],
              actionsBuilder:
                  withActions
                      ? (context, index) => [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.more_vert_rounded),
                        ),
                      ]
                      : null,
              sort: sort,
              onSort: onSort,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('表格渲染行与固定操作列', (tester) async {
    await pumpTable(tester, rowCount: 3, onSort: (columnKey, ascending) {});
    expect(find.text('row-0'), findsOneWidget);
    expect(find.text('row-2'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsNWidgets(3));
  });

  testWidgets('点击可排序列头回调列键与方向', (tester) async {
    String? receivedKey;
    var receivedAscending = true;
    await pumpTable(
      tester,
      rowCount: 1,
      sort: const AdminListSort(columnKey: 'name', ascending: true),
      onSort: (columnKey, ascending) {
        receivedKey = columnKey;
        receivedAscending = ascending;
      },
    );
    await tester.tap(find.text('名称'));
    await tester.pump();
    expect(receivedKey, 'name');
    expect(receivedAscending, isFalse, reason: '已升序再点应变降序');
  });

  testWidgets('空态渲染占位提示', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: OmniNestTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: AdminDataTable(
              columns: const [AdminListColumn(key: 'name', label: '名称')],
              rowCount: 0,
              rowCellsBuilder: (context, index) => const <Widget>[],
              emptyState: AdminListEmptyState(message: 'empty-hint'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('empty-hint'), findsOneWidget);
  });
}
