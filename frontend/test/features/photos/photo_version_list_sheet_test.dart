import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/features/photos/domain/photo_edit_version.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_version_list_sheet.dart';

void main() {
  testWidgets('空版本列表展示空状态', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        child: PhotoVersionListSheet(versions: const [], onRevert: (_) {}),
      ),
    );

    expect(find.text('No edit history'), findsOneWidget);
  });

  testWidgets('展示版本信息并提交回滚动作', (tester) async {
    String? revertedVersionId;
    const version = PhotoEditVersion(
      id: 'version-2',
      versionNumber: 2,
      editType: 'CROP',
      editParams: <String, dynamic>{},
      createdAt: null,
    );

    await tester.pumpWidget(
      _TestApp(
        child: PhotoVersionListSheet(
          versions: const [version],
          onRevert: (versionId) => revertedVersionId = versionId,
        ),
      ),
    );

    expect(find.text('v2'), findsOneWidget);
    expect(find.text('Crop'), findsOneWidget);

    await tester.tap(find.text('Rollback'));
    expect(revertedVersionId, version.id);
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
