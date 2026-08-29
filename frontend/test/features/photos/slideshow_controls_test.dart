import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/features/photos/presentation/widgets/slideshow_controls.dart';

void main() {
  testWidgets('幻灯片图标操作包含可访问名称', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: OmniNestTheme.dark(),
        home: Scaffold(
          body: SlideshowControls(
            isPlaying: true,
            currentIndex: 0,
            totalCount: 3,
            speedSeconds: 5,
            onPlayPause: _noop,
            onPrevious: _noop,
            onNext: _noop,
            onSpeedChanged: (_) {},
            onClose: _noop,
          ),
        ),
      ),
    );

    expect(find.byTooltip('关闭'), findsOneWidget);
    expect(find.byTooltip('上一个'), findsOneWidget);
    expect(find.byTooltip('暂停'), findsOneWidget);
    expect(find.byTooltip('下一个'), findsOneWidget);
  });
}

void _noop() {}
