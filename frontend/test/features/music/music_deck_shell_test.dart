import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/app/theme/app_theme_palette.dart';
import 'package:omninest/core/widgets/mobile_shell_scope.dart';
import 'package:omninest/features/music/application/music_controller.dart';
import 'package:omninest/features/music/application/music_platform_library_controller.dart';
import 'package:omninest/features/music/domain/music_models.dart';
import 'package:omninest/features/music/presentation/deck/music_deck_shell.dart';

void main() {
  testWidgets('移动端查看全部页面提供返回首页控件', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final center = MusicCenterState(
      dashboard: MusicDashboard.empty(),
      tracks: const [],
      albums: const [],
      artists: const [],
      playlists: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          musicCenterControllerProvider.overrideWith(
            () => _FakeMusicCenterController(center),
          ),
          musicPlatformLibraryProvider.overrideWith(
            _FakeMusicPlatformLibraryController.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: OmniNestTheme.from(AppThemePalette.dark),
          home: const MobileShellScope(hosted: true, child: MusicDeckShell()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byKey(const ValueKey<String>('music-mobile-section-back')),
      findsNothing,
    );
    await tester.tap(find.text('View All').first);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('music-mobile-section-back')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('music-mobile-section-back')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('music-mobile-section-back')),
      findsNothing,
    );
    expect(find.text('View All'), findsNWidgets(2));
  });
}

class _FakeMusicCenterController extends MusicCenterController {
  _FakeMusicCenterController(this.initialState);

  final MusicCenterState initialState;

  @override
  Future<MusicCenterState> build() async => initialState;
}

class _FakeMusicPlatformLibraryController
    extends MusicPlatformLibraryController {
  @override
  Future<MusicPlatformLibraryState> build() async {
    return const MusicPlatformLibraryState();
  }
}
