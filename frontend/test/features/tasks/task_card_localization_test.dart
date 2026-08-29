import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/features/tasks/domain/task_record.dart';
import 'package:omninest/features/tasks/presentation/widgets/task_card.dart';

void main() {
  testWidgets('任务卡片使用英文状态、阶段和相对时间', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final task = TaskRecord(
      id: 'task-1',
      taskType: 'FILE_PURGE',
      status: 'RUNNING',
      phase: 'PLANNING',
      progress: 30,
      retryCount: 1,
      maxRetries: 3,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: OmniNestTheme.light(),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          );
        },
        home: Scaffold(body: TaskCard(task: task)),
      ),
    );
    await tester.pump();

    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Planning resource deletion'), findsOneWidget);
    expect(find.text('Retries: 1/3'), findsOneWidget);
    expect(find.textContaining('min ago'), findsOneWidget);
    expect(_visibleText(tester), isNot(matches(RegExp(r'[\u4e00-\u9fff]'))));
    expect(tester.takeException(), isNull);
  });
}

String _visibleText(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
      .join('\n');
}
