import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/app/theme/app_theme_palette.dart';
import 'package:omninest/core/auth/auth_controller.dart';
import 'package:omninest/core/auth/auth_session_store_base.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/presentation/pages/photos_page.dart';
import 'package:omninest/features/photos/presentation/widgets/frame_bottom_nav.dart';
import 'package:omninest/features/photos/presentation/widgets/frame_sidebar.dart';

/// 伪造的照片中心控制器，返回空状态以避免网络请求
class _FakePhotoCenterController extends PhotoCenterController {
  @override
  Future<PhotoCenterState> build() async {
    return PhotoCenterState.empty();
  }
}

Widget _wrapFramePage() {
  final router = GoRouter(
    initialLocation: '/photos',
    routes: [
      GoRoute(path: '/photos', builder: (context, state) => const PhotosPage()),
      GoRoute(path: '/portal', builder: (context, state) => const SizedBox()),
    ],
  );
  return ProviderScope(
    overrides: [
      authSessionStoreProvider.overrideWithValue(MemoryAuthSessionStore()),
      photoCenterControllerProvider.overrideWith(
        () => _FakePhotoCenterController(),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: OmniNestTheme.from(AppThemePalette.dark),
    ),
  );
}

Future<void> _pumpAt(WidgetTester tester, Size logicalSize) async {
  tester.view.physicalSize = logicalSize * 2;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_wrapFramePage());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('Frame 导航壳', () {
    testWidgets('宽屏侧栏展开并可在视图间切换', (tester) async {
      await _pumpAt(tester, const Size(1280, 800));

      expect(find.byType(FrameSidebar), findsOneWidget);
      expect(find.byType(FrameBottomNav), findsNothing);
      expect(
        tester.getSize(find.byType(FrameSidebar)).width,
        moreOrLessEquals(220),
      );
      expect(find.text('Trash'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('frame-nav-trash')));
      await tester.pumpAndSettle();
      expect(find.text('Trash is empty'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('frame-nav-locations')));
      await tester.pumpAndSettle();
      expect(find.text('No locations yet'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('frame-nav-albums')));
      await tester.pumpAndSettle();
      expect(find.text('New Album'), findsOneWidget);
    });

    testWidgets('宽 1024 以下侧栏折叠为 60px 且隐藏文字', (tester) async {
      await _pumpAt(tester, const Size(950, 800));

      expect(find.byType(FrameSidebar), findsOneWidget);
      expect(
        tester.getSize(find.byType(FrameSidebar)).width,
        moreOrLessEquals(60),
      );
      // 折叠态仅保留图标与顶栏标题，侧栏文字与统计全部隐藏。
      expect(find.text('Trash'), findsNothing);
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('0 photos'), findsNothing);
    });

    testWidgets('紧凑布局使用底部导航且不渲染侧栏', (tester) async {
      await _pumpAt(tester, const Size(600, 900));

      expect(find.byType(FrameSidebar), findsNothing);
      expect(find.byType(FrameBottomNav), findsOneWidget);
      // 底部导航与设计稿一致，仅五个入口，不含回收站。
      expect(find.byKey(const ValueKey('frame-tab-trash')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('frame-tab-albums')));
      await tester.pumpAndSettle();
      expect(find.text('New Album'), findsOneWidget);
      expect(find.byKey(const ValueKey('frame-tab-trash')), findsNothing);
    });
  });
}
