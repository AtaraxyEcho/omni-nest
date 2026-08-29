import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_editor_top_bar.dart';

void main() {
  const photo = PhotoItem(
    id: 'photo-1',
    fileNodeId: 'file-1',
    title: 'Summer.jpg',
    format: 'JPEG',
    fileSize: 1024,
    metadataStatus: 'READY',
    favorite: false,
    createdAt: null,
  );

  testWidgets('紧凑布局展示图标命令并触发回调', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var backCount = 0;
    var saveCount = 0;
    var historyCount = 0;

    await tester.pumpWidget(
      _TestApp(
        child: PhotoEditorTopBar(
          photo: photo,
          saving: false,
          onBack: () => backCount++,
          onSave: () => saveCount++,
          onShowVersions: () => historyCount++,
        ),
      ),
    );

    expect(find.text('Edit - Summer.jpg'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.tap(find.byIcon(Icons.history_rounded));
    await tester.tap(find.byIcon(Icons.save_rounded));

    expect(backCount, 1);
    expect(historyCount, 1);
    expect(saveCount, 1);
  });

  testWidgets('保存中禁用保存命令', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        child: PhotoEditorTopBar(
          photo: photo,
          saving: true,
          onBack: () {},
          onSave: () {},
          onShowVersions: () {},
        ),
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: OmniNestTheme.dark(),
      home: Scaffold(body: child),
    );
  }
}
