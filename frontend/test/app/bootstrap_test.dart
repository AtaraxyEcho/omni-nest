import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/bootstrap.dart';
import 'package:omninest/app/preferences/app_bootstrap_data.dart';

void main() {
  testWidgets('启动数据加载完成后挂载应用', (tester) async {
    await tester.pumpWidget(
      AppBootstrapGate(
        loader:
            () async => const AppBootstrapData(
              themeModeName: 'dark',
              languageCode: 'en',
            ),
        builder:
            (data) => MaterialApp(
              home: Text('${data.themeModeName}:${data.languageCode}'),
            ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('dark:en'), findsOneWidget);
  });

  testWidgets('启动失败后可以重试并恢复', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      AppBootstrapGate(
        loader: () async {
          attempts++;
          if (attempts == 1) {
            throw StateError('media unavailable');
          }
          return const AppBootstrapData();
        },
        builder: (_) => const MaterialApp(home: Text('ready')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('ready'), findsOneWidget);
    expect(attempts, 2);
  });
}
