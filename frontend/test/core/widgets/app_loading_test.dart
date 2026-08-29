import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/core/widgets/app_loading.dart';
import 'package:omninest/core/widgets/skeleton_shimmer.dart';

void main() {
  testWidgets('网格骨架从内容区域顶部开始并铺开卡片槽位', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(width: 390, height: 800, child: AppLoading.grid()),
      ),
    );

    final loading = find.byType(AppLoading);
    final alignments = tester
        .widgetList<Align>(
          find.descendant(of: loading, matching: find.byType(Align)),
        )
        .map((widget) => widget.alignment);

    expect(alignments, contains(Alignment.topCenter));
    expect(
      find.descendant(of: loading, matching: find.byType(SkeletonBox)),
      findsAtLeastNWidgets(8),
    );
    final firstSkeleton =
        find.descendant(of: loading, matching: find.byType(SkeletonBox)).first;
    expect(tester.getTopLeft(firstSkeleton).dy, lessThan(40));
    expect(find.byType(ShaderMask), findsOneWidget);
  });

  testWidgets('关闭动画时内容骨架保留位置但不执行扫光', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SizedBox(width: 390, height: 800, child: AppLoading()),
        ),
      ),
    );

    expect(find.byType(SkeletonBox), findsAtLeastNWidgets(20));
    expect(find.byType(ShaderMask), findsNothing);
  });
}
