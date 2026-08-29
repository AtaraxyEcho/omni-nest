import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_control_layout.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_return_to_progress_control.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_view_settings.dart';

void main() {
  test('沉浸模式释放正文空间并隐藏常驻阅读界面', () {
    final normal = ReaderChromeLayout.resolve(
      immersiveMode: false,
      isPageMode: false,
    );
    final immersive = ReaderChromeLayout.resolve(
      immersiveMode: true,
      isPageMode: false,
    );
    final paginated = ReaderChromeLayout.resolve(
      immersiveMode: false,
      isPageMode: true,
    );

    expect(normal.contentPadding, const EdgeInsets.only(top: 35, bottom: 16));
    expect(normal.viewportVerticalReserve, 51);
    expect(normal.chapterHeaderReserve, 54);
    expect(normal.showPersistentProgress, isTrue);
    expect(immersive.contentPadding, EdgeInsets.zero);
    expect(immersive.viewportVerticalReserve, 0);
    expect(immersive.chapterHeaderReserve, 0);
    expect(immersive.showPersistentProgress, isFalse);
    expect(
      paginated.contentPadding,
      const EdgeInsets.only(top: 35, bottom: 16),
    );
    expect(paginated.viewportVerticalReserve, 51);
    expect(paginated.showPersistentProgress, isTrue);
  });

  test('layout resolves compact medium and expanded viewports', () {
    final compact = ReaderControlLayout.resolve(
      viewport: const Size(320, 568),
      fontSize: 18,
    );
    final medium = ReaderControlLayout.resolve(
      viewport: const Size(800, 600),
      fontSize: 18,
    );
    final expanded = ReaderControlLayout.resolve(
      viewport: const Size(1280, 720),
      fontSize: 18,
    );

    expect(compact.density, ReaderControlDensity.compact);
    expect(medium.density, ReaderControlDensity.medium);
    expect(expanded.density, ReaderControlDensity.expanded);
    expect(expanded.usesSidePanel, isTrue);
    expect(compact.textColumnWidth, lessThanOrEqualTo(284));
  });

  test('short landscape uses a scrollable bottom panel', () {
    final layout = ReaderControlLayout.resolve(
      viewport: const Size(740, 360),
      fontSize: 22,
      textScale: 2,
    );

    expect(layout.isShort, isTrue);
    expect(layout.usesSidePanel, isFalse);
    expect(layout.panelMaxHeight, lessThanOrEqualTo(360));
  });

  test('return progress control remains bounded on desktop', () {
    expect(ReaderControlLayout.returnControlMaxWidth, 360);
  });

  testWidgets('return progress control does not stretch across desktop', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderReturnToProgressControl(
            settings: ReaderViewSettings(),
            label: 'Return to last reading position',
            onPressed: () {},
          ),
        ),
      ),
    );

    final size = tester.getSize(
      find.byKey(const ValueKey('reader-return-progress-control')),
    );
    expect(size.width, lessThanOrEqualTo(360));
    expect(size.width, lessThan(1280));
  });
}
