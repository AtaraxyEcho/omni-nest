import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/features/portal/presentation/widgets/portal_visual_widgets.dart';

void main() {
  testWidgets('Portal 模块快捷卡片列表从左侧开始排列', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        home: Scaffold(
          body: Builder(
            builder:
                (context) => Align(
                  alignment: Alignment.topLeft,
                  child: PortalQuickLinks(
                    palette: PortalVisualPalette.of(context),
                    includeAdmin: false,
                  ),
                ),
          ),
        ),
      ),
    );

    final wrap = tester.widget<Wrap>(find.byType(Wrap));
    expect(wrap.alignment, WrapAlignment.start);
    expect(wrap.runAlignment, WrapAlignment.start);
    expect(wrap.crossAxisAlignment, WrapCrossAlignment.start);
  });

  test('Portal 音乐卡片优先使用恢复的播放会话', () {
    final dataSource =
        File(
          'lib/features/portal/presentation/widgets/portal_desktop_data.dart',
        ).readAsStringSync();
    final stageSource =
        File(
          'lib/features/music/presentation/player/music_immersive_player_stage.dart',
        ).readAsStringSync();
    final integrationSource =
        File(
          'lib/features/music/application/music_portal_integration.dart',
        ).readAsStringSync();
    final previewSource =
        File(
          'lib/features/portal/presentation/widgets/portal_desktop_quick_actions.dart',
        ).readAsStringSync();

    expect(dataSource, contains('portalMusicSnapshotProvider'));
    expect(dataSource, contains('featuredTrack'));
    expect(integrationSource, contains('center.currentItem'));
    expect(integrationSource, contains('center.playbackItems[index]'));
    expect(integrationSource, contains('primaryItem?.track'));
    expect(stageSource, contains('state!.playbackQueue'));
    expect(previewSource, contains('snapshot.queuePreview'));
    expect(previewSource, contains('_PortalMusicFocusPreview'));
    expect(previewSource, contains('_PortalFocusPreviewWaterfall'));
  });

  test('移动端 Portal 音乐卡片使用统一播放会话', () {
    final source =
        File(
          'lib/features/portal/presentation/widgets/portal_mobile_shell.dart',
        ).readAsStringSync();

    expect(source, contains('ref.watch(portalMusicSnapshotProvider)'));
    expect(source, contains('snapshot.featuredTrack'));
    expect(source, contains('snapshot.recentPlayCount'));
    expect(source, isNot(contains('musicCenterControllerProvider')));
  });
}
