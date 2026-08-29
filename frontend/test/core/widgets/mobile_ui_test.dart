import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/core/widgets/mobile_ui.dart';

void main() {
  testWidgets('移动端分段控件在窄屏下保持稳定并响应选择', (tester) async {
    var selected = 0;
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder:
                  (context, setState) => MobileSegmentedControl<int>(
                    values: const [0, 1, 2],
                    selected: selected,
                    labelBuilder: (value) => '选项 ${value + 1}',
                    onSelected: (value) => setState(() => selected = value),
                  ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('选项 3'));
    await tester.pumpAndSettle();

    expect(selected, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('移动端状态视图支持 1.3 倍文字缩放', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: MobileInlineState(
              icon: Icons.cloud_off_outlined,
              message: '网络暂时不可用，恢复连接后可以继续同步当前内容。',
              actionLabel: '重新加载',
              onAction: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('重新加载'), findsOneWidget);
  });
}
